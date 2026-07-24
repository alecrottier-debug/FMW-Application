# Fox Mill Woods — iPhone Application Specification

**Product:** Fox Mill Woods (neighborhood app; umbrella brand)
**First module owner:** The Crooked Fox Collective (events committee)
**Platform:** iOS 17+ (iPhone), SwiftUI
**Backend:** Azure
**Author of build:** Claude Code in VS Code (GitHub + Xcode + Azure)
**Status:** Design validated; ready to build

---

## 1. Overview

Fox Mill Woods is a mobile-first neighborhood app. It launches with two live modules — **Events** (run by the Crooked Fox Collective) and **Pavilion Rentals** — and a shell designed to grow into a whole-neighborhood app without re-architecting navigation. Residents discover, RSVP, and pay for events and book the community pavilion; coordinators create and run events and track the money; the board administers members and oversees all finances.

The visual language is bright and sunny — pine green and sunset orange on cream and mint — drawn from the Fox Mill Woods Swim & Tennis Club identity.

## 2. Roles & permissions

Three roles, each inheriting the one below it.

| Capability | Resident | Event Coordinator | Board Member |
|---|:--:|:--:|:--:|
| RSVP/pay events, book pavilion, **pay annual dues**, own wallet & tickets | ✓ | ✓ | ✓ |
| Create & edit events, define paid items (event editor) | — | ✓ | ✓ |
| Manage event money (budget, receipts, expenses, reimbursements) | — | ✓ own events | ✓ all events |
| See who paid for which item | — | ✓ own events | ✓ all events |
| Scan receipts | — | ✓ | ✓ |
| **Directory** — see names + emails | ✓ | ✓ | ✓ |
| Directory — see phone numbers | — | ✓ | ✓ |
| Directory — see dues paid/unpaid (+ filter/sort by it) | — | ✓ | ✓ |
| Directory — see home addresses | — | — | ✓ |
| Directory — approvals, role assignment, dues changes | — | — | ✓ |
| All-event finances, reconciliation, export | — | — | ✓ |
| Neighborhood settings & announcements | — | — | ✓ |

### Directory field visibility (enforce at the API, not the client)

| Field | Resident | Coordinator | Board |
|---|:--:|:--:|:--:|
| Name | ✓ | ✓ | ✓ |
| Email | ✓ | ✓ | ✓ |
| Phone | — | ✓ | ✓ |
| Dues status (paid/unpaid) | — | ✓ | ✓ |
| Home address | — | — | ✓ |
| Pending (unapproved) members | — | — | ✓ |

**The API must return different field sets per role** — never send addresses or dues status to a resident client and hide them in the UI. Residents and coordinators don't see pending sign-ups at all.

Coordinators are the Crooked Fox Collective. Roles are stored server-side and enforced by the API (never trust client-side gating alone).

## 3. Information architecture

A stable five-tab shell (functions, not features) so new modules never add a tab:

- **Home** — neighborhood hub: next event, notices, and a module grid (Events, Pavilion, **Directory**, and **Pool & Tennis** all live). New modules surface here.
- **Events** — list → detail → RSVP/pay → My Tickets. Coordinators get "create/manage."
- **Calendar** — cross-module, filterable by type (Events, Rentals, +future), month grid + agenda.
- **Wallet** — residents: tickets & payments. Coordinators/board: the money dashboard.
- **You** — profile, role, connected accounts (Apple/Google), settings; board gets member admin.

Scan is **not** a tab — it's a coordinator/board action inside the money context.

## 4. Screen inventory

1. **Auth** — Sign in with Apple / Google.
2. **Home** — hero next-event ticket, module grid, notices.
3. **Events** — upcoming list; coordinator "plan a new event" entry.
4. **Event detail** — info, attendees, RSVP (free) or **itemized checkout** for paid events: each paid item listed with price and a quantity stepper, running total, then pay.
5. **Event editor** *(coordinator/board)* — name, date/time, location, audience, description, ticketing (Free/RSVP or **Paid items**), **a repeater of paid items** (name, price, optional limit — add/remove any number), RSVP deadline, budget target, coordinators, visibility, save draft / publish.
6. **Pavilion Rentals** — details, month picker (open/booked), instant book, pay fee.
7. **Calendar** — filter chips, month grid with type dots, agenda list.
8. **Wallet (resident)** — **annual dues card at the top** (amount owed / paid-through, tap to pay), season total, **itemized ticket stubs** (line items purchased), receipts.
8a. **Dues payment** *(resident)* — membership amount and coverage period, **payment method choice: bank account (ACH) or card**, ACH authorization (mandate) text, total, pay. Bank is presented first and labeled lowest-fee.
9. **Money dashboard (coordinator/board)** — event selector, budget ring, payments-in by source, **sales by item** (qty sold + revenue per item), **who paid for what** (per-person line-item records, exportable), per-person reimbursements owed, ⊕ Scan receipt.
10. **Scan** *(coordinator/board)* — camera → on-device parse → review expense → assign person + event + category → save.
11. **Directory** *(all roles, tiered fields)* — search plus a **compact single-row list (~52pt rows) with an A–Z index rail down the right edge** for fast scrolling; rows are grouped under letter headers when sorted by name (the rail disables itself for other sorts). Each row: avatar, name, a role tag for Board/Coordinator, one truncated detail line, and a dues status dot. Visible fields depend on role (see §2). Residents get a neighbor count and sort by name or role. Coordinators additionally get phone, dues status, dues stats, and filter/sort by dues. Board additionally gets addresses, pending sign-ups, approvals, role assignment, and sort by address.
12. **Pool & Tennis** *(all roles)* — opening and closing times only: a prominent "today" card plus pool hours (weekday/weekend, adult swim) and tennis court hours. No teams, bookings, or rosters in v1.
12. **You** — profile, role chip, connected accounts, payment methods, notifications, account deletion.

## 5. Data model (core entities)

- **User** — id, name, email, **phone**, role (resident/coordinator/board), status (pending/active), **membershipStatus (paid/unpaid)**, **duesPaidThrough** (date), householdId, authProviderSub, **emailVisibleToNeighbors** (bool, default true).
- **Household** — id, address (residency verification), members[].
- **FacilityHours** — id, facility (pool/tennis), dayRange, opensAt, closesAt, note (e.g. "Adult swim"). *Powers the Pool & Tennis screen; board-editable later.*
- **Event** — id, title, start/end, locationId, audience, description, ticketing {type: free|paid}, budgetTarget, coordinatorIds[], visibility, status (draft/published).
- **EventItem** — id, eventId, name, price, limit (nullable), sortOrder, isOptional. *An event has 0..n items; free events have none.*
- **Order** — id, eventId, userId, total, paymentId, createdAt, status.
- **OrderLine** — id, orderId, eventItemId, quantity, unitPrice, lineTotal. *This is the "who paid for what" record; roll up by item for sales, by user for purchase history.*
- **DuesPeriod** — id, year, amount, dueDate, coverageStart, coverageEnd, description. *Board-configurable; one active period at a time.*
- **DuesPayment** — id, duesPeriodId, userId (or householdId), amount, paymentId, method (ach/card/cash/check), status (pending/succeeded/failed), paidAt. *On success, set the user's `membershipStatus` to paid and `duesPaidThrough` to the period end — this is what the Directory reads.*
- **PavilionBooking** — id, date, block, userId, fee, paymentId, status.
- **Payment (in)** — id, orderId|bookingId, userId, amount, source (card/venmo/cash/check), stripeRef?, loggedBy (for manual), timestamp.
- **Expense (out)** — id, eventId, paidByUserId, merchant, date, amount, tax, category, receiptBlobUrl, reimbursedStatus.
- **AuditLog** — actorId, action, target, timestamp (admin/financial actions, incl. dues status changes).

**Key queries:** sales-by-item = `OrderLine` grouped by `eventItemId`; who-paid-for-what = `Order` + `OrderLine` grouped by `userId`; directory = `User` **projected to a role-specific DTO** (ResidentDirectoryDTO: name, email · CoordinatorDirectoryDTO: + phone, membershipStatus · BoardDirectoryDTO: + address, status), filtered/sorted by membershipStatus, name, address, or role.

## 6. Azure architecture

- **API:** Azure Functions (Flex Consumption) — REST endpoints, role checks, Stripe webhook handler.
- **Database:** Azure SQL Database, serverless tier (auto-pause) — relational fit for the entities above. (Cosmos DB serverless is the NoSQL alternative.)
- **Receipt images:** Azure Blob Storage (private container; SAS or API-proxied reads).
- **Auth:** Microsoft Entra External ID federating Apple + Google (pre-configured social IdPs; satisfies App Store 4.8). App uses the native/browser-delegated flow; Functions validate issued tokens.
- **Secrets:** Azure Key Vault (Stripe keys, IdP client secrets).
- **Payments:** Stripe (iOS SDK / PaymentSheet); webhook → Function → Azure SQL.
- **OCR:** on-device VisionKit `DataScannerViewController` primary; Azure AI Document Intelligence prebuilt-receipt model optional server-side.
- **Infra as code:** Bicep, provisioned/deployed with `azd`. CI/CD via GitHub Actions.

## 7. Authentication

- Sign in with Apple (native) and Google via Entra External ID as the identity broker.
- App receives tokens; Azure Functions validate issuer/audience/signature and map to the User record.
- No passwords stored by the app. On first sign-in, create a `pending` user; board approves to `active` (residency verification).

## 8. Payments & multi-source tracking

- Card payments via Stripe iOS SDK (PaymentSheet) — card data goes directly to Stripe.
- **Bank payments (ACH Direct Debit)** for dues and larger amounts — see §8a.
- An order may contain **multiple line items** (e.g. 2 × adult ticket + 1 × T-shirt); the payment intent covers the order total, and `OrderLine` rows preserve exactly what each person bought.
- Manual sources (Venmo, cash, check) logged by a coordinator/board member with `loggedBy` attribution — still recorded as an Order with line items, so item-level reporting stays complete regardless of payment source.
- All payments roll up per event in the money dashboard: by source, by item, and by person. Reconciliation compares total collected vs. records.

## 8a. Annual dues & ACH Direct Debit

Residents pay annual dues in-app. Bank payment is offered first because it is dramatically cheaper at dues-sized amounts.

**Why ACH here:** bank debits save up to roughly 70% per transaction versus cards. On $250 dues that's the difference between a card fee of several dollars and a capped ACH fee — meaningful across ~200 households.

**Implementation:**
- Enable **US bank account** as a payment method in the Stripe Dashboard; PaymentSheet then offers it alongside card.
- Bank account collection uses **Stripe Financial Connections** to instantly verify the account, with manual account/routing entry plus microdeposit verification as fallback (microdeposits take 1–2 business days to appear).
- **The customer must authorize the payment terms and the bank account must be verified** — the app must display mandate/authorization text at the point of payment (the prototype shows this wording).
- Only **USD from US bank accounts**, and the Stripe account must have a US bank account to accept ACH.
- Save the verified account to the Stripe Customer so future years are one tap.

**Operational realities to design for:**
- ACH is a **delayed-notification method: acknowledgement of success or failure can take up to 4 business days**, so dues must show a **`pending` state** in the UI and in the Directory — do *not* mark a member paid on submission; flip `membershipStatus` only on the webhook's `succeeded` event.
- **ACH isn't guaranteed — payments can fail after the fact** (and Stripe charges a failure fee), so handle `payment_failed` by reverting status and notifying the treasurer.
- **Nacha compliance:** Stripe tightened ACH requirements to align with Nacha rules; the account must be configured so members can identify the payer on their bank statement and contact the group. Set a clear statement descriptor ("FOX MILL WOODS DUES") and complete the transaction-classification setting in the Dashboard.

## 9. Receipt capture → expense

- VisionKit scans on device; parse merchant, date, total (and tax when present).
- Coordinator reviews/edits, assigns paid-by person + event + category.
- Image stored in Blob; expense recorded; per-person reimbursement total updates.

## 10. Compliance validation

**PCI DSS:** Stripe iOS SDK keeps card data off your servers → **SAQ A** (simplest tier). Never store PAN/CVV; use Stripe tokens for saved cards. Bank details are collected by Financial Connections and never touch your servers either. Merchant still owns basics (patching, logging, TLS, ASV scan if internet-facing IPs are in scope) under PCI DSS 4.0.1.

**ACH/Nacha:** display authorization (mandate) text before debiting, set a recognizable statement descriptor, and complete Stripe's transaction-classification setting. Never mark dues paid before the webhook confirms success.

**Data privacy:** Virginia VCDPA applies only at 100k+ consumers (or 25k+ with data-sale revenue) and exempts nonprofits — not triggered here, but follow its principles: privacy notice, purpose limitation, data minimization, deletion rights. **The directory is the app's main privacy surface**: it exposes member data to other members, so the role-based field tiers in §2 must be enforced by the API returning role-specific DTOs — a client-side filter is not a control. Home addresses are board-only; dues status is board+coordinator only and never visible to residents (in a small neighborhood, who hasn't paid is socially sensitive); phone is board+coordinator only. Residents can opt out of sharing their email with neighbors (`emailVisibleToNeighbors`). Every dues or role change is written to the audit log. Entra handles credentials.

**App Store:**
- **3.1.3 / 3.1.5** — event tickets & pavilion rentals are real-world services consumed outside the app → use external payment (Stripe/Apple Pay), **not** in-app purchase.
- **4.8** — offering Google sign-in requires Sign in with Apple (satisfied via Entra).
- **5.1.1(v)** — in-app account deletion required (You → delete account).
- Complete the App Privacy "nutrition label" accurately.

**Financial controls (community-treasurer best practice):** segregation of duties (coordinators log, board approves reimbursements), full audit trail with attached receipts, reconciliation across all sources, per-person tracking, per-event exportable ledger.

*Outside app scope:* confirm the group's legal/tax status (association vs. nonprofit) with a professional; the app keeps clean exportable records regardless. This section is not legal or financial advice.

## 11. Build order

0. Repo + `azd` scaffold + `CLAUDE.md` + design tokens + TabView shell (building & deploying an empty API).
1. Entra External ID + Apple/Google sign-in; token validation; users + households; approval flow.
2. Events (iOS + Events API + SQL), including `EventItem` and the event editor's item repeater.
3. Pavilion Rentals + shared filterable Calendar.
4. Wallet + coordinator/board money dashboard + role-gating.
5. Stripe + multi-source payments + `Order`/`OrderLine` (who paid for what) + Key Vault + webhook Function.
5a. **Annual dues + ACH Direct Debit**: `DuesPeriod`/`DuesPayment`, PaymentSheet with US bank account enabled, Financial Connections verification, mandate text, pending→succeeded/failed webhook handling that drives `membershipStatus`.
6. Scan (VisionKit) → Blob → expense assignment & per-person tracking.
7. **Directory** (all roles, tiered DTOs): compact rows + A–Z index, dues status, filter/sort, approvals, role assignment. **Pool & Tennis** hours screen (small — can ride along).
8. Polish: account deletion, email-visibility opt-out, audit log, exports (sales-by-item, who-paid-for-what, per-event ledger).

## 12. Out of scope (v1) / future modules

Pool & Tennis beyond hours (swim team, lessons, court booking), Marketplace, Alerts, Governance/voting, dues autopay/recurring renewal, household-level dues splitting — future spokes that plug into the same shell, Calendar, and Wallet. `FacilityHours` becomes board-editable when Pool & Tennis grows; the saved ACH mandate makes next year's dues a one-tap renewal.
