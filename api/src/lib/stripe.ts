import Stripe from "stripe";

// Stripe client. STRIPE_SECRET_KEY comes from Key Vault in Azure (never in code).
let client: Stripe | null = null;

export function stripe(): Stripe {
  if (!client) {
    const key = process.env.STRIPE_SECRET_KEY;
    if (!key) throw new Error("STRIPE_SECRET_KEY is not configured");
    client = new Stripe(key);
  }
  return client;
}

export { Stripe };
