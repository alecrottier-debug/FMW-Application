import braintree from "braintree";

// Braintree (a PayPal service) gateway — Apple Pay + card + PayPal for event/rental
// checkout, settling to the merchant's bank. Credentials come from Key Vault.
let gateway: braintree.BraintreeGateway | null = null;

export function bt(): braintree.BraintreeGateway {
  if (!gateway) {
    const merchantId = process.env.BRAINTREE_MERCHANT_ID;
    const publicKey = process.env.BRAINTREE_PUBLIC_KEY;
    const privateKey = process.env.BRAINTREE_PRIVATE_KEY;
    if (!merchantId || !publicKey || !privateKey) {
      throw new Error("Braintree credentials are not configured");
    }
    gateway = new braintree.BraintreeGateway({
      environment:
        process.env.BRAINTREE_ENVIRONMENT === "production"
          ? braintree.Environment.Production
          : braintree.Environment.Sandbox,
      merchantId,
      publicKey,
      privateKey,
    });
  }
  return gateway;
}

/** Map a Braintree payment instrument to our Payments.source enum. */
export function sourceFor(instrument: string | undefined): string {
  switch (instrument) {
    case "paypal_account":
      return "paypal";
    case "apple_pay_card":
      return "applepay";
    case "venmo_account":
      return "venmo";
    default:
      return "card";
  }
}

export { braintree };
