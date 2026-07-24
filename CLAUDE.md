# CLAUDE.md — Fox Mill Woods

Neighborhood iOS app. Start with Events (Crooked Fox Collective) + Pavilion Rentals; grow into a whole-neighborhood app. Build the app into the existing Xcode project; back it with Azure.

## Sources of truth
- `Design/prototype.html` — the visual & interaction spec. Match layout, palette, and flows to it. Screenshot the simulator and compare before marking a screen done.
- `fox-mill-woods-ios-spec.md` — the PRD: roles, IA, screens, data model, Azure architecture, compliance. Build against it feature by feature.

## Stack & conventions
- iOS 17+, **Swift 6**, **SwiftUI**, **MVVM with `@Observable`**, Swift Package Manager.
- Networking: `async/await` + `URLSession`; no third-party networking unless asked.
- Avoid `AnyView`. Prefer a `@ViewBuilder` generic or an `enum` switch that returns concrete views — SwiftUI diffing relies on stable view identity.
- Use design tokens from `DesignTokens.swift` (colors + Fraunces/Figtree). No hardcoded hex or font names in views.
- Accessibility: label controls, respect Dynamic Type and reduced motion.

## Navigation (do not add tabs)
Stable 5-tab shell: **Home · Events · Calendar · Wallet · You**. New modules surface on Home, never as new tabs. Scan is a coordinator/board action inside the money context, not a tab.

## Roles (enforce server-side)
`resident` ⊂ `eventCoordinator` ⊂ `boardMember`. Client gating is UX only; the Azure API is the authority. See the permission matrix in the spec.

## Two things that are easy to get wrong
- **Events have many paid items, not one price.** Model `EventItem` (name, price, limit) and `Order`/`OrderLine`. Every purchase — card, Venmo, cash, or check — writes line items, so "who paid for what" and "sales by item" always reconcile. Never collapse an order to a single amount.
- **Directory fields are tiered by role, enforced server-side.** Return a different DTO per role — resident: name + email only; coordinator: + phone + dues status; board: + address + pending members + management. Never send a field the role can't see and hide it in SwiftUI; a client-side filter is not an access control. Dues status is never visible to residents. Log every dues/role change to `AuditLog`. UI: compact ~52pt rows in a `List` with `.listStyle(.plain)`, section headers by first letter, and a native A–Z section index when sorted by name.
- **ACH dues are asynchronous — never mark paid on submit.** Bank payments can take up to 4 business days to confirm and can fail afterward. Show a `pending` state, and flip `membershipStatus` to paid only on the Stripe webhook's success event; revert and notify on failure. Always render the ACH authorization (mandate) text before debiting.

## Azure
- **Deploy with `azd`, never `az` for deployments** (parallel provisioning, faster). Infra is Bicep under `infra/`.
- Services: Azure Functions (API + Stripe webhook), Azure SQL serverless (data), Blob (receipts), Entra External ID (Apple/Google auth), Key Vault (secrets). Never commit secrets — read from Key Vault / GitHub secrets.
- Validate Entra tokens (issuer/audience/signature) in the API and map to the User record.

## Payments & compliance (must hold)
- Card payments via the **Stripe iOS SDK / PaymentSheet** — card data goes directly to Stripe. Never store PAN/CVV; use Stripe tokens. This keeps us at PCI **SAQ A**.
- Event tickets & pavilion rentals are real-world services → **external payment, not in-app purchase** (App Store 3.1.3/3.1.5).
- Provide **in-app account deletion** (5.1.1(v)). Data minimization: address only for residency verification, board-visible, deletable.

## Xcode project hygiene
- New Swift files must be added to the target. Use **XcodeGen/Tuist** so Claude-created files land in the project automatically; commit a minimal `project.pbxproj` before sessions. Do not hand-edit `.pbxproj`.
- Prefer XcodeBuildMCP for build/test/simulator; pipe `xcodebuild` errors back and self-fix in a generate → build → test loop.

## Workflow
- Plan before coding on each module. Small increments. One module = iOS slice + API slice + PR.
- Commit per increment; open a PR with simulator screenshots. Keep manual approval on merges and prod deploys.
- Write tests (Swift Testing / XCTest) for models and API mapping; `swift test --filter` for fast TDD.
