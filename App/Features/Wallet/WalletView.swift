import SwiftUI

/// Wallet — the money context (spec IA "Wallet"). Two role-driven variants:
///
///  • `resident`         → the personal WALLET: 2026 annual-dues card (owing),
///    a season balance, and itemized ticket stubs (every purchase is line items,
///    never a single amount).
///  • `eventCoordinator`+ → the committee MONEY DASHBOARD: event selector, a
///    budget ring (collected / spent / budget), payments-in by source, sales by
///    item, who-paid-for-what (line items reconcile), per-person reimbursements,
///    and a "Scan a receipt" action.
///
/// Built to match Design/prototype.html (data-screen="wallet"). Client gating is
/// UX only — the Azure API is the authority on what a role may see.
struct WalletView: View {
    let role: FMWRole

    init(role: FMWRole = .resident) {
        self.role = role
    }

    @State private var committeeTab: WalletCommitteeTab = .books

    private var isCommittee: Bool { role >= .eventCoordinator }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header

                if isCommittee {
                    WalletTabSwitch(selection: $committeeTab)
                        .padding(.horizontal, 18)
                        .padding(.top, 6)

                    switch committeeTab {
                    case .books: CommitteeDashboard()
                    case .mine:  ResidentWallet(showDues: false)
                    }
                } else {
                    ResidentWallet(showDues: true)
                }

                Color.clear.frame(height: 20)
            }
        }
        .scrollIndicators(.hidden)
        .background(FMW.cream.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Text("◱")
                    .font(FMW.ui(11, .bold))
                    .foregroundStyle(FMW.pine)
                Text("PAYMENTS")
                    .font(FMW.ui(11, .bold))
                    .tracking(1.5)
                    .foregroundStyle(FMW.pine)
            }
            Text(isCommittee ? "Money" : "Wallet")
                .font(FMW.display(26, .bold))
                .foregroundStyle(FMW.ink)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }
}

// MARK: - One-off shades (sampled from the prototype; never inline raw hex in a body)

private enum WalletShade {
    static let duesTop      = Color(hex: 0xE0673F)   // .duescard.owing gradient start
    static let duesDeep     = Color(hex: 0xB8452C)   // .duescard.owing gradient end + button text
    static let stripe       = Color(hex: 0x635BFF)   // .si-card (Stripe)
    static let venmo        = Color(hex: 0x008CFF)   // .si-venmo
    static let paypal       = Color(hex: 0x0070BA)   // PayPal blue
    static let avatarPurple = Color(hex: 0x8A7CC9)   // Mike K. avatar
}

// MARK: - Live-summary → row-model mapping (committee dashboard)

private enum WalletMap {
    static func money(_ v: Double) -> String { fmt(v, fraction: 2) }
    static func money0(_ v: Double) -> String { fmt(v, fraction: 0) }

    private static func fmt(_ v: Double, fraction: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = fraction
        f.minimumFractionDigits = fraction
        return f.string(from: v as NSNumber) ?? "$\(v)"
    }

    static func initials(_ name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "•" : String(letters).uppercased()
    }

    private static let palette: [Color] = [FMW.coral, FMW.water, WalletShade.avatarPurple, FMW.pine, FMW.sun]
    static func tint(_ i: Int) -> Color { palette[i % palette.count] }

    static func source(_ p: MoneySummaryDTO.PaymentSourceDTO) -> WalletSource {
        WalletSource(badge: badge(p.source), tint: sourceTint(p.source), name: sourceName(p.source),
                     detail: "\(p.count) payment\(p.count == 1 ? "" : "s")", amount: money(p.amount))
    }
    static func itemSale(_ it: MoneySummaryDTO.ItemSaleDTO, index: Int) -> WalletItemSale {
        WalletItemSale(tint: tint(index), name: it.name,
                       qtyTag: "\(it.quantity) SOLD · \(money(it.unitPrice)) EA", amount: money(it.amount))
    }
    static func payer(_ o: MoneySummaryDTO.OrderDTO, index: Int) -> WalletPayer {
        WalletPayer(initials: initials(o.name), tint: tint(index), name: o.name,
                    method: methodLabel(o.method, date: o.date), total: money(o.total),
                    lines: o.lines.map { WalletLineItem(label: $0.label, value: money($0.value)) })
    }
    static func reimbursement(_ w: MoneySummaryDTO.OwedDTO, index: Int) -> WalletReimbursement {
        WalletReimbursement(initials: initials(w.name), tint: tint(index), name: w.name,
                            detail: w.detail ?? "Reimbursement", owed: money(w.owed))
    }

    static func badge(_ s: String) -> String {
        switch s {
        case "card": "CARD"; case "applepay": "AP"; case "paypal": "PP"
        case "venmo": "V"; case "cash": "$"; case "check": "CK"; case "ach": "ACH"; default: "•"
        }
    }
    static func sourceName(_ s: String) -> String {
        switch s {
        case "card": "Card"; case "applepay": "Apple Pay"; case "paypal": "PayPal"
        case "venmo": "Venmo"; case "cash": "Cash"; case "check": "Check"; case "ach": "Bank · ACH"
        default: s.capitalized
        }
    }
    static func sourceTint(_ s: String) -> Color {
        switch s {
        case "card": WalletShade.stripe; case "venmo": WalletShade.venmo; case "paypal": WalletShade.paypal
        case "applepay": FMW.ink; case "cash": FMW.pine; case "ach": FMW.water; default: FMW.muted
        }
    }
    static func methodLabel(_ method: String?, date: String?) -> String {
        let label = method.map(sourceName) ?? "Paid"
        guard let date, let d = parseISO(date) else { return label }
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return "\(label) · \(f.string(from: d))"
    }
    private static func parseISO(_ s: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFraction.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }
}

/// A muted placeholder row for a dashboard section with no live data yet.
private struct WalletEmptyRow: View {
    let text: String
    var body: some View {
        Text(text)
            .font(FMW.ui(13))
            .foregroundStyle(FMW.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .walletCard()
    }
}

// MARK: - Committee tab switch (.wtabs)

private enum WalletCommitteeTab { case books, mine }

private struct WalletTabSwitch: View {
    @Binding var selection: WalletCommitteeTab

    var body: some View {
        HStack(spacing: 6) {
            tab("Event books", .books)
            tab("My tickets", .mine)
        }
        .padding(5)
        .background(FMW.mint)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func tab(_ title: String, _ value: WalletCommitteeTab) -> some View {
        let on = selection == value
        return Text(title)
            .font(FMW.ui(13.5, .bold))
            .foregroundStyle(FMW.pineDeep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                if on {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(FMW.paper)
                        .shadow(color: FMW.ink.opacity(0.14), radius: 10, x: 0, y: 6)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { selection = value }
            .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Resident wallet

private struct ResidentWallet: View {
    let showDues: Bool

    var body: some View {
        VStack(spacing: 0) {
            if showDues {
                NavigationLink(value: AppRoute.dues) {
                    WalletDuesCard()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.top, 14)
            }

            WalletBalanceCard()
                .padding(.horizontal, 12)
                .padding(.top, 14)

            WalletSectionHead(title: "My tickets")
                .padding(.horizontal, 18)
                .padding(.top, 22)
                .padding(.bottom, 10)

            VStack(spacing: 8) {
                ForEach(WalletTicket.samples) { ticket in
                    WalletTicketStub(ticket: ticket)
                }
            }
            .padding(.horizontal, 12)

            Color.clear.frame(height: 4)
        }
    }
}

private struct WalletDuesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("2026 ANNUAL DUES")
                .font(FMW.ui(12, .bold))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.9))
            Text("$250.00 due")
                .font(FMW.display(30, .bold))
                .foregroundStyle(.white)
                .padding(.top, 4)
            Text("Covers pool, tennis & neighborhood events · due Sep 1")
                .font(FMW.ui(12.5))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 3)

            Text("Pay dues →")
                .font(FMW.ui(14, .bold))
                .foregroundStyle(WalletShade.duesDeep)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(FMW.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, 14)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient(colors: [WalletShade.duesTop, WalletShade.duesDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(alignment: .topTrailing) { WalletSunGlow(opacity: 0.45) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("2026 annual dues, 250 dollars due September 1. Pay dues.")
        .accessibilityAddTraits(.isButton)
    }
}

private struct WalletBalanceCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Paid this season")
                .font(FMW.ui(12, .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text("$165.00")
                .font(FMW.display(34, .bold))
                .foregroundStyle(.white)
                .padding(.top, 3)
            Text("2 tickets · 1 pavilion booking")
                .font(FMW.ui(12))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient(colors: [FMW.pine, FMW.pineDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(alignment: .topTrailing) { WalletSunGlow(opacity: 0.5) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// The soft sunset glow bleeding off the top-right of the dues/balance cards.
private struct WalletSunGlow: View {
    var opacity: Double
    var body: some View {
        Circle()
            .fill(RadialGradient(
                colors: [FMW.sun2.opacity(opacity), FMW.sun2.opacity(0)],
                center: .center, startRadius: 0, endRadius: 65))
            .frame(width: 130, height: 130)
            .offset(x: 20, y: -30)
            .allowsHitTesting(false)
    }
}

// MARK: - Ticket stub (line items, not a single price)

private struct WalletTicketStub: View {
    let ticket: WalletTicket

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(ticket.kicker.uppercased())
                    .font(FMW.ui(11, .bold))
                    .tracking(1.3)
                    .foregroundStyle(FMW.sun)
                Text(ticket.title)
                    .font(FMW.display(19, .bold))
                    .foregroundStyle(FMW.ink)
                    .padding(.top, 4)
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FMW.pine)
                    Text(ticket.dateText)
                        .font(FMW.ui(13, .medium))
                        .foregroundStyle(FMW.pineDeep)
                }
                .padding(.top, 9)

                if !ticket.lines.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(ticket.lines) { line in
                            HStack {
                                Text(line.label)
                                    .font(FMW.ui(12.5, .semibold))
                                    .foregroundStyle(FMW.muted)
                                Spacer(minLength: 8)
                                Text(line.value)
                                    .font(FMW.ui(12.5, .semibold).monospacedDigit())
                                    .foregroundStyle(FMW.pineDeep)
                            }
                        }
                    }
                    .padding(.top, 10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            WalletPerforation()
                .frame(height: 20)
                .padding(.horizontal, 14)

            HStack {
                FMWPill(text: ticket.paidPill, bg: FMW.mint, fg: FMW.pineDeep)
                Spacer(minLength: 8)
                Text(ticket.refNo)
                    .font(FMW.ui(12, .bold).monospacedDigit())
                    .foregroundStyle(FMW.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(FMW.paper)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: FMW.ink.opacity(0.22), radius: 18, x: 0, y: 12)
    }
}

/// Dashed perforation with the two round notches bitten out of the stub's sides.
private struct WalletPerforation: View {
    var body: some View {
        Rectangle()
            .fill(FMW.line)
            .frame(height: 2)
            .frame(maxHeight: .infinity, alignment: .center)
            .overlay(alignment: .center) {
                WalletDashLine()
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .foregroundStyle(FMW.cream)
            }
            .overlay(alignment: .leading) { notch.offset(x: -24) }
            .overlay(alignment: .trailing) { notch.offset(x: 24) }
    }
    private var notch: some View {
        Circle()
            .fill(FMW.cream)
            .frame(width: 20, height: 20)
            .overlay(Circle().stroke(FMW.line.opacity(0.7), lineWidth: 1))
    }
}

private struct WalletDashLine: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: r.midY))
        p.addLine(to: CGPoint(x: r.width, y: r.midY))
        return p
    }
}

// MARK: - Committee money dashboard

private struct CommitteeDashboard: View {
    // Live books for the selected event; falls back to the prototype samples in
    // demo mode (no API) or before the first load, matching EventsView's pattern.
    @State private var events: [EventSummary] = []
    @State private var selectedTitle = "End-of-Summer Luau"
    @State private var summary: MoneySummaryDTO?

    private let demoTitles = ["End-of-Summer Luau", "Summer Sunset Social", "Fall Chili Cook-off"]
    private var titles: [String] { events.isEmpty ? demoTitles : events.map(\.title) }

    var body: some View {
        VStack(spacing: 0) {
            WalletEventSelector(selection: $selectedTitle, events: titles)
                .padding(.horizontal, 12)
                .padding(.top, 14)

            WalletBudgetRing(collected: collected, spent: spent, budget: budget)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            WalletSubhead(title: "Payments in", trailing: .text(paymentsTrailing))
            VStack(spacing: 8) {
                if sources.isEmpty {
                    WalletEmptyRow(text: "No payments in yet")
                } else {
                    ForEach(sources) { WalletSourceRow(source: $0) }
                }
            }
            .padding(.horizontal, 12)

            WalletSubhead(title: "Sales by item", trailing: .text(salesTrailing))
            VStack(spacing: 8) {
                if itemSales.isEmpty {
                    WalletEmptyRow(text: "No ticket sales yet")
                } else {
                    ForEach(itemSales) { WalletItemRow(item: $0) }
                }
            }
            .padding(.horizontal, 12)

            WalletSubhead(title: "Who paid for what", trailing: .link("Export →"))
            VStack(spacing: 8) {
                if payers.isEmpty {
                    WalletEmptyRow(text: "No orders yet")
                } else {
                    ForEach(payers) { WalletPaidWhatCard(payer: $0) }
                }
            }
            .padding(.horizontal, 12)

            WalletSubhead(title: "Owed back to volunteers", trailing: .link("Reimburse →"))
            VStack(spacing: 8) {
                if reimbursements.isEmpty {
                    WalletEmptyRow(text: "Nothing owed — all reimbursed")
                } else {
                    ForEach(reimbursements) { WalletPersonRow(person: $0) }
                }
            }
            .padding(.horizontal, 12)

            NavigationLink(value: AppRoute.scan) {
                WalletScanButton()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
            .padding(.top, 16)
        }
        .task { await loadInitial() }
        .onChange(of: selectedTitle) { Task { await loadSummary() } }
    }

    // MARK: Mapped rows (live summary → the existing row models, else samples)

    private var collected: Double { summary?.budget.collected ?? 840 }
    private var spent: Double { summary?.budget.spent ?? 285.55 }
    private var budget: Double? { summary != nil ? summary?.budget.budget : 1200 }

    private var sources: [WalletSource] {
        guard let s = summary else { return WalletSource.samples }
        return s.paymentsIn.map(WalletMap.source)
    }
    private var itemSales: [WalletItemSale] {
        guard let s = summary else { return WalletItemSale.samples }
        return s.salesByItem.filter { $0.quantity > 0 }.enumerated().map { WalletMap.itemSale($1, index: $0) }
    }
    private var payers: [WalletPayer] {
        guard let s = summary else { return WalletPayer.samples }
        return s.whoPaidWhat.enumerated().map { WalletMap.payer($1, index: $0) }
    }
    private var reimbursements: [WalletReimbursement] {
        guard let s = summary else { return WalletReimbursement.samples }
        return s.owedToVolunteers.enumerated().map { WalletMap.reimbursement($1, index: $0) }
    }
    private var paymentsTrailing: String {
        guard let s = summary else { return "\(WalletSource.samples.count) sources" }
        let n = s.paymentsIn.count
        return "\(n) source\(n == 1 ? "" : "s")"
    }
    private var salesTrailing: String {
        guard let s = summary else { return "$840.00" }
        return WalletMap.money(s.salesByItem.reduce(0) { $0 + $1.amount })
    }

    // MARK: Loading

    private func loadInitial() async {
        guard AppConfig.isAPIConfigured else { return }
        guard let list = try? await MoneyService().events(), !list.isEmpty else { return }
        events = list
        selectedTitle = list.first?.title ?? selectedTitle
        await loadSummary()
    }

    private func loadSummary() async {
        guard AppConfig.isAPIConfigured,
              let id = events.first(where: { $0.title == selectedTitle })?.id else {
            summary = nil
            return
        }
        summary = try? await MoneyService().summary(eventId: id)
    }
}

private struct WalletEventSelector: View {
    @Binding var selection: String
    let events: [String]

    var body: some View {
        HStack(spacing: 10) {
            Text("EVENT")
                .font(FMW.ui(11, .bold))
                .tracking(0.7)
                .foregroundStyle(FMW.muted)
            Spacer(minLength: 8)
            Menu {
                ForEach(events, id: \.self) { event in
                    Button(event) { selection = event }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selection)
                        .font(FMW.ui(14, .bold))
                        .foregroundStyle(FMW.pineDeep)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(FMW.pineDeep)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(FMW.mint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .walletCard()
    }
}

/// The budget donut: pine (collected) → sun (spent) → mint2 (remaining budget),
/// with a paper hole and a "$X collected" center label. Arc lengths are
/// proportional to the real ledger; the denominator grows if collected+spent
/// exceeds the budget so it still renders cleanly.
private struct WalletBudgetRing: View {
    let collected: Double
    let spent: Double
    let budget: Double?

    var body: some View {
        let denom = max(budget ?? 0, collected + spent, 1)
        let pineEnd = min(collected / denom, 1)
        let sunEnd = min((collected + spent) / denom, 1)
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: FMW.pine,  location: 0.0),
                            .init(color: FMW.pine,  location: pineEnd),
                            .init(color: FMW.sun,   location: pineEnd),
                            .init(color: FMW.sun,   location: sunEnd),
                            .init(color: FMW.mint2, location: sunEnd),
                            .init(color: FMW.mint2, location: 1.0),
                        ]),
                        center: .center,
                        startAngle: .degrees(-90), endAngle: .degrees(270)))
                    .frame(width: 96, height: 96)
                Circle()
                    .fill(FMW.paper)
                    .frame(width: 72, height: 72)
                VStack(spacing: 1) {
                    Text(WalletMap.money0(collected))
                        .font(FMW.display(18, .bold).monospacedDigit())
                        .foregroundStyle(FMW.ink)
                    Text("collected")
                        .font(FMW.ui(9.5, .bold))
                        .foregroundStyle(FMW.muted)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "Collected \(WalletMap.money(collected)), spent \(WalletMap.money(spent))"
                + (budget.map { ", budget \(WalletMap.money($0))" } ?? "") + ".")

            VStack(alignment: .leading, spacing: 8) {
                legend(FMW.pine,  "Collected", WalletMap.money(collected))
                legend(FMW.sun,   "Spent",     WalletMap.money(spent))
                legend(FMW.mint2, "Budget",    budget.map { WalletMap.money($0) } ?? "—")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .walletCard()
    }

    private func legend(_ color: Color, _ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(FMW.ui(13))
                .foregroundStyle(FMW.ink)
            Spacer(minLength: 8)
            Text(value)
                .font(FMW.ui(13, .semibold).monospacedDigit())
                .foregroundStyle(FMW.ink)
        }
    }
}

private struct WalletSourceRow: View {
    let source: WalletSource

    var body: some View {
        HStack(spacing: 12) {
            Text(source.badge)
                .font(FMW.ui(12, .heavy))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(source.tint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(source.name)
                    .font(FMW.ui(14, .semibold))
                    .foregroundStyle(FMW.ink)
                Text(source.detail)
                    .font(FMW.ui(11.5))
                    .foregroundStyle(FMW.muted)
            }
            Spacer(minLength: 8)
            Text(source.amount)
                .font(FMW.ui(15, .bold).monospacedDigit())
                .foregroundStyle(FMW.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .walletCard()
    }
}

private struct WalletItemRow: View {
    let item: WalletItemSale

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(item.tint)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(FMW.ui(14, .semibold))
                    .foregroundStyle(FMW.ink)
                Text(item.qtyTag)
                    .font(FMW.ui(11, .heavy))
                    .tracking(0.4)
                    .foregroundStyle(FMW.muted)
            }
            Spacer(minLength: 8)
            Text(item.amount)
                .font(FMW.ui(15, .bold).monospacedDigit())
                .foregroundStyle(FMW.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .walletCard()
    }
}

private struct WalletPaidWhatCard: View {
    let payer: WalletPayer

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 11) {
                WalletAvatar(initials: payer.initials, color: payer.tint, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(payer.name)
                        .font(FMW.ui(14.5, .semibold))
                        .foregroundStyle(FMW.ink)
                    Text(payer.method)
                        .font(FMW.ui(12))
                        .foregroundStyle(FMW.muted)
                }
                Spacer(minLength: 8)
                Text(payer.total)
                    .font(FMW.ui(15, .bold).monospacedDigit())
                    .foregroundStyle(FMW.ink)
            }
            VStack(spacing: 4) {
                ForEach(payer.lines) { line in
                    HStack {
                        Text(line.label)
                            .font(FMW.ui(12.5, .semibold))
                            .foregroundStyle(FMW.muted)
                        Spacer(minLength: 8)
                        Text(line.value)
                            .font(FMW.ui(12.5, .semibold).monospacedDigit())
                            .foregroundStyle(FMW.pineDeep)
                    }
                }
            }
            .padding(.leading, 47)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .walletCard()
    }
}

private struct WalletPersonRow: View {
    let person: WalletReimbursement

    var body: some View {
        HStack(spacing: 12) {
            WalletAvatar(initials: person.initials, color: person.tint, size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(person.name)
                    .font(FMW.ui(14.5, .semibold))
                    .foregroundStyle(FMW.ink)
                Text(person.detail)
                    .font(FMW.ui(12))
                    .foregroundStyle(FMW.muted)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(person.owed)
                    .font(FMW.ui(15, .heavy).monospacedDigit())
                    .foregroundStyle(FMW.danger)
                Text("OWED")
                    .font(FMW.ui(10, .bold))
                    .tracking(0.4)
                    .foregroundStyle(FMW.muted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .walletCard()
    }
}

private struct WalletScanButton: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "viewfinder")
                .font(.system(size: 18, weight: .semibold))
            Text("Scan a receipt")
                .font(FMW.ui(15, .bold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(FMW.pine, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: FMW.pine.opacity(0.5), radius: 12, x: 0, y: 10)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Shared bits

private struct WalletAvatar: View {
    let initials: String
    let color: Color
    let size: CGFloat

    var body: some View {
        Text(initials)
            .font(FMW.ui(size >= 38 ? 14 : 13, .heavy))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: Circle())
    }
}

private struct WalletSectionHead: View {
    let title: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(FMW.display(18, .semibold))
                .foregroundStyle(FMW.ink)
            Spacer()
        }
    }
}

private struct WalletSubhead: View {
    enum Trailing { case text(String), link(String) }
    let title: String
    let trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(FMW.display(16, .semibold))
                .foregroundStyle(FMW.ink)
            Spacer()
            switch trailing {
            case .text(let s):
                Text(s)
                    .font(FMW.ui(13, .bold).monospacedDigit())
                    .foregroundStyle(FMW.muted)
            case .link(let s):
                Text(s)
                    .font(FMW.ui(12.5, .semibold))
                    .foregroundStyle(FMW.pine)
                    .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}

private extension View {
    /// The prototype's `.card`: paper surface, soft shadow, hairline warm border.
    func walletCard(radius: CGFloat = 20) -> some View {
        self
            .background(FMW.paper)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(FMW.line.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: FMW.ink.opacity(0.14), radius: 10, x: 0, y: 6)
    }
}

// MARK: - Sample data (copied from the prototype)

private struct WalletLineItem: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

private struct WalletTicket: Identifiable {
    let id = UUID()
    let kicker: String
    let title: String
    let dateText: String
    let lines: [WalletLineItem]
    let paidPill: String
    let refNo: String

    static let samples: [WalletTicket] = [
        WalletTicket(
            kicker: "Admit · Family",
            title: "End-of-Summer Luau",
            dateText: "Aug 30 · 6:00 PM",
            lines: [
                WalletLineItem(label: "2 × Adult ticket", value: "$70.00"),
                WalletLineItem(label: "2 × Kid ticket", value: "$20.00"),
            ],
            paidPill: "✓ Paid $90.00",
            refNo: "#FMW-2214"),
        WalletTicket(
            kicker: "Pavilion · 4 hrs",
            title: "Pavilion Reservation",
            dateText: "Sep 13 · 12–4 PM",
            lines: [],
            paidPill: "✓ Paid $75.00",
            refNo: "#FMW-RP08"),
    ]
}

private struct WalletSource: Identifiable {
    let id = UUID()
    let badge: String
    let tint: Color
    let name: String
    let detail: String
    let amount: String

    static let samples: [WalletSource] = [
        WalletSource(badge: "CARD", tint: WalletShade.stripe, name: "Card · Stripe", detail: "18 payments", amount: "$520.00"),
        WalletSource(badge: "V",    tint: WalletShade.venmo,  name: "Venmo",         detail: "9 payments",  amount: "$220.00"),
        WalletSource(badge: "$",    tint: FMW.pine,           name: "Cash · at the door", detail: "Logged by Dana", amount: "$100.00"),
        WalletSource(badge: "CK",   tint: FMW.muted,          name: "Check",         detail: "1 payment",   amount: "$0.00"),
    ]
}

private struct WalletItemSale: Identifiable {
    let id = UUID()
    let tint: Color
    let name: String
    let qtyTag: String
    let amount: String

    static let samples: [WalletItemSale] = [
        WalletItemSale(tint: FMW.pine,  name: "Adult ticket",  qtyTag: "18 SOLD · $35.00 EA", amount: "$630.00"),
        WalletItemSale(tint: FMW.water, name: "Kid ticket",    qtyTag: "9 SOLD · $10.00 EA",  amount: "$90.00"),
        WalletItemSale(tint: FMW.sun,   name: "Event T-shirt", qtyTag: "6 SOLD · $20.00 EA",  amount: "$120.00"),
    ]
}

private struct WalletPayer: Identifiable {
    let id = UUID()
    let initials: String
    let tint: Color
    let name: String
    let method: String
    let total: String
    let lines: [WalletLineItem]

    static let samples: [WalletPayer] = [
        WalletPayer(initials: "SM", tint: FMW.coral, name: "Sarah M.", method: "Card · Jul 19", total: "$90.00",
                    lines: [
                        WalletLineItem(label: "2 × Adult ticket", value: "$70.00"),
                        WalletLineItem(label: "2 × Kid ticket", value: "$20.00"),
                    ]),
        WalletPayer(initials: "DR", tint: FMW.water, name: "Dana R.", method: "Venmo · Jul 20", total: "$55.00",
                    lines: [
                        WalletLineItem(label: "1 × Adult ticket", value: "$35.00"),
                        WalletLineItem(label: "1 × Event T-shirt", value: "$20.00"),
                    ]),
        WalletPayer(initials: "MK", tint: WalletShade.avatarPurple, name: "Mike K.", method: "Cash · logged by Dana", total: "$35.00",
                    lines: [
                        WalletLineItem(label: "1 × Adult ticket", value: "$35.00"),
                    ]),
    ]
}

private struct WalletReimbursement: Identifiable {
    let id = UUID()
    let initials: String
    let tint: Color
    let name: String
    let detail: String
    let owed: String

    static let samples: [WalletReimbursement] = [
        WalletReimbursement(initials: "SM", tint: FMW.coral, name: "Sarah M.", detail: "Costco · food & drinks", owed: "$142.60"),
        WalletReimbursement(initials: "DR", tint: FMW.water, name: "Dana R.", detail: "Safeway · beverages", owed: "$54.75"),
        WalletReimbursement(initials: "MK", tint: WalletShade.avatarPurple, name: "Mike K.", detail: "Party City · decor", owed: "$88.20"),
    ]
}

#Preview("Resident") {
    WalletView()
}

#Preview("Committee") {
    WalletView(role: .boardMember)
}
