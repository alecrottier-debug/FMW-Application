import { getPool, sql } from "./db";

/** Append to AuditLog. Every dues/role/financial change must be recorded (spec §10). */
export async function audit(
  actorId: string | null,
  action: string,
  target: string | null,
  detail?: string | null
): Promise<void> {
  const pool = await getPool();
  await pool
    .request()
    .input("actor", sql.UniqueIdentifier, actorId)
    .input("action", sql.NVarChar, action)
    .input("target", sql.NVarChar, target)
    .input("detail", sql.NVarChar, detail ?? null)
    .query(
      "INSERT INTO dbo.AuditLog (actorId, action, target, detail) VALUES (@actor, @action, @target, @detail)"
    );
}
