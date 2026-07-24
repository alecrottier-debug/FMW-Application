import { app, HttpRequest } from "@azure/functions";
import { requireUser } from "../lib/auth";
import { getPool, sql } from "../lib/db";
import { errorResponse, HttpError, json } from "../lib/http";
import { bt, sourceFor } from "../lib/braintree";

// GET /api/braintree/client-token — token the iOS drop-in needs to start checkout.
app.http("braintreeClientToken", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "braintree/client-token",
  handler: async (request: HttpRequest) => {
    try {
      await requireUser(request);
      const result = await bt().clientToken.generate({});
      return json(200, { clientToken: result.clientToken });
    } catch (e) {
      return errorResponse(e);
    }
  },
});

// POST /api/braintree/checkout { eventId, lines:[{eventItemId, quantity}], paymentMethodNonce }
// Prices every line SERVER-SIDE, writes a pending Order + OrderLines, charges via
// Braintree (Apple Pay / card / PayPal) WITH the line items, then reconciles.
app.http("braintreeCheckout", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "braintree/checkout",
  handler: async (request: HttpRequest) => {
    try {
      const user = await requireUser(request);
      const body = (await request.json()) as {
        eventId: string;
        lines: Array<{ eventItemId: string; quantity: number }>;
        paymentMethodNonce: string;
      };
      if (!body.eventId || !body.lines?.length || !body.paymentMethodNonce) {
        throw new HttpError(400, "eventId, lines, and paymentMethodNonce are required");
      }

      const pool = await getPool();
      const itemsRes = await pool
        .request()
        .input("eventId", sql.UniqueIdentifier, body.eventId)
        .query("SELECT id, price, name FROM dbo.EventItems WHERE eventId = @eventId");
      const catalog = new Map<string, { price: number; name: string }>(
        itemsRes.recordset.map((r: Record<string, unknown>) => [
          r.id as string,
          { price: Number(r.price), name: String(r.name) },
        ])
      );

      let total = 0;
      const btLineItems: Array<{
        name: string;
        kind: "debit";
        quantity: string;
        unitAmount: string;
        totalAmount: string;
      }> = [];
      const lines = body.lines.map((line) => {
        const item = catalog.get(line.eventItemId);
        if (!item) throw new HttpError(400, `Unknown item ${line.eventItemId}`);
        const qty = Math.max(1, Math.trunc(line.quantity));
        const lineTotal = item.price * qty;
        total += lineTotal;
        btLineItems.push({
          name: item.name.slice(0, 35), // Braintree caps line-item names at 35 chars
          kind: "debit",
          quantity: String(qty),
          unitAmount: item.price.toFixed(2),
          totalAmount: lineTotal.toFixed(2),
        });
        return { eventItemId: line.eventItemId, quantity: qty, unitPrice: item.price, lineTotal };
      });
      if (total <= 0) throw new HttpError(400, "Order total must be positive");

      // Persist the pending order + line items (the "who paid for what" record).
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

      // Charge via Braintree WITH the itemized detail (shows on the PayPal receipt).
      const sale = await bt().transaction.sale({
        amount: total.toFixed(2),
        paymentMethodNonce: body.paymentMethodNonce,
        orderId,
        lineItems: btLineItems,
        options: { submitForSettlement: true },
      });

      if (!sale.success || !sale.transaction) {
        await pool
          .request()
          .input("id", sql.UniqueIdentifier, orderId)
          .query("UPDATE dbo.Orders SET status = 'canceled' WHERE id = @id");
        throw new HttpError(402, sale.message || "Payment was declined");
      }

      await pool
        .request()
        .input("id", sql.UniqueIdentifier, orderId)
        .query("UPDATE dbo.Orders SET status = 'paid' WHERE id = @id");
      await pool
        .request()
        .input("orderId", sql.UniqueIdentifier, orderId)
        .input("userId", sql.UniqueIdentifier, user.id)
        .input("amount", sql.Decimal(10, 2), total)
        .input("source", sql.VarChar, sourceFor(sale.transaction.paymentInstrumentType))
        .input("ref", sql.NVarChar, sale.transaction.id)
        .query(
          `INSERT INTO dbo.Payments (orderId, userId, amount, source, stripeRef)
           VALUES (@orderId, @userId, @amount, @source, @ref)`
        );

      return json(200, { orderId, status: "paid", transactionId: sale.transaction.id });
    } catch (e) {
      return errorResponse(e);
    }
  },
});
