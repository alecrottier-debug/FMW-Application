import { app, HttpRequest, HttpResponseInit } from "@azure/functions";
import { audit } from "../lib/audit";
import { getPool, sql } from "../lib/db";
import { stripe, Stripe } from "../lib/stripe";

/**
 * Stripe webhook. Verifies the signature against STRIPE_WEBHOOK_SECRET, then drives
 * state from the *verified* event — never from client submission.
 *
 * Payments rule (spec §8a): for ACH the money settles asynchronously, so a
 * DuesPayment stays `pending` and membershipStatus flips to `paid` only on
 * `payment_intent.succeeded`; `payment_intent.payment_failed` reverts it and logs
 * for the treasurer.
 */
app.http("stripeWebhook", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "stripe/webhook",
  handler: async (request: HttpRequest): Promise<HttpResponseInit> => {
    const signature = request.headers.get("stripe-signature");
    const secret = process.env.STRIPE_WEBHOOK_SECRET;
    const payload = await request.text(); // raw body required for signature verification
    if (!signature || !secret) {
      return { status: 400, body: "Missing signature or webhook secret" };
    }

    let event: Stripe.Event;
    try {
      event = stripe().webhooks.constructEvent(payload, signature, secret);
    } catch (err) {
      return { status: 400, body: `Signature verification failed: ${(err as Error).message}` };
    }

    try {
      switch (event.type) {
        case "payment_intent.succeeded":
          await onSucceeded(event.data.object as Stripe.PaymentIntent);
          break;
        case "payment_intent.payment_failed":
          await onFailed(event.data.object as Stripe.PaymentIntent);
          break;
        default:
          break; // ignore unhandled event types
      }
      return { status: 200, jsonBody: { received: true } };
    } catch (err) {
      return { status: 500, body: (err as Error).message };
    }
  },
});

async function onSucceeded(pi: Stripe.PaymentIntent): Promise<void> {
  const meta = pi.metadata ?? {};
  const pool = await getPool();

  if (meta.kind === "dues" && meta.duesPaymentId) {
    await pool
      .request()
      .input("id", sql.UniqueIdentifier, meta.duesPaymentId)
      .input("piId", sql.NVarChar, pi.id)
      .query(
        "UPDATE dbo.DuesPayments SET status = 'succeeded', paidAt = SYSUTCDATETIME(), paymentId = @piId WHERE id = @id"
      );

    // Flip membership from the webhook (this is what the Directory reads).
    const row = await pool
      .request()
      .input("id", sql.UniqueIdentifier, meta.duesPaymentId)
      .query(
        `SELECT dp.userId, per.coverageEnd
         FROM dbo.DuesPayments dp
         JOIN dbo.DuesPeriods per ON per.id = dp.duesPeriodId
         WHERE dp.id = @id`
      );
    if (row.recordset.length > 0) {
      await pool
        .request()
        .input("userId", sql.UniqueIdentifier, row.recordset[0].userId)
        .input("through", sql.Date, row.recordset[0].coverageEnd ?? null)
        .query(
          "UPDATE dbo.Users SET membershipStatus = 'paid', duesPaidThrough = @through WHERE id = @userId"
        );
    }
    await audit(null, "dues.succeeded", meta.duesPaymentId as string, pi.id);
  } else if (meta.kind === "order" && meta.orderId) {
    await pool
      .request()
      .input("id", sql.UniqueIdentifier, meta.orderId)
      .query("UPDATE dbo.Orders SET status = 'paid', paymentId = NULL WHERE id = @id");
    // Record the payment-in (card via Stripe).
    await pool
      .request()
      .input("orderId", sql.UniqueIdentifier, meta.orderId)
      .input("userId", sql.UniqueIdentifier, meta.userId ?? null)
      .input("amount", sql.Decimal(10, 2), (pi.amount_received ?? pi.amount) / 100)
      .input("stripeRef", sql.NVarChar, pi.id)
      .query(
        `INSERT INTO dbo.Payments (orderId, userId, amount, source, stripeRef)
         VALUES (@orderId, @userId, @amount, 'card', @stripeRef)`
      );
    await audit(null, "order.paid", meta.orderId as string, pi.id);
  }
}

async function onFailed(pi: Stripe.PaymentIntent): Promise<void> {
  const meta = pi.metadata ?? {};
  const pool = await getPool();

  if (meta.kind === "dues" && meta.duesPaymentId) {
    await pool
      .request()
      .input("id", sql.UniqueIdentifier, meta.duesPaymentId)
      .query("UPDATE dbo.DuesPayments SET status = 'failed' WHERE id = @id");
    if (meta.userId) {
      await pool
        .request()
        .input("userId", sql.UniqueIdentifier, meta.userId)
        .query("UPDATE dbo.Users SET membershipStatus = 'unpaid' WHERE id = @userId");
    }
    await audit(null, "dues.failed", meta.duesPaymentId as string, "ACH failed — notify treasurer");
  } else if (meta.kind === "order" && meta.orderId) {
    await pool
      .request()
      .input("id", sql.UniqueIdentifier, meta.orderId)
      .query("UPDATE dbo.Orders SET status = 'canceled' WHERE id = @id");
    await audit(null, "order.failed", meta.orderId as string, pi.id);
  }
}
