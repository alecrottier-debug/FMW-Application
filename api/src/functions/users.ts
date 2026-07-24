import { app, HttpRequest } from "@azure/functions";
import { assertRole, requireUser } from "../lib/auth";
import { getPool, sql } from "../lib/db";
import { audit } from "../lib/audit";
import { errorResponse, HttpError, json } from "../lib/http";

// GET /api/users/me — the signed-in user's own record (all fields).
app.http("usersMe", {
  methods: ["GET"],
  authLevel: "anonymous", // secured by Entra bearer-token validation, not a function key
  route: "users/me",
  handler: async (request: HttpRequest) => {
    try {
      const user = await requireUser(request);
      return json(200, user);
    } catch (e) {
      return errorResponse(e);
    }
  },
});

// POST /api/users/{id}/approve — board approves a pending sign-up to active.
app.http("approveUser", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "users/{id}/approve",
  handler: async (request: HttpRequest) => {
    try {
      const actor = await requireUser(request);
      assertRole(actor, "boardMember");
      const id = request.params.id;
      const pool = await getPool();
      await pool
        .request()
        .input("id", sql.UniqueIdentifier, id)
        .query("UPDATE dbo.Users SET status = 'active' WHERE id = @id");
      await audit(actor.id, "user.approve", id);
      return json(200, { ok: true });
    } catch (e) {
      return errorResponse(e);
    }
  },
});

// POST /api/users/{id}/role  { "role": "eventCoordinator" } — board assigns a role.
app.http("setUserRole", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "users/{id}/role",
  handler: async (request: HttpRequest) => {
    try {
      const actor = await requireUser(request);
      assertRole(actor, "boardMember");
      const id = request.params.id;
      const body = (await request.json()) as { role?: string };
      const role = body.role;
      if (role !== "resident" && role !== "eventCoordinator" && role !== "boardMember") {
        throw new HttpError(400, "Invalid role");
      }
      const pool = await getPool();
      await pool
        .request()
        .input("id", sql.UniqueIdentifier, id)
        .input("role", sql.VarChar, role)
        .query("UPDATE dbo.Users SET role = @role WHERE id = @id");
      await audit(actor.id, "user.role", id, role);
      return json(200, { ok: true });
    } catch (e) {
      return errorResponse(e);
    }
  },
});
