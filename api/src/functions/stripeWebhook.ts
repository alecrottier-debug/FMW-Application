import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";

/**
 * Stripe webhook receiver (stub).
 *
 * Stripe cannot present Azure Functions keys, so this endpoint is "anonymous" at the
 * platform layer and MUST instead be secured by verifying the `Stripe-Signature`
 * header against STRIPE_WEBHOOK_SECRET (from Key Vault) before trusting the payload.
 *
 * Payments rule (spec §8a): never mark dues paid on submit. For ACH the money settles
 * asynchronously, so membershipStatus flips to `paid` only when the verified
 * `payment_intent.succeeded` (or charge success) event arrives here; a `payment_failed`
 * event reverts status and notifies the treasurer. Wired in build-order phase 5.
 */
export async function stripeWebhook(
  request: HttpRequest,
  context: InvocationContext
): Promise<HttpResponseInit> {
  const signature = request.headers.get("stripe-signature");
  const payload = await request.text();
  context.log(
    `stripe webhook received: ${payload.length} bytes, signed=${signature !== null}`
  );

  // TODO(phase 5): construct the event via the Stripe SDK using the raw body +
  // signature + STRIPE_WEBHOOK_SECRET, then dispatch on event.type.
  return { status: 200, jsonBody: { received: true } };
}

app.http("stripeWebhook", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "stripe/webhook",
  handler: stripeWebhook,
});
