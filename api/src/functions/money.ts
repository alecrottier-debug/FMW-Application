import { app, HttpRequest } from "@azure/functions";
import { assertRole, requireUser } from "../lib/auth";
import { getPool, sql } from "../lib/db";
import { errorResponse, HttpError, json } from "../lib/http";

// GET /api/events/{id}/summary — the committee money dashboard, reconciled from the
// real ledger (coordinator+). Money in = paid Orders + their OrderLines + Payments
// (by source); money out = Expenses (spent, and owed back to volunteers). Everything
// ties back to line items so "who paid for what" and "sales by item" always reconcile.
app.http("eventMoneySummary", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "events/{id}/summary",
  handler: async (request: HttpRequest) => {
    try {
      const user = await requireUser(request);
      assertRole(user, "eventCoordinator");
      const eventId = request.params.id;

      const pool = await getPool();
      const ev = await pool
        .request()
        .input("id", sql.UniqueIdentifier, eventId)
        .query("SELECT id, title, budgetTarget FROM dbo.Events WHERE id = @id");
      if (ev.recordset.length === 0) throw new HttpError(404, "Event not found");
      const event = ev.recordset[0];

      const q = (text: string) =>
        pool.request().input("id", sql.UniqueIdentifier, eventId).query(text);

      const [collected, spent, paymentsIn, salesByItem, orders, orderLines, owed] =
        await Promise.all([
          q(`SELECT ISNULL(SUM(total), 0) AS v FROM dbo.Orders WHERE eventId = @id AND status = 'paid'`),
          q(`SELECT ISNULL(SUM(amount), 0) AS v FROM dbo.Expenses WHERE eventId = @id`),
          q(`SELECT p.source, COUNT(*) AS cnt, ISNULL(SUM(p.amount), 0) AS amount
             FROM dbo.Payments p
             JOIN dbo.Orders o ON o.id = p.orderId
             WHERE o.eventId = @id
             GROUP BY p.source
             ORDER BY amount DESC`),
          q(`SELECT i.id AS itemId, i.name, i.price AS unitPrice,
                    ISNULL(SUM(ol.quantity), 0) AS quantity,
                    ISNULL(SUM(ol.lineTotal), 0) AS amount
             FROM dbo.EventItems i
             LEFT JOIN dbo.OrderLines ol ON ol.eventItemId = i.id
             LEFT JOIN dbo.Orders o ON o.id = ol.orderId AND o.status = 'paid'
             WHERE i.eventId = @id
             GROUP BY i.id, i.name, i.price, i.sortOrder
             ORDER BY i.sortOrder`),
          q(`SELECT o.id AS orderId, o.userId, u.name, o.total, o.createdAt,
                    (SELECT TOP 1 source FROM dbo.Payments WHERE orderId = o.id) AS method
             FROM dbo.Orders o
             JOIN dbo.Users u ON u.id = o.userId
             WHERE o.eventId = @id AND o.status = 'paid'
             ORDER BY o.createdAt DESC`),
          q(`SELECT ol.orderId, ol.quantity, ol.lineTotal, i.name
             FROM dbo.OrderLines ol
             JOIN dbo.EventItems i ON i.id = ol.eventItemId
             JOIN dbo.Orders o ON o.id = ol.orderId
             WHERE o.eventId = @id AND o.status = 'paid'`),
          q(`SELECT x.paidByUserId AS userId, u.name,
                    ISNULL(SUM(x.amount), 0) AS owed,
                    MAX(x.merchant) AS merchant, MAX(x.category) AS category
             FROM dbo.Expenses x
             JOIN dbo.Users u ON u.id = x.paidByUserId
             WHERE x.eventId = @id AND x.reimbursedStatus = 'owed'
             GROUP BY x.paidByUserId, u.name
             ORDER BY owed DESC`),
        ]);

      // Group order lines under their order for "who paid for what".
      const linesByOrder = new Map<string, Array<{ label: string; value: number }>>();
      for (const l of orderLines.recordset as Record<string, unknown>[]) {
        const oid = l.orderId as string;
        const list = linesByOrder.get(oid) ?? [];
        list.push({ label: `${l.quantity} × ${l.name}`, value: Number(l.lineTotal) });
        linesByOrder.set(oid, list);
      }

      const collectedTotal = Number(collected.recordset[0].v);
      const spentTotal = Number(spent.recordset[0].v);

      return json(200, {
        event: {
          id: event.id,
          title: event.title,
          budgetTarget: event.budgetTarget != null ? Number(event.budgetTarget) : null,
        },
        budget: {
          collected: collectedTotal,
          spent: spentTotal,
          budget: event.budgetTarget != null ? Number(event.budgetTarget) : null,
        },
        paymentsIn: (paymentsIn.recordset as Record<string, unknown>[]).map((r) => ({
          source: r.source as string,
          count: Number(r.cnt),
          amount: Number(r.amount),
        })),
        salesByItem: (salesByItem.recordset as Record<string, unknown>[]).map((r) => ({
          itemId: r.itemId as string,
          name: r.name as string,
          unitPrice: Number(r.unitPrice),
          quantity: Number(r.quantity),
          amount: Number(r.amount),
        })),
        whoPaidWhat: (orders.recordset as Record<string, unknown>[]).map((o) => ({
          orderId: o.orderId as string,
          userId: o.userId as string,
          name: o.name as string,
          method: (o.method as string) ?? null,
          date: o.createdAt ? new Date(o.createdAt as string).toISOString() : null,
          total: Number(o.total),
          lines: linesByOrder.get(o.orderId as string) ?? [],
        })),
        owedToVolunteers: (owed.recordset as Record<string, unknown>[]).map((r) => ({
          userId: r.userId as string,
          name: r.name as string,
          detail: [r.merchant, r.category].filter(Boolean).join(" · ") || null,
          owed: Number(r.owed),
        })),
      });
    } catch (e) {
      return errorResponse(e);
    }
  },
});
