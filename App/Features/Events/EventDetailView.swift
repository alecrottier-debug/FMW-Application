import SwiftUI

/// Event Detail — the RSVP / pay screen for a single Crooked Fox Collective event
/// (Design/prototype.html, data-screen="event"). A full-bleed sunwash hero with a
/// back button and a Fraunces title, an overlapping info card (when / where / cost),
/// a short blurb, the attendee avatar stack, the itemized "choose what you're paying
/// for" picker with a live running total, and a sticky sun-toned pay bar.
///
/// Sample data is the paid "Summer Sunset Social" from the prototype's EVENTS map —
/// it exercises the item picker + paid pay bar (Events have many paid items, never one
/// price). The steppers drive the total and the button label just like the prototype.
struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BraintreeService.self) private var braintree

    // Real event/item ids come from the live Events API; the sample view uses placeholders.
    private let eventId = "00000000-0000-0000-0000-000000000000"

    // One-off shades sampled from the prototype (no token exists for these).
    private static let avatarPurple = Color(hex: 0x8A7CC9)

    // detail-hero: linear-gradient(165deg,#FFF3DE,#F8E6C6 55%,#E9F3E7)
    private static let detailHeroGradient = LinearGradient(
        stops: [
            .init(color: Color(hex: 0xFFF3DE), location: 0),
            .init(color: Color(hex: 0xF8E6C6), location: 0.55),
            .init(color: Color(hex: 0xE9F3E7), location: 1)
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    // detail-hero .sunwash: radial-gradient(220px 180px at 85% 8%, rgba(248,180,94,.5), transparent 70%)
    private static let detailSunwash = RadialGradient(
        colors: [FMW.sun2.opacity(0.5), FMW.sun2.opacity(0)],
        center: UnitPoint(x: 0.85, y: 0.08), startRadius: 0, endRadius: 200
    )
    // btn-sun: linear-gradient(180deg,var(--sun-2),var(--sun))
    private static let sunButtonGradient = LinearGradient(
        colors: [FMW.sun2, FMW.sun], startPoint: .top, endPoint: .bottom
    )
    // paybar: linear-gradient(180deg,rgba(251,250,243,0),var(--cream) 26%)
    private static let payBarFade = LinearGradient(
        stops: [
            .init(color: FMW.cream.opacity(0), location: 0),
            .init(color: FMW.cream, location: 0.26),
            .init(color: FMW.cream, location: 1)
        ],
        startPoint: .top, endPoint: .bottom
    )

    // Sample event — the paid "Summer Sunset Social".
    private let kicker = "THE CROOKED FOX COLLECTIVE"
    private let title  = "Summer Sunset Social"
    private let when   = "Sat, Aug 9 · 7:00 PM"
    private let place  = "Black Fir Court Pool & Pavilion"
    private let cost   = "From $35 · 3 items"
    private let blurb  = "An adults-only evening at the pavilion — catered bites, a bar, and a golden-hour view. Sitters welcome to sign up."

    private let items: [EventDetailItem] = [
        EventDetailItem(name: "Adult ticket",       note: "Includes dinner & one drink", price: 35),
        EventDetailItem(name: "Extra drink ticket", note: "Optional add-on",             price: 8),
        EventDetailItem(name: "Sitter share",       note: "Per child · pavilion sitter", price: 12)
    ]

    @State private var quantities: [Int] = [0, 0, 0]

    private var total: Double {
        var sum = 0.0
        for i in items.indices { sum += Double(quantities[i]) * items[i].price }
        return sum
    }
    private var payLabel: String {
        total > 0 ? "Pay \(currency(total)) & reserve" : "Choose items to continue"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero

                infoCard
                    .padding(.horizontal, 12)
                    .padding(.top, -14)

                Text(blurb)
                    .font(FMW.ui(14))
                    .foregroundStyle(FMW.muted)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.top, 18)

                sectionHead(title: "Who’s coming", trailing: "32 going →")
                attendees

                itemsSection

                Color.clear.frame(height: 8)
            }
        }
        .scrollIndicators(.hidden)
        .background(FMW.cream.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { payBar }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { dismiss() } label: {
                HStack(spacing: 6) {
                    Text("‹").font(FMW.ui(16, .semibold))
                    Text("Events").font(FMW.ui(13, .semibold))
                }
                .foregroundStyle(FMW.pineDeep)
                .padding(.leading, 10)
                .padding(.trailing, 13)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.7), in: Capsule())
                .overlay(Capsule().stroke(FMW.lineMint, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to Events")

            Text(kicker)
                .font(FMW.ui(11, .heavy))
                .tracking(1.3)
                .foregroundStyle(FMW.sun)
                .padding(.top, 14)

            Text(title)
                .font(FMW.display(28, .bold))
                .foregroundStyle(FMW.ink)
                .lineSpacing(0)
                .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 22)
        .background {
            ZStack {
                Self.detailHeroGradient
                Self.detailSunwash
            }
        }
        .clipped()
    }

    // MARK: - Info card

    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow(symbol: "calendar",             label: "When",  value: when)
            rowDivider
            infoRow(symbol: "mappin.and.ellipse",   label: "Where", value: place)
            rowDivider
            infoRow(symbol: "dollarsign",           label: "Cost",  value: cost)
        }
        .padding(4)
        .background(FMW.paper)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(FMW.line.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: FMW.ink.opacity(0.18), radius: 10, x: 0, y: 6)
    }

    private func infoRow(symbol: String, label: String, value: String) -> some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous).fill(FMW.mint)
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FMW.pine)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(FMW.ui(11.5, .semibold)).foregroundStyle(FMW.muted)
                Text(value).font(FMW.ui(14.5, .semibold)).foregroundStyle(FMW.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private var rowDivider: some View {
        Rectangle().fill(FMW.line).frame(height: 1)
    }

    // MARK: - Section head + attendees

    private func sectionHead(title: String, trailing: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(FMW.display(18, .semibold)).foregroundStyle(FMW.ink)
            Spacer()
            Text(trailing).font(FMW.ui(12.5, .semibold)).foregroundStyle(FMW.pine)
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 10)
    }

    private var attendees: some View {
        HStack(spacing: -9) {
            avatar("SM", FMW.coral)
            avatar("JL", FMW.pine)
            avatar("DR", FMW.water)
            avatar("KW", FMW.sun)
            avatar("AB", Self.avatarPurple)
            avatar("+27", FMW.pineDeep)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("32 neighbors going")
    }

    private func avatar(_ initials: String, _ color: Color) -> some View {
        Text(initials)
            .font(FMW.ui(12, .heavy))
            .foregroundStyle(.white)
            .minimumScaleFactor(0.7)
            .frame(width: 34, height: 34)
            .background(color, in: Circle())
            .overlay(Circle().stroke(FMW.cream, lineWidth: 2))
    }

    // MARK: - Itemized picker

    private var itemsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Choose what you're paying for")
                    .font(FMW.display(18, .semibold))
                    .foregroundStyle(FMW.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 10)

            ForEach(items.indices, id: \.self) { i in
                itemRow(i)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }

            totalBar
        }
    }

    private func itemRow(_ i: Int) -> some View {
        let item = items[i]
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(FMW.ui(14.5, .semibold))
                    .foregroundStyle(FMW.ink)
                (
                    Text(item.note + " · ")
                        .foregroundColor(FMW.muted)
                    + Text(item.priceText)
                        .font(FMW.ui(12, .bold))
                        .foregroundColor(FMW.pineDeep)
                )
                .font(FMW.ui(12))
            }
            Spacer(minLength: 8)
            stepper(i)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(FMW.paper)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(FMW.line.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: FMW.ink.opacity(0.16), radius: 9, x: 0, y: 5)
    }

    private func stepper(_ i: Int) -> some View {
        HStack(spacing: 11) {
            stepButton("−", enabled: quantities[i] > 0) {
                if quantities[i] > 0 { quantities[i] -= 1 }
            }
            .accessibilityLabel("Decrease \(items[i].name)")

            Text("\(quantities[i])")
                .font(FMW.ui(15, .heavy))
                .monospacedDigit()
                .foregroundStyle(FMW.ink)
                .frame(minWidth: 16)

            stepButton("+", enabled: true) {
                quantities[i] += 1
            }
            .accessibilityLabel("Increase \(items[i].name)")
        }
    }

    private func stepButton(_ glyph: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(FMW.ui(17, .bold))
                .foregroundStyle(FMW.pine)
                .frame(width: 30, height: 30)
                .background(FMW.paper, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(FMW.lineMint, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }

    private var totalBar: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Your total").font(FMW.ui(14, .bold)).foregroundStyle(FMW.ink)
            Spacer()
            Text(currency(total))
                .font(FMW.display(24, .bold))
                .monospacedDigit()
                .foregroundStyle(FMW.ink)
        }
        .padding(.top, 13)
        .overlay(alignment: .top) {
            EventDetailDashedLine()
                .stroke(FMW.line, style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                .frame(height: 2)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    // MARK: - Sticky pay bar

    private var payBar: some View {
        Button { Task { await pay() } } label: {
            HStack(spacing: 8) {
                Image(systemName: "creditcard")
                    .font(.system(size: 15, weight: .bold))
                Text(payLabel)
                    .font(FMW.ui(15, .bold))
            }
            .foregroundStyle(FMW.sunInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Self.sunButtonGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: FMW.sun.opacity(0.5), radius: 11, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(total <= 0)
        .opacity(total > 0 ? 1 : 0.5)
        .accessibilityLabel(payLabel)
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 18)
        .background(Self.payBarFade)
    }

    /// Itemized checkout via Braintree (Apple Pay / card / PayPal). Lines carry the
    /// item + quantity so the PayPal receipt and our Order/OrderLines reconcile.
    private func pay() async {
        let lines = items.indices.compactMap { i in
            quantities[i] > 0 ? OrderLineInput(eventItemId: items[i].id.uuidString, quantity: quantities[i]) : nil
        }
        guard !lines.isEmpty else { return }
        if await braintree.checkout(eventId: eventId, lines: lines) { dismiss() }
    }

    // MARK: - Helpers

    private func currency(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }
}

// MARK: - Model

private struct EventDetailItem: Identifiable {
    let id = UUID()
    let name: String
    let note: String
    let price: Double
    var priceText: String { String(format: "$%.2f", price) }
}

// MARK: - Shapes

/// A single horizontal rule used as the dashed top border of the total bar
/// (prototype `.totalbar` `border-top:2px dashed`). Uniquely named to avoid
/// collisions with other files' private shapes in this single-module app.
private struct EventDetailDashedLine: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: r.midY))
        p.addLine(to: CGPoint(x: r.width, y: r.midY))
        return p
    }
}

#Preview {
    EventDetailView().environment(BraintreeService())
}
