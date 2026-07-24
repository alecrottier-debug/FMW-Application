# Go-live checklist

The app + API + infra for **auth (step 1)**, **events (step 2)**, and **payments (step 5/5a)**
are written and build-verified. They are **not live** — that requires accounts and secrets
only you can create. Nothing secret is committed; all of it is read from Key Vault / Info.plist.

Until these are set, the app runs in **demo mode**: sign-in is skipped, screens show sample
data, and "Pay" reports that payments aren't configured.

## 1. Azure (database + API)
```bash
azd auth login
azd env new fmw-dev
azd env set SQL_ADMIN_PASSWORD '<a-strong-password>'
azd up                     # provisions infra + deploys the API (Flex Consumption)
```
Then apply the schema (Entra auth to SQL):
```bash
sqlcmd -S <sql-server>.database.windows.net -d foxmillwoods -G -i infra/sql/schema.sql
```
Grant the Function App's managed identity a DB login (one-time, run as the SQL Entra admin):
```sql
CREATE USER [<func-app-name>] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [<func-app-name>];
ALTER ROLE db_datawriter ADD MEMBER [<func-app-name>];
```
Seed one active dues period and (optionally) FacilityHours.

## 2. Entra External ID (Apple + Google sign-in)
- Create an **External ID** tenant; add **Apple** and **Google** as social identity providers.
- Register **two apps**: an **API** app (its client id = audience) and a **public client** app
  for iOS (redirect `foxmillwoods://auth`, PKCE, no secret).
- Set backend values: `azd env set ENTRA_ISSUER …`, `ENTRA_AUDIENCE …`, `ENTRA_JWKS_URI …`, then `azd up`.
- Set iOS values in `project.yml` `info.properties` (then `xcodegen generate`):
  `API_BASE_URL`, `ENTRA_AUTHORIZE_URL`, `ENTRA_TOKEN_URL`, `ENTRA_CLIENT_ID`.
- First sign-in creates a **pending** user; a board member approves via `POST /users/{id}/approve`.

## 3. Stripe (payments + ACH)
- Create a Stripe account; in the Dashboard enable **US bank account** (ACH) and set the
  statement descriptor / transaction classification (Nacha).
- Put secrets in Key Vault (the Function reads them as references):
```bash
az keyvault secret set --vault-name <kv> --name stripe-secret-key    --value sk_test_xxx
az keyvault secret set --vault-name <kv> --name stripe-webhook-secret --value whsec_xxx
```
- Set the iOS **publishable** key in `project.yml` (`STRIPE_PUBLISHABLE_KEY`, `pk_test_…`).
- Add a webhook endpoint in Stripe → `https://<func-app>/api/stripe/webhook`, subscribed to
  `payment_intent.succeeded` and `payment_intent.payment_failed`.

## 4. iOS signing (device / TestFlight)
- Set `DEVELOPMENT_TEAM` in `project.yml` and add the **Sign in with Apple** capability.
- Event tickets / rentals stay **external payment** (not IAP) per App Store 3.1.3/3.1.5.

## What's intentionally not done yet
Pavilion booking payment, receipt scan → Blob upload, dues autopay, and full money-dashboard
reconciliation endpoints. The models/screens exist; wiring them follows the same patterns above.
