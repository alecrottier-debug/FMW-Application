import { app, HttpRequest } from "@azure/functions";
import { assertRole, mapUser, requireUser } from "../lib/auth";
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

// PATCH /api/users/me — the signed-in user edits their own account details
// (name, phone, whether their email is visible to neighbors). Any member.
app.http("updateMe", {
  methods: ["PATCH", "POST"],
  authLevel: "anonymous",
  route: "users/me",
  handler: async (request: HttpRequest) => {
    try {
      const user = await requireUser(request);
      const body = (await request.json()) as {
        name?: string;
        phone?: string | null;
        emailVisibleToNeighbors?: boolean;
      };

      const pool = await getPool();
      const req = pool.request().input("id", sql.UniqueIdentifier, user.id);
      const sets: string[] = [];
      const name = body.name?.trim();
      if (name) {
        req.input("name", sql.NVarChar, name);
        sets.push("name = @name");
      }
      if (body.phone !== undefined) {
        const phone = body.phone && body.phone.trim() ? body.phone.trim() : null;
        req.input("phone", sql.NVarChar, phone);
        sets.push("phone = @phone");
      }
      if (body.emailVisibleToNeighbors !== undefined) {
        req.input("evn", sql.Bit, body.emailVisibleToNeighbors ? 1 : 0);
        sets.push("emailVisibleToNeighbors = @evn");
      }
      if (sets.length === 0) throw new HttpError(400, "Nothing to update");

      const res = await req.query(
        `UPDATE dbo.Users SET ${sets.join(", ")} OUTPUT INSERTED.* WHERE id = @id`
      );
      await audit(user.id, "user.updateSelf", user.id, sets.join(", "));
      return json(200, mapUser(res.recordset[0]));
    } catch (e) {
      return errorResponse(e);
    }
  },
});

// POST /api/users/{id}/status  { "status": "active" | "pending" } — board activates
// (approves/adds) or suspends (removes access for) a member. Suspended members drop
// to 'pending', which fails the active-status gate on every protected action.
app.http("setUserStatus", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "users/{id}/status",
  handler: async (request: HttpRequest) => {
    try {
      const actor = await requireUser(request);
      assertRole(actor, "boardMember");
      const id = request.params.id;
      if (id === actor.id) throw new HttpError(400, "You can’t change your own status");
      const body = (await request.json()) as { status?: string };
      if (body.status !== "active" && body.status !== "pending") {
        throw new HttpError(400, "status must be 'active' or 'pending'");
      }
      const pool = await getPool();
      const res = await pool
        .request()
        .input("id", sql.UniqueIdentifier, id)
        .input("status", sql.VarChar, body.status)
        .query("UPDATE dbo.Users SET status = @status OUTPUT INSERTED.id WHERE id = @id");
      if (res.recordset.length === 0) throw new HttpError(404, "Member not found");
      await audit(actor.id, "user.status", id, body.status);
      return json(200, { ok: true, status: body.status });
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
      if (id === actor.id) throw new HttpError(400, "You can’t change your own role");
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
