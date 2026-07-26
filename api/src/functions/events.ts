import { app, HttpRequest } from "@azure/functions";
import { assertRole, requireUser } from "../lib/auth";
import { getPool, sql } from "../lib/db";
import { errorResponse, HttpError, json } from "../lib/http";
import { roleAtLeast } from "../lib/types";

// GET /api/events — published events for everyone; coordinators/board also see drafts.
app.http("listEvents", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "events",
  handler: async (request: HttpRequest) => {
    try {
      const user = await requireUser(request);
      const canSeeDrafts = roleAtLeast(user.role, "eventCoordinator");
      const pool = await getPool();
      const result = await pool.request().query(
        `SELECT e.*, (SELECT COUNT(*) FROM dbo.EventItems i WHERE i.eventId = e.id) AS itemCount
         FROM dbo.Events e
         ${canSeeDrafts ? "" : "WHERE e.status = 'published'"}
         ORDER BY e.startAt`
      );
      return json(200, { events: result.recordset.map(mapEvent) });
    } catch (e) {
      return errorResponse(e);
    }
  },
});

// GET /api/events/{id} — event with its paid items.
app.http("getEvent", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "events/{id}",
  handler: async (request: HttpRequest) => {
    try {
      const user = await requireUser(request);
      const id = request.params.id;
      const pool = await getPool();
      const ev = await pool
        .request()
        .input("id", sql.UniqueIdentifier, id)
        .query("SELECT * FROM dbo.Events WHERE id = @id");
      if (ev.recordset.length === 0) throw new HttpError(404, "Event not found");
      // Unpublished (draft) events are coordinator/board-only — don't leak them.
      if (ev.recordset[0].status !== "published" && !roleAtLeast(user.role, "eventCoordinator")) {
        throw new HttpError(404, "Event not found");
      }
      const items = await pool
        .request()
        .input("id", sql.UniqueIdentifier, id)
        .query("SELECT * FROM dbo.EventItems WHERE eventId = @id ORDER BY sortOrder");
      return json(200, { ...mapEvent(ev.recordset[0]), items: items.recordset.map(mapItem) });
    } catch (e) {
      return errorResponse(e);
    }
  },
});

// POST /api/events — create an event with 0..n paid items (coordinator+). Transactional.
app.http("createEvent", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "events",
  handler: async (request: HttpRequest) => {
    try {
      const user = await requireUser(request);
      assertRole(user, "eventCoordinator");
      const body = (await request.json()) as CreateEventBody;
      if (!body.title || !body.startAt) throw new HttpError(400, "title and startAt are required");

      const pool = await getPool();
      const tx = new sql.Transaction(pool);
      await tx.begin();
      try {
        const created = await new sql.Request(tx)
          .input("title", sql.NVarChar, body.title)
          .input("startAt", sql.DateTime2, new Date(body.startAt))
          .input("endAt", sql.DateTime2, body.endAt ? new Date(body.endAt) : null)
          .input("location", sql.NVarChar, body.location ?? null)
          .input("audience", sql.NVarChar, body.audience ?? null)
          .input("description", sql.NVarChar, body.description ?? null)
          .input("ticketingType", sql.VarChar, body.ticketingType ?? "free")
          .input("budgetTarget", sql.Decimal(10, 2), body.budgetTarget ?? null)
          .input("visibility", sql.VarChar, body.visibility ?? "all")
          .input("status", sql.VarChar, body.status ?? "draft")
          .input("createdBy", sql.UniqueIdentifier, user.id)
          .query(
            `INSERT INTO dbo.Events
               (title, startAt, endAt, location, audience, description, ticketingType, budgetTarget, visibility, status, createdBy)
             OUTPUT INSERTED.*
             VALUES (@title, @startAt, @endAt, @location, @audience, @description, @ticketingType, @budgetTarget, @visibility, @status, @createdBy)`
          );
        const eventId = created.recordset[0].id as string;

        let sortOrder = 0;
        for (const item of body.items ?? []) {
          await new sql.Request(tx)
            .input("eventId", sql.UniqueIdentifier, eventId)
            .input("name", sql.NVarChar, item.name)
            .input("price", sql.Decimal(10, 2), item.price)
            .input("itemLimit", sql.Int, item.limit ?? null)
            .input("sortOrder", sql.Int, sortOrder++)
            .input("isOptional", sql.Bit, item.isOptional ? 1 : 0)
            .query(
              `INSERT INTO dbo.EventItems (eventId, name, price, itemLimit, sortOrder, isOptional)
               VALUES (@eventId, @name, @price, @itemLimit, @sortOrder, @isOptional)`
            );
        }
        await tx.commit();
        return json(201, mapEvent(created.recordset[0]));
      } catch (err) {
        await tx.rollback();
        throw err;
      }
    } catch (e) {
      return errorResponse(e);
    }
  },
});

interface CreateEventBody {
  title: string;
  startAt: string;
  endAt?: string;
  location?: string;
  audience?: string;
  description?: string;
  ticketingType?: "free" | "paid";
  budgetTarget?: number;
  visibility?: "all" | "invite";
  status?: "draft" | "published";
  items?: Array<{ name: string; price: number; limit?: number; isOptional?: boolean }>;
}

function mapEvent(r: Record<string, unknown>) {
  return {
    id: r.id,
    title: r.title,
    startAt: new Date(r.startAt as string).toISOString(),
    endAt: r.endAt ? new Date(r.endAt as string).toISOString() : null,
    location: (r.location as string) ?? null,
    audience: (r.audience as string) ?? null,
    description: (r.description as string) ?? null,
    ticketingType: r.ticketingType,
    budgetTarget: r.budgetTarget ?? null,
    visibility: r.visibility,
    status: r.status,
    itemCount: typeof r.itemCount === "number" ? r.itemCount : undefined,
  };
}

function mapItem(r: Record<string, unknown>) {
  return {
    id: r.id,
    name: r.name,
    price: r.price,
    limit: (r.itemLimit as number) ?? null,
    sortOrder: r.sortOrder,
    isOptional: Boolean(r.isOptional),
  };
}
