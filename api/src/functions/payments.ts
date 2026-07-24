import { app, HttpRequest } from "@azure/functions";
import { requireUser } from "../lib/auth";
import { getPool, sql } from "../lib/db";
import { errorResponse, HttpError, json } from "../lib/http";
import { stripe } from "../lib/stripe";

// POST /api/payments/intent  { eventId, lines: [{ eventItemId, quantity }] }
// Prices every line SERVER-SIDE (never trust client amounts), writes a pending
// Order + OrderLines, and returns a Stripe PaymentIntent client secret.
app.http("createPaymentIntent", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "payments/intent",
  handler: async (request: HttpRequest) => {
    try {
      const user = await requireUser(request);
      const body = (await request.json()) as {
        eventId: string;
        lines: Array<{ eventItemId: string; quantity: number }>;
      };
      if (!body.eventId || !body.lines?.length) {
        throw new HttpError(400, "eventId and lines are required");
      }

      const pool = await getPool();
      const itemsRes = await pool
        .request()
        .input("eventId", sql.UniqueIdentifier, body.eventId)
        .query("SELECT id, price, name FROM dbo.EventItems WHERE eventId = @eventId");
      const priceById = new Map<string, number>(
        itemsRes.recordset.map((r: Record<string, unknown>) => [r.id as string, Number(r.price)])
      );

      let total = 0;
      const lines = body.lines.map((line) => {
        const unit = priceById.get(line.eventItemId);
        if (unit === undefined) throw new HttpError(400, `Unknown item ${line.eventItemId}`);
        const qty = Math.max(1, Math.trunc(line.quantity));
        const lineTotal = unit * qty;
        total += lineTotal;
        return { eventItemId: line.eventItemId, quantity: qty, unitPrice: unit, lineTotal };
      });
      if (total <= 0) throw new HttpError(400, "Order total must be positive");

      // Persist a pending order + its line items (this is the "who paid for what" record).
      const tx = new sql.Transaction(pool);
      await tx.begin();
      let orderId: string;
      try {
        const order = await new sql.Request(tx)
          .input("eventId", sql.UniqueIdentifier, body.eventId)
          .input("userId", sql.UniqueIdentifier, user.id)
          .input("total", sql.Decimal(10, 2), total)
          .query(
            `INSERT INTO dbo.Orders (eventId, userId, total, status)
             OUTPUT INSERTED.id VALUES (@eventId, @userId, @total, 'pending')`
          );
        orderId = order.recordset[0].id as string;
        for (const l of lines) {
          await new sql.Request(tx)
            .input("orderId", sql.UniqueIdentifier, orderId)
            .input("eventItemId", sql.UniqueIdentifier, l.eventItemId)
            .input("quantity", sql.Int, l.quantity)
            .input("unitPrice", sql.Decimal(10, 2), l.unitPrice)
            .input("lineTotal", sql.Decimal(10, 2), l.lineTotal)
            .query(
              `INSERT INTO dbo.OrderLines (orderId, eventItemId, quantity, unitPrice, lineTotal)
               VALUES (@orderId, @eventItemId, @quantity, @unitPrice, @lineTotal)`
            );
        }
        await tx.commit();
      } catch (err) {
        await tx.rollback();
        throw err;
      }

      const intent = await stripe().paymentIntents.create({
        amount: Math.round(total * 100),
        currency: "usd",
        automatic_payment_methods: { enabled: true },
        metadata: { kind: "order", orderId, userId: user.id },
      });

      return json(200, { clientSecret: intent.client_secret, orderId, total });
    } catch (e) {
      return errorResponse(e);
    }
  },
});

// POST /api/dues/intent  { method: "ach" | "card" }
// Bank (ACH) is offered first — far cheaper — but settles asynchronously, so the
// DuesPayment stays 'pending' and membership flips only on the webhook success.
app.http("createDuesIntent", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "dues/intent",
  handler: async (request: HttpRequest) => {
    try {
      const user = await requireUser(request);
      const body = (await request.json()) as { method: "ach" | "card" };
      const method = body.method === "card" ? "card" : "ach";

      const pool = await getPool();
      const period = await pool
        .request()
        .query("SELECT TOP 1 * FROM dbo.DuesPeriods WHERE isActive = 1 ORDER BY year DESC");
      if (period.recordset.length === 0) throw new HttpError(400, "No active dues period");
      const amount = Number(period.recordset[0].amount);

      const created = await pool
        .request()
        .input("periodId", sql.UniqueIdentifier, period.recordset[0].id)
        .input("userId", sql.UniqueIdentifier, user.id)
        .input("amount", sql.Decimal(10, 2), amount)
        .input("method", sql.VarChar, method)
        .query(
          `INSERT INTO dbo.DuesPayments (duesPeriodId, userId, amount, method, status)
           OUTPUT INSERTED.id VALUES (@periodId, @userId, @amount, @method, 'pending')`
        );
      const duesPaymentId = created.recordset[0].id as string;

      const intent = await stripe().paymentIntents.create({
        amount: Math.round(amount * 100),
        currency: "usd",
        payment_method_types: method === "ach" ? ["us_bank_account"] : ["card"],
        statement_descriptor: "FOX MILL WOODS DUES",
        metadata: { kind: "dues", duesPaymentId, userId: user.id },
      });

      return json(200, { clientSecret: intent.client_secret, duesPaymentId, amount });
    } catch (e) {
      return errorResponse(e);
    }
  },
});
