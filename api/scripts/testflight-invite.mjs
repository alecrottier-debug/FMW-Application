// Add external TestFlight testers via the App Store Connect API.
// Creates (or reuses) an external beta group and invites the given testers.
// Requires ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH in the environment.
import { readFile } from "node:fs/promises";
import { importPKCS8, SignJWT } from "jose";

const KEY_ID = process.env.ASC_KEY_ID;
const ISSUER = process.env.ASC_ISSUER_ID;
const KEY_PATH = process.env.ASC_KEY_PATH;
const APP_ID = process.env.ASC_APP_ID || "6794430934";
const GROUP_NAME = process.env.ASC_GROUP_NAME || "Neighborhood Coordinators";
if (!KEY_ID || !ISSUER || !KEY_PATH) {
  console.error("Set ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH");
  process.exit(1);
}

const key = await importPKCS8(await readFile(KEY_PATH, "utf8"), "ES256");
const token = await new SignJWT({})
  .setProtectedHeader({ alg: "ES256", kid: KEY_ID, typ: "JWT" })
  .setIssuer(ISSUER)
  .setAudience("appstoreconnect-v1")
  .setIssuedAt()
  .setExpirationTime("18m")
  .sign(key);

const BASE = "https://api.appstoreconnect.apple.com";
async function api(method, path, body) {
  const res = await fetch(BASE + path, {
    method,
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json;
  try {
    json = text ? JSON.parse(text) : {};
  } catch {
    json = { raw: text };
  }
  if (!res.ok) {
    const err = new Error(`${method} ${path} -> ${res.status}`);
    err.status = res.status;
    err.body = json;
    throw err;
  }
  return json;
}

const testers = [
  { email: "goldjay@hotmail.com", firstName: "Jason", lastName: "Goldberg" },
  { email: "jimbetz10@gmail.com", firstName: "Jim", lastName: "Betz" },
  { email: "timcarlson1@gmail.com", firstName: "Tim", lastName: "Carlson" },
  { email: "jamesandjenapierce@gmail.com", firstName: "James", lastName: "Pierce" },
];

// 1) Find or create the external beta group.
const groups = await api("GET", `/v1/apps/${APP_ID}/betaGroups?limit=200`);
let group = (groups.data || []).find((g) => g.attributes?.name === GROUP_NAME);
if (!group) {
  const created = await api("POST", `/v1/betaGroups`, {
    data: {
      type: "betaGroups",
      attributes: { name: GROUP_NAME, publicLinkEnabled: false },
      relationships: { app: { data: { type: "apps", id: APP_ID } } },
    },
  });
  group = created.data;
  console.log(`created external group "${GROUP_NAME}" (${group.id})`);
} else {
  console.log(`using existing group "${GROUP_NAME}" (${group.id})`);
}
const groupId = group.id;

// 2) Invite each tester (create with group; if they already exist, add to group).
for (const t of testers) {
  try {
    await api("POST", `/v1/betaTesters`, {
      data: {
        type: "betaTesters",
        attributes: { email: t.email, firstName: t.firstName, lastName: t.lastName },
        relationships: { betaGroups: { data: [{ type: "betaGroups", id: groupId }] } },
      },
    });
    console.log(`invited: ${t.email}`);
  } catch (e) {
    if (e.status === 409) {
      const found = await api("GET", `/v1/betaTesters?filter[email]=${encodeURIComponent(t.email)}`);
      const id = found.data?.[0]?.id;
      if (id) {
        try {
          await api("POST", `/v1/betaGroups/${groupId}/relationships/betaTesters`, {
            data: [{ type: "betaTesters", id }],
          });
          console.log(`already existed — added to group: ${t.email}`);
        } catch (e2) {
          if (e2.status === 409) console.log(`already in group: ${t.email}`);
          else throw e2;
        }
      } else {
        console.log(`could not resolve existing tester: ${t.email}`);
      }
    } else {
      console.log(`FAILED ${t.email}: ${e.status} ${JSON.stringify(e.body?.errors?.[0]?.detail ?? e.body)}`);
    }
  }
}

console.log(`GROUP_ID=${groupId}`);
