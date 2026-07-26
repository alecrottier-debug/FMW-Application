// Read-only: report the beta review / external testing state of the newest build.
import { readFile } from "node:fs/promises";
import { importPKCS8, SignJWT } from "jose";

const KEY_ID = process.env.ASC_KEY_ID;
const ISSUER = process.env.ASC_ISSUER_ID;
const KEY_PATH = process.env.ASC_KEY_PATH;
const APP_ID = process.env.ASC_APP_ID || "6794430934";
if (!KEY_ID || !ISSUER || !KEY_PATH) {
  console.error("Set ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH");
  process.exit(1);
}

const key = await importPKCS8(await readFile(KEY_PATH, "utf8"), "ES256");
const token = await new SignJWT({})
  .setProtectedHeader({ alg: "ES256", kid: KEY_ID, typ: "JWT" })
  .setIssuer(ISSUER).setAudience("appstoreconnect-v1")
  .setIssuedAt().setExpirationTime("18m").sign(key);

const BASE = "https://api.appstoreconnect.apple.com";
async function api(path) {
  const res = await fetch(BASE + path, { headers: { Authorization: `Bearer ${token}` } });
  const text = await res.text();
  let json; try { json = text ? JSON.parse(text) : {}; } catch { json = { raw: text }; }
  if (!res.ok) { const e = new Error(`GET ${path} -> ${res.status}`); e.status = res.status; e.body = json; throw e; }
  return json;
}

const builds = await api(`/v1/apps/${APP_ID}/builds?limit=20&fields[builds]=version,processingState,expired`);
const build = (builds.data || [])
  .slice().sort((a, b) => Number(b.attributes.version) - Number(a.attributes.version))[0];
if (!build) { console.log("no builds"); process.exit(0); }
console.log(`build v${build.attributes.version}  processing=${build.attributes.processingState}  expired=${build.attributes.expired}  id=${build.id}`);

try {
  const bbd = await api(`/v1/builds/${build.id}/buildBetaDetail`);
  const a = bbd.data?.attributes ?? {};
  console.log(`externalBuildState = ${a.externalBuildState}`);
  console.log(`internalBuildState = ${a.internalBuildState}`);
} catch (e) { console.log("buildBetaDetail:", e.status); }

try {
  const sub = await api(`/v1/builds/${build.id}/betaAppReviewSubmission`);
  console.log(`betaReviewState = ${sub.data?.attributes?.betaReviewState ?? "(none)"}`);
} catch (e) {
  if (e.status === 404) console.log("betaReviewState = (no submission)");
  else console.log("betaAppReviewSubmission:", e.status);
}

// How many testers are attached to our external group.
try {
  const groups = await api(`/v1/apps/${APP_ID}/betaGroups?limit=200`);
  const g = (groups.data || []).find((x) => x.attributes?.name === "Neighborhood Coordinators");
  if (g) {
    const testers = await api(`/v1/betaGroups/${g.id}/betaTesters?limit=200&fields[betaTesters]=email,state,inviteType`);
    console.log(`group "Neighborhood Coordinators": ${testers.data?.length ?? 0} testers`);
    for (const t of testers.data || []) {
      console.log(`  - ${t.attributes?.email}  state=${t.attributes?.state}`);
    }
  }
} catch (e) { console.log("group testers:", e.status); }
