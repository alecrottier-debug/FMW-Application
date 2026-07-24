import { HttpRequest } from "@azure/functions";
import { createRemoteJWKSet, jwtVerify } from "jose";
import { getPool, sql } from "./db";
import { HttpError } from "./http";
import { Role, User } from "./types";

// Entra External ID token validation (issuer / audience / signature via JWKS).
const issuer = process.env.ENTRA_ISSUER;
const audience = process.env.ENTRA_AUDIENCE;
const jwksUri = process.env.ENTRA_JWKS_URI;

let jwks: ReturnType<typeof createRemoteJWKSet> | null = null;
function getJwks() {
  if (!jwksUri) throw new HttpError(500, "ENTRA_JWKS_URI is not configured");
  if (!jwks) jwks = createRemoteJWKSet(new URL(jwksUri));
  return jwks;
}

interface Claims {
  sub: string;
  email?: string;
  name?: string;
  preferred_username?: string;
}

/** Validate the bearer token and return the mapped User (creating a pending one on first sign-in). */
export async function requireUser(request: HttpRequest): Promise<User> {
  const header = request.headers.get("authorization") ?? "";
  const match = /^Bearer (.+)$/i.exec(header);
  if (!match) throw new HttpError(401, "Missing bearer token");

  let claims: Claims;
  try {
    const { payload } = await jwtVerify(match[1], getJwks(), { issuer, audience });
    claims = payload as unknown as Claims;
  } catch {
    throw new HttpError(401, "Invalid token");
  }
  if (!claims.sub) throw new HttpError(401, "Token missing subject");
  return getOrCreateUser(claims);
}

async function getOrCreateUser(claims: Claims): Promise<User> {
  const pool = await getPool();
  const existing = await pool
    .request()
    .input("sub", sql.NVarChar, claims.sub)
    .query("SELECT * FROM dbo.Users WHERE authProviderSub = @sub");
  if (existing.recordset.length > 0) return mapUser(existing.recordset[0]);

  // First sign-in → create a pending user (board approves to active for residency).
  const email = claims.email ?? claims.preferred_username ?? "";
  const name = claims.name ?? email.split("@")[0] ?? "New neighbor";
  const created = await pool
    .request()
    .input("sub", sql.NVarChar, claims.sub)
    .input("email", sql.NVarChar, email)
    .input("name", sql.NVarChar, name)
    .query(
      `INSERT INTO dbo.Users (name, email, authProviderSub)
       OUTPUT INSERTED.* VALUES (@name, @email, @sub)`
    );
  return mapUser(created.recordset[0]);
}

/** Server-side role/status gate. Client gating is UX only. */
export function assertRole(user: User, min: Role): void {
  if (user.status !== "active") throw new HttpError(403, "Account pending approval");
  const rank: Record<Role, number> = { resident: 0, eventCoordinator: 1, boardMember: 2 };
  if (rank[user.role] < rank[min]) throw new HttpError(403, "Insufficient role");
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
