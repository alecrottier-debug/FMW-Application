import { app, HttpRequest } from "@azure/functions";
import { assertRole, requireUser } from "../lib/auth";
import { getPool } from "../lib/db";
import { errorResponse, json } from "../lib/http";
import { Role, roleAtLeast } from "../lib/types";

// GET /api/directory — role-tiered member directory.
//
// The API returns a DIFFERENT field set per role (spec §2/§10). Never send a
// field the viewer can't see and hide it on the client — this projection *is*
// the access control. Residents: name + email only. Coordinators: + phone +
// dues status. Board: + address + pending members.
app.http("directory", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "directory",
  handler: async (request: HttpRequest) => {
    try {
      const viewer = await requireUser(request);
      assertRole(viewer, "resident"); // any active member

      const includePending = viewer.role === "boardMember";
      const pool = await getPool();
      const result = await pool.request().query(
        `SELECT u.id, u.name, u.email, u.phone, u.role, u.status,
                u.membershipStatus, u.emailVisibleToNeighbors, h.address
         FROM dbo.Users u
         LEFT JOIN dbo.Households h ON h.id = u.householdId
         ${includePending ? "" : "WHERE u.status = 'active'"}
         ORDER BY u.name`
      );

      const neighbors = result.recordset.map((r: Record<string, unknown>) =>
        project(r, viewer.role)
      );
      return json(200, { neighbors, count: neighbors.length });
    } catch (e) {
      return errorResponse(e);
    }
  },
});

function project(r: Record<string, unknown>, viewerRole: Role) {
  const dto: Record<string, unknown> = {
    id: r.id,
    name: r.name,
    role: r.role,
    // Residents may opt out of sharing their email with neighbors.
    email: r.emailVisibleToNeighbors ? r.email : null,
  };
  if (roleAtLeast(viewerRole, "eventCoordinator")) {
    dto.phone = (r.phone as string) ?? null;
    dto.membershipStatus = r.membershipStatus; // dues status: coordinator + board only
  }
  if (viewerRole === "boardMember") {
    dto.address = (r.address as string) ?? null;
    dto.status = r.status; // pending vs active
  }
  return dto;
}
