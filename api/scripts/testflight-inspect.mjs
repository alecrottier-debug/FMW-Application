// Read-only: dump the metadata attached to the beta review submission, with a
// focus on privacy fields.
import { readFile } from "node:fs/promises";
import { importPKCS8, SignJWT } from "jose";

const KEY_ID = process.env.ASC_KEY_ID;
const ISSUER = process.env.ASC_ISSUER_ID;
const KEY_PATH = process.env.ASC_KEY_PATH;
const APP_ID = process.env.ASC_APP_ID || "6794430934";
if (!KEY_ID || !ISSUER || !KEY_PATH) { console.error("missing creds"); process.exit(1); }

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

console.log("=== Beta App Review Detail (contact / demo) ===");
try {
  const d = await api(`/v1/apps/${APP_ID}/betaAppReviewDetail`);
  console.log(JSON.stringify(d.data?.attributes ?? {}, null, 2));
} catch (e) { console.log("err", e.status); }

console.log("\n=== Beta App Localizations (description / feedback / PRIVACY) ===");
try {
  const l = await api(`/v1/apps/${APP_ID}/betaAppLocalizations`);
  for (const loc of l.data || []) console.log(JSON.stringify(loc.attributes, null, 2));
} catch (e) { console.log("err", e.status); }

console.log("\n=== Build export compliance (encryption) ===");
try {
  const b = await api(`/v1/apps/${APP_ID}/builds?limit=20&fields[builds]=version,usesNonExemptEncryption`);
  const build = (b.data || []).slice().sort((x, y) => Number(y.attributes.version) - Number(x.attributes.version))[0];
  console.log(`build v${build?.attributes?.version}: usesNonExemptEncryption = ${build?.attributes?.usesNonExemptEncryption}`);
} catch (e) { console.log("err", e.status); }

console.log("\n=== App-level: privacy policy / app info ===");
try {
  const infos = await api(`/v1/apps/${APP_ID}/appInfos`);
  for (const info of infos.data || []) {
    console.log("appInfo state:", info.attributes?.appStoreState, "| brazilAgeRating:", info.attributes?.brazilAgeRatingV2 ?? "-");
  }
} catch (e) { console.log("appInfos err", e.status); }
