import { app, HttpRequest } from "@azure/functions";
import { assertRole, requireUser } from "../lib/auth";
import { getPool, sql } from "../lib/db";
import { errorResponse, HttpError, json } from "../lib/http";
import { stripe } from "../lib/stripe";

// Annual dues stay on Stripe (low-fee ACH bank debit). Events/rentals go through
// Braintree (see braintree.ts). Bank (ACH) is offered first — far cheaper — but
// settles asynchronously, so the DuesPayment stays 'pending' and membership flips
// only on the Stripe webhook success (spec §8a).
app.http("createDuesIntent", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "dues/intent",
  handler: async (request: HttpRequest) => {
    try {
      const user = await requireUser(request);
      assertRole(user, "resident"); // active members only
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
