import { app, HttpRequest } from "@azure/functions";

// GET /api/privacy — the public privacy policy (anonymous). Serves as the App Store
// privacyPolicyUrl and the in-app "Privacy policy" link. Reflects the app's actual
// data practices (spec §10): role-tiered directory, tokenized payments (no card
// storage), address only for residency, and in-app account deletion.
const UPDATED = "2026-07-26";

const HTML = `<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Fox Mill Woods — Privacy Policy</title>
<style>
  :root { color-scheme: light dark; }
  body { font: 16px/1.6 -apple-system, system-ui, sans-serif; max-width: 720px;
         margin: 0 auto; padding: 28px 20px 64px; color: #143229; background: #FBFAF3; }
  @media (prefers-color-scheme: dark) { body { color: #EAF4EC; background: #12201B; } }
  h1 { font-size: 26px; color: #2E7D63; }
  h2 { font-size: 18px; margin-top: 28px; }
  a { color: #2E7D63; }
  .muted { color: #6b7a72; font-size: 14px; }
  ul { padding-left: 20px; }
</style></head><body>
<h1>Fox Mill Woods — Privacy Policy</h1>
<p class="muted">Last updated: ${UPDATED}</p>

<p>Fox Mill Woods is a private app for the Fox Mill Woods neighborhood. It helps
residents discover and pay for neighborhood events, book the community pavilion,
pay annual dues, and find neighbors in a member directory. This policy explains
what we collect, how we use it, and your choices.</p>

<h2>What we collect</h2>
<ul>
  <li><strong>Account &amp; profile:</strong> your name, email, and (optionally) phone number, from your Apple or Google sign-in. We do not store passwords.</li>
  <li><strong>Home address:</strong> collected only for residency verification, visible only to board members, and deletable.</li>
  <li><strong>Membership &amp; activity:</strong> your role, dues status, event RSVPs and orders, and pavilion bookings.</li>
  <li><strong>Payments:</strong> card and bank details are entered directly into our payment processors (Stripe and PayPal/Braintree) and are <strong>never stored by Fox Mill Woods</strong>. We keep only a payment reference and the amounts/line items.</li>
  <li><strong>Receipts (coordinators):</strong> images of expense receipts you scan are stored in a private, access-controlled location.</li>
</ul>

<h2>How we use it</h2>
<ul>
  <li>To run neighborhood events, process dues and ticket payments, and reconcile the community's finances.</li>
  <li>To show a member directory to other residents, with <strong>role-tiered visibility</strong>: residents see names and emails; coordinators additionally see phone and dues status; board members additionally see home addresses and pending sign-ups. Dues status is never shown to residents.</li>
  <li>You can opt out of sharing your email with neighbors at any time (You → Edit profile).</li>
</ul>

<h2>How we share it</h2>
<p>We do not sell your personal data. Limited profile fields are shown to other
members through the directory as described above. Payments are processed by Stripe
and PayPal/Braintree under their own privacy policies. Sign-in is handled by Apple
and Google.</p>

<h2>Retention &amp; deletion</h2>
<p>You can delete your account in the app (You → Delete account). This removes your
personal information (name, email, phone, address) and disconnects your sign-in.
Financial records required for the community's bookkeeping may be retained in
anonymized form. Every dues and role change is recorded in an internal audit log.</p>

<h2>Security</h2>
<p>Data is transmitted over TLS and stored in access-controlled Azure services.
Card data is handled entirely by our PCI-compliant payment processors and never
touches our servers.</p>

<h2>Children</h2>
<p>Fox Mill Woods is intended for neighborhood residents managing household
membership and is not directed to children under 13.</p>

<h2>Contact</h2>
<p>Questions or requests: <a href="mailto:alec.rottier@gmail.com">alec.rottier@gmail.com</a>.</p>
</body></html>`;

app.http("privacyPolicy", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "privacy",
  handler: async (_request: HttpRequest) => ({
    status: 200,
    headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "public, max-age=3600" },
    body: HTML,
  }),
});
