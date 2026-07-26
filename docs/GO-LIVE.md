# Go-live checklist

App + API + infra are **build-verified**. They're **not live** — that needs accounts and
secrets only you can create. Nothing secret is committed; everything is read from Key Vault
/ Info.plist. Until set, the app runs in **demo mode** (sign-in skipped, sample data, pay
buttons report "not configured").

## 1. Azure (database + API)
```bash
azd auth login && azd env new fmw-dev
azd env set SQL_ADMIN_PASSWORD '<strong-password>'
azd up
sqlcmd -S <sql-server>.database.windows.net -d foxmillwoods -G -i infra/sql/schema.sql
```
Grant the Function App's managed identity a DB login (`CREATE USER [<func-app>] FROM EXTERNAL PROVIDER;` + db_datareader/db_datawriter). Seed one active `DuesPeriods` row.

## 2. Sign-in — native Apple + Google
- **Apple**: the app already has the *Sign in with Apple* entitlement. Make sure the App ID `com.foxmillwoods.app` has that capability enabled (automatic signing does this).
- **Google**: create an OAuth **iOS client** at console.cloud.google.com → copy the client id. Put it in `project.yml` `info.properties` → `GOOGLE_CLIENT_ID`, and set the reversed-client-id **URL scheme** (`com.googleusercontent.apps.<id>`), then `xcodegen generate`. Also set the Function app setting: `azd env set GOOGLE_CLIENT_ID <id>`.
- **Session secret**: `az keyvault secret set --vault-name <kv> --name app-jwt-secret --value <long-random-string>` (signs our own session tokens).

## 3. Payments
### Events / rentals — **Braintree** (Apple Pay + card + PayPal → your bank)
- Create a Braintree account (**sandbox** first), connect your bank, enable **PayPal** + **Apple Pay**.
- Key Vault: `braintree-merchant-id`, `braintree-public-key`, `braintree-private-key`. Set `BRAINTREE_ENVIRONMENT` (`sandbox`→`production` when ready).
- **Apple Pay**: create an Apple Pay **Merchant ID** + add the `in-app-payments` entitlement so the Drop-in shows the Apple Pay button (card + PayPal work without it).
### Dues — **Stripe ACH** (kept, low fee)
- Stripe account; enable **US bank account** (ACH). Key Vault: `stripe-secret-key`, `stripe-webhook-secret`. iOS `STRIPE_PUBLISHABLE_KEY`. Register the webhook → `https://<func-app>/api/stripe/webhook`.

## 4. iOS distribution — TestFlight
`DEVELOPMENT_TEAM` is set. One command: **`scripts/beta.sh`** (Admin API key in `scripts/private/`, Issuer id in `scripts/beta.env`). First distribution build already uploaded.

## Not built yet
Pavilion booking payment, receipt scan → Blob upload, dues autopay, money-dashboard
reconciliation endpoints, and wiring Event detail/editor to live API data (Events **list**
is already wired). Note: **CLAUDE.md still describes the original Stripe + Entra design** —
the live stack is now Braintree (events) + Stripe (dues) + native Apple/Google auth.
