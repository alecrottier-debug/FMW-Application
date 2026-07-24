import { HttpRequest } from "@azure/functions";
import { createRemoteJWKSet, jwtVerify, SignJWT } from "jose";
import { getPool, sql } from "./db";
import { HttpError } from "./http";
import { Role, User } from "./types";

// Native Sign in with Apple + Google Sign-In. The app validates nothing itself; it
// sends the provider's identity token to /auth/session, we verify it here against
// the provider's public keys, then issue OUR OWN session JWT that the app uses for
// every request (validated by requireUser). No passwords, no Entra broker.

const appleJwks = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));
const googleJwks = createRemoteJWKSet(new URL("https://www.googleapis.com/oauth2/v3/certs"));

// Apple: aud = the app's bundle id. Google: aud = the iOS OAuth client id.
const APPLE_AUD = process.env.APPLE_BUNDLE_ID;
const GOOGLE_AUD = process.env.GOOGLE_CLIENT_ID;

function appSecret(): Uint8Array {
  const secret = process.env.APP_JWT_SECRET;
  if (!secret) throw new HttpError(500, "APP_JWT_SECRET is not configured");
  return new TextEncoder().encode(secret);
}

interface ProviderClaims {
  sub: string;
  email?: string;
}

/** Validate a provider id token, upsert the user, and return an app session JWT. */
export async function issueSession(
  provider: string,
  idToken: string,
  name?: string
): Promise<{ token: string; user: User }> {
  const claims = await verifyIdentityToken(provider, idToken);
  if (!claims.sub) throw new HttpError(401, "Token missing subject");

  const user = await getOrCreateUser(`${provider}:${claims.sub}`, claims.email ?? "", name);
  const token = await new SignJWT({ role: user.role })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(user.id)
    .setIssuedAt()
    .setExpirationTime("30d")
    .sign(appSecret());
  return { token, user };
}

/** Verify an Apple/Google identity token against the provider's JWKS. Bad tokens → 401. */
async function verifyIdentityToken(provider: string, idToken: string): Promise<ProviderClaims> {
  try {
    if (provider === "apple") {
      const { payload } = await jwtVerify(idToken, appleJwks, {
        issuer: "https://appleid.apple.com",
        audience: APPLE_AUD,
      });
      return { sub: String(payload.sub), email: payload.email as string | undefined };
    }
    if (provider === "google") {
      const { payload } = await jwtVerify(idToken, googleJwks, {
        issuer: ["https://accounts.google.com", "accounts.google.com"],
        audience: GOOGLE_AUD,
      });
      return { sub: String(payload.sub), email: payload.email as string | undefined };
    }
    throw new HttpError(400, "Unknown auth provider");
  } catch (err) {
    if (err instanceof HttpError) throw err;
    throw new HttpError(401, "Invalid identity token");
  }
}

/** Validate our app session JWT (from the Authorization header) and load the user. */
export async function requireUser(request: HttpRequest): Promise<User> {
  const header = request.headers.get("authorization") ?? "";
  const match = /^Bearer (.+)$/i.exec(header);
  if (!match) throw new HttpError(401, "Missing bearer token");

  let userId: string;
  try {
    const { payload } = await jwtVerify(match[1], appSecret());
    userId = String(payload.sub);
  } catch {
    throw new HttpError(401, "Invalid or expired session");
  }

  const pool = await getPool();
  const res = await pool
    .request()
    .input("id", sql.UniqueIdentifier, userId)
    .query("SELECT * FROM dbo.Users WHERE id = @id");
  if (res.recordset.length === 0) throw new HttpError(401, "User not found");
  return mapUser(res.recordset[0]);
}

/** Server-side role/status gate. Client gating is UX only. */
export function assertRole(user: User, min: Role): void {
  if (user.status !== "active") throw new HttpError(403, "Account pending approval");
  const rank: Record<Role, number> = { resident: 0, eventCoordinator: 1, boardMember: 2 };
  if (rank[user.role] < rank[min]) throw new HttpError(403, "Insufficient role");
}

async function getOrCreateUser(providerSub: string, email: string, name?: string): Promise<User> {
  const pool = await getPool();
  const existing = await pool
    .request()
    .input("sub", sql.NVarChar, providerSub)
    .query("SELECT * FROM dbo.Users WHERE authProviderSub = @sub");
  if (existing.recordset.length > 0) return mapUser(existing.recordset[0]);

  const displayName = name && name.trim() ? name.trim() : email.split("@")[0] || "New neighbor";
  const created = await pool
    .request()
    .input("sub", sql.NVarChar, providerSub)
    .input("email", sql.NVarChar, email)
    .input("name", sql.NVarChar, displayName)
    .query(
      `INSERT INTO dbo.Users (name, email, authProviderSub)
       OUTPUT INSERTED.* VALUES (@name, @email, @sub)`
    );
  return mapUser(created.recordset[0]);
}

function mapUser(r: Record<string, unknown>): User {
  const dues = r.duesPaidThrough as Date | null;
  return {
    id: r.id as string,
    name: r.name as string,
    email: r.email as string,
    phone: (r.phone as string) ?? null,
    role: r.role as Role,
    status: r.status as User["status"],
    membershipStatus: r.membershipStatus as User["membershipStatus"],
    duesPaidThrough: dues ? new Date(dues).toISOString().slice(0, 10) : null,
    householdId: (r.householdId as string) ?? null,
    authProviderSub: r.authProviderSub as string,
    emailVisibleToNeighbors: Boolean(r.emailVisibleToNeighbors),
  };
}
