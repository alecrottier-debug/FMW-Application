// Attach the newest build to the external group, set "what to test", and submit
// for Beta App Review (required before external testers can install).
import { readFile } from "node:fs/promises";
import { importPKCS8, SignJWT } from "jose";

const KEY_ID = process.env.ASC_KEY_ID;
const ISSUER = process.env.ASC_ISSUER_ID;
const KEY_PATH = process.env.ASC_KEY_PATH;
const APP_ID = process.env.ASC_APP_ID || "6794430934";
const GROUP_ID = process.env.ASC_GROUP_ID;
if (!KEY_ID || !ISSUER || !KEY_PATH || !GROUP_ID) {
  console.error("Set ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH, ASC_GROUP_ID");
  process.exit(1);
}

const key = await importPKCS8(await readFile(KEY_PATH, "utf8"), "ES256");
const token = await new SignJWT({})
  .setProtectedHeader({ alg: "ES256", kid: KEY_ID, typ: "JWT" })
  .setIssuer(ISSUER).setAudience("appstoreconnect-v1")
  .setIssuedAt().setExpirationTime("18m").sign(key);

const BASE = "https://api.appstoreconnect.apple.com";
async function api(method, path, body) {
  const res = await fetch(BASE + path, {
    method,
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json; try { json = text ? JSON.parse(text) : {}; } catch { json = { raw: text }; }
  if (!res.ok) { const e = new Error(`${method} ${path} -> ${res.status}`); e.status = res.status; e.body = json; throw e; }
  return json;
}

const WHATS_NEW =
  "Sign in with Apple or Google. Browse Events and (as a coordinator) publish a new event. " +
  "Under Wallet, scan a receipt and review the Event books. Edit your profile under You. Thanks for testing!";

// 1) Newest build + processing state.
const builds = await api("GET",
  `/v1/apps/${APP_ID}/builds?limit=20&fields[builds]=version,processingState`);
const build = (builds.data || [])
  .slice()
  .sort((a, b) => Number(b.attributes.version) - Number(a.attributes.version))[0];
if (!build) { console.log("no builds found"); process.exit(0); }
console.log(`newest build: v${build.attributes.version}  state=${build.attributes.processingState}  id=${build.id}`);
if (build.attributes.processingState !== "VALID") {
  console.log("PROCESSING — not ready to submit yet. Re-run in a few minutes.");
  process.exit(0);
}
const buildId = build.id;

// 2) Attach build to the external group.
try {
  await api("POST", `/v1/betaGroups/${GROUP_ID}/relationships/builds`, {
    data: [{ type: "builds", id: buildId }],
  });
  console.log("attached build to group");
} catch (e) {
  console.log(`attach: ${e.status} ${JSON.stringify(e.body?.errors?.[0]?.detail ?? "")}`);
}

// 3) What-to-test localization.
const locs = await api("GET", `/v1/builds/${buildId}/betaBuildLocalizations`);
const en = (locs.data || []).find((l) => l.attributes?.locale === "en-US");
if (en) {
  await api("PATCH", `/v1/betaBuildLocalizations/${en.id}`, {
    data: { type: "betaBuildLocalizations", id: en.id, attributes: { whatsNew: WHATS_NEW } },
  });
  console.log("updated what-to-test");
} else {
  await api("POST", `/v1/betaBuildLocalizations`, {
    data: {
      type: "betaBuildLocalizations",
      attributes: { locale: "en-US", whatsNew: WHATS_NEW },
      relationships: { build: { data: { type: "builds", id: buildId } } },
    },
  });
  console.log("set what-to-test");
}

// 4) Beta App Localization (Beta App Description + feedback email) — required for external.
const FEEDBACK_EMAIL = process.env.ASC_FEEDBACK_EMAIL || "alec.rottier@gmail.com";
const PRIVACY_URL = process.env.ASC_PRIVACY_URL ||
  "https://func-ndps736gp4ayg.azurewebsites.net/api/privacy";
const DESCRIPTION =
  "Fox Mill Woods is a private app for the Fox Mill Woods neighborhood — events, " +
  "pavilion rentals, annual dues, and a member directory. This beta is for neighborhood " +
  "coordinators to try publishing events, scanning receipts, and the money dashboard.";
{
  const attributes = { feedbackEmail: FEEDBACK_EMAIL, description: DESCRIPTION, privacyPolicyUrl: PRIVACY_URL };
  const bloc = await api("GET", `/v1/apps/${APP_ID}/betaAppLocalizations`);
  const en2 = (bloc.data || []).find((l) => l.attributes?.locale === "en-US");
  if (en2) {
    await api("PATCH", `/v1/betaAppLocalizations/${en2.id}`, {
      data: { type: "betaAppLocalizations", id: en2.id, attributes },
    });
    console.log("updated beta app localization (+ privacy policy URL)");
  } else {
    await api("POST", `/v1/betaAppLocalizations`, {
      data: { type: "betaAppLocalizations",
        attributes: { locale: "en-US", ...attributes },
        relationships: { app: { data: { type: "apps", id: APP_ID } } } },
    });
    console.log("created beta app localization (+ privacy policy URL)");
  }
}

// 5) Beta App Review Detail (contact info). Phone is required by Apple — supply
//    ASC_CONTACT_PHONE to complete it and submit.
const PHONE = process.env.ASC_CONTACT_PHONE || "";
{
  const detail = await api("GET", `/v1/apps/${APP_ID}/betaAppReviewDetail`);
  const id = detail.data?.id;
  if (id) {
    const attrs = {
      contactFirstName: process.env.ASC_CONTACT_FIRST || "Alec",
      contactLastName: process.env.ASC_CONTACT_LAST || "Rottier",
      contactEmail: FEEDBACK_EMAIL,
      demoAccountRequired: false,
    };
    if (PHONE) attrs.contactPhone = PHONE;
    await api("PATCH", `/v1/betaAppReviewDetails/${id}`, {
      data: { type: "betaAppReviewDetails", id, attributes: attrs },
    });
    console.log(`updated beta app review detail${PHONE ? " (with phone)" : " (no phone yet)"}`);
  }
}

// 6) Submit — only when we have a phone (Apple rejects the submission otherwise).
if (!PHONE) {
  console.log("NEED_PHONE: set ASC_CONTACT_PHONE to submit for Beta App Review.");
  process.exit(0);
}
try {
  const sub = await api("POST", `/v1/betaAppReviewSubmissions`, {
    data: { type: "betaAppReviewSubmissions", relationships: { build: { data: { type: "builds", id: buildId } } } },
  });
  console.log(`SUBMITTED for Beta App Review: ${sub.data?.id} state=${sub.data?.attributes?.betaReviewState}`);
} catch (e) {
  console.log(`SUBMIT blocked: ${e.status} ${JSON.stringify(e.body?.errors?.map((x) => x.detail) ?? e.body)}`);
}
