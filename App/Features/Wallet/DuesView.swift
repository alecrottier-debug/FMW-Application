import SwiftUI

/// Annual dues — the membership-payment screen (Design/prototype.html,
/// data-screen="dues"). A soft mint→sun sunwash hero with a back button and a
/// Fraunces title, an overlapping info card (amount + coverage period), the
/// "how would you like to pay?" method picker with **Bank (ACH) offered first
/// and flagged LOWEST FEE**, the ACH authorization / mandate text, a dashed
/// total bar, and a sticky pine Pay bar.
///
/// ACH is asynchronous: the copy makes clear the debit "arrives in 2–4 business
/// days" and the tap does not imply instant success — the server flips
/// membershipStatus to paid only on the Stripe webhook, never on submit.
struct DuesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PaymentService.self) private var payments

    // One-off shades sampled from the prototype (no token exists for these).
    // detail-hero override: linear-gradient(165deg,#EAF4EC,#DCEEDF 55%,#FDECD2)
    private static let duesHeroGradient = LinearGradient(
        stops: [
            .init(color: FMW.mint,            location: 0),
            .init(color: Color(hex: 0xDCEEDF), location: 0.55),
            .init(color: Color(hex: 0xFDECD2), location: 1)
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    // detail-hero .sunwash: radial-gradient(220px 180px at 85% 8%, rgba(248,180,94,.5), transparent 70%)
    private static let duesSunwash = RadialGradient(
        colors: [FMW.sun2.opacity(0.5), FMW.sun2.opacity(0)],
        center: UnitPoint(x: 0.85, y: 0.08), startRadius: 0, endRadius: 200
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
    private static let methodOnBg   = Color(hex: 0xF5FBF6) // methodcard.on background
    private static let cardLogoBg   = Color(hex: 0xEDEAFB) // card method mlogo tint
    private static let stripePurple = Color(hex: 0x635BFF) // card glyph stroke

    // Sample dues — the 2026 Fox Mill Woods membership.
    private let amount     = 250.0
    private let membership = "2026 membership"
    private let covers     = "Pool, tennis & neighborhood events · Jan–Dec 2026"

    @State private var method: PaymentMethodKind = .bank

    private var amountText: String { currency(amount) }
    private var payLabel: String {
        method == .bank ? "Pay \(amountText) from bank" : "Pay \(amountText) with card"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero

                infoCard
                    .padding(.horizontal, 12)
                    .padding(.top, -14)

                sectionHead("How would you like to pay?")

                // Bank (ACH) is presented first — far cheaper at dues-sized
                // amounts — and carries the mandate the resident authorizes.
                bankMethodCard
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)

                cardMethodCard
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)

                totalBar

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
                    Text("Wallet").font(FMW.ui(13, .semibold))
                }
                .foregroundStyle(FMW.pineDeep)
                .padding(.leading, 10)
                .padding(.trailing, 13)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.7), in: Capsule())
                .overlay(Capsule().stroke(FMW.lineMint, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to Wallet")

            Text("FOX MILL WOODS MEMBERSHIP")
                .font(FMW.ui(11, .heavy))
                .tracking(1.3)
                .foregroundStyle(FMW.sun)
                .padding(.top, 12)

            Text("Annual dues")
                .font(FMW.display(25, .bold))
                .foregroundStyle(FMW.ink)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background {
            ZStack {
                Self.duesHeroGradient
                Self.duesSunwash
            }
        }
        .clipped()
    }

    // MARK: - Info card

    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow(symbol: "dollarsign", label: membership) {
                Text(amountText)
                    .font(FMW.ui(14.5, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(FMW.ink)
            }
            rowDivider
            infoRow(symbol: "calendar", label: "Covers") {
                Text(covers)
                    .font(FMW.ui(13.5, .semibold))
                    .foregroundStyle(FMW.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
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

    private func infoRow<Value: View>(symbol: String, label: String, @ViewBuilder value: () -> Value) -> some View {
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
                value()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
    }

    private var rowDivider: some View {
        Rectangle().fill(FMW.line).frame(height: 1)
    }

    // MARK: - Section head

    private func sectionHead(_ title: String) -> some View {
        HStack {
            Text(title).font(FMW.display(18, .semibold)).foregroundStyle(FMW.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 10)
    }

    // MARK: - Method cards

    private var bankMethodCard: some View {
        let on = method == .bank
        return VStack(alignment: .leading, spacing: 0) {
            methodHeader(
                logoTint: FMW.mint,
                glyph: "building.columns",
                glyphColor: FMW.pine,
                title: "Bank account",
                subtitle: "Pay directly from checking",
                badge: "LOWEST FEE"
            )
            // ACH authorization / mandate — rendered before any debit.
            Text("Connect your bank in a few taps — verified instantly. Arrives in 2–4 business days. By paying you authorize Fox Mill Woods to debit this account for \(amountText) on a one-time basis.")
                .font(FMW.ui(11))
                .foregroundStyle(FMW.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 11)
        }
        .padding(14)
        .background(on ? Self.methodOnBg : FMW.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(on ? FMW.pine : FMW.line, lineWidth: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture { method = .bank }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bank account. Pay directly from checking. Lowest fee.")
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    private var cardMethodCard: some View {
        let on = method == .card
        return methodHeader(
            logoTint: Self.cardLogoBg,
            glyph: "creditcard",
            glyphColor: Self.stripePurple,
            title: "Card",
            subtitle: "Visa ···· 4242 · instant",
            badge: nil
        )
        .padding(14)
        .background(on ? Self.methodOnBg : FMW.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(on ? FMW.pine : FMW.line, lineWidth: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture { method = .card }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Card. Visa ending 4242. Instant.")
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    private func methodHeader(
        logoTint: Color,
        glyph: String,
        glyphColor: Color,
        title: String,
        subtitle: String,
        badge: String?
    ) -> some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous).fill(logoTint)
                Image(systemName: glyph)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(glyphColor)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(FMW.ui(14.5, .bold)).foregroundStyle(FMW.ink)
                Text(subtitle).font(FMW.ui(12)).foregroundStyle(FMW.muted)
            }

            Spacer(minLength: 8)

            if let badge {
                Text(badge)
                    .font(FMW.ui(9.5, .heavy))
                    .foregroundStyle(FMW.pineDeep)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(FMW.mint, in: Capsule())
            }
        }
    }

    // MARK: - Total bar

    private var totalBar: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Total due").font(FMW.ui(14, .bold)).foregroundStyle(FMW.ink)
            Spacer()
            Text(amountText)
                .font(FMW.display(24, .bold))
                .monospacedDigit()
                .foregroundStyle(FMW.ink)
        }
        .padding(.top, 13)
        .overlay(alignment: .top) {
            DuesDashedLine()
                .stroke(FMW.line, style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                .frame(height: 2)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    // MARK: - Sticky pay bar

    private var payBar: some View {
        VStack(spacing: 0) {
            Button {
                // ACH authorizes now but settles later — membership flips on the webhook.
                Task {
                    let done = await payments.payDues(method: method == .bank ? "ach" : "card")
                    if done { dismiss() }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                    Text(payLabel)
                        .font(FMW.ui(15, .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(FMW.pine, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: FMW.pine.opacity(0.6), radius: 11, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(payLabel)

            Text("Payments are processed securely by Stripe. Fox Mill Woods never sees your bank or card details.")
                .font(FMW.ui(11))
                .foregroundStyle(FMW.muted)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.top, 10)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 18)
        .background(Self.payBarFade)
    }

    // MARK: - Helpers

    private func currency(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }
}

// MARK: - Shapes

/// A single horizontal rule used as the dashed top border of the total bar
/// (prototype `.totalbar` `border-top:2px dashed`). Uniquely named to avoid
/// collisions with other files' private shapes in this single-module app.
private struct DuesDashedLine: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: r.midY))
        p.addLine(to: CGPoint(x: r.width, y: r.midY))
        return p
    }
}

#Preview {
    DuesView().environment(PaymentService())
}
