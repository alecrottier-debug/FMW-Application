import SwiftUI

/// Pool & Tennis — read-only amenity hours (spec IA "Pool & Tennis"; reached from
/// Home). A cool teal→sun detail hero, a prominent "today" card with the current
/// open/closing window, the pool's weekday/weekend hours plus the daily adult-swim
/// note, and the tennis-court hours. No bookings live here.
/// Built to match Design/prototype.html (data-screen="pool").
struct PoolView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                PoolHeroView(onBack: { dismiss() })

                TodayCard()
                    .padding(.horizontal, 12)
                    .padding(.top, -10)

                PoolSectionHead(title: "Pool hours")
                    .padding(.top, 22)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 10)

                VStack(spacing: 8) {
                    PoolViewRow(barColor: FMW.pine,
                                title: "Monday – Friday",
                                amount: "11:00 AM – 8:00 PM")
                    PoolViewRow(barColor: FMW.pine,
                                title: "Saturday – Sunday",
                                amount: "10:00 AM – 8:00 PM")
                    PoolViewRow(barColor: FMW.sun,
                                title: "Adult swim",
                                badge: "DAILY",
                                amount: "7:00 – 8:00 PM")
                }
                .padding(.horizontal, 12)

                PoolSectionHead(title: "Tennis courts")
                    .padding(.top, 22)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 10)

                VStack(spacing: 8) {
                    PoolViewRow(barColor: FMW.water,
                                title: "Every day",
                                amount: "7:00 AM – Dusk")
                }
                .padding(.horizontal, 12)

                Color.clear.frame(height: 26)
            }
        }
        .scrollIndicators(.hidden)
        .background(FMW.cream.ignoresSafeArea())
    }
}

// MARK: - Local palette (shades sampled from the prototype's pool detail-hero)

private enum PoolPalette {
    static let heroTop = Color(hex: 0xDDF0EE) // cool teal wash
    static let heroMid = Color(hex: 0xCFE9E4)
    static let heroBot = Color(hex: 0xFDECD2) // warms into sun at the base

    static let heroGradient = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: heroTop, location: 0),
            .init(color: heroMid, location: 0.55),
            .init(color: heroBot, location: 1)
        ]),
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Detail hero

private struct PoolHeroView: View {
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Home")
                        .font(FMW.ui(13, .semibold))
                }
                .foregroundStyle(FMW.pineDeep)
                .padding(.leading, 10)
                .padding(.trailing, 13)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.7), in: Capsule())
                .overlay(Capsule().stroke(FMW.lineMint, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to Home")

            Text("FOX MILL WOODS")
                .font(FMW.ui(11, .heavy))
                .tracking(1.3)
                .foregroundStyle(FMW.sun)
                .padding(.top, 12)

            Text("Pool & Tennis")
                .font(FMW.display(26, .bold))
                .foregroundStyle(FMW.ink)
                .padding(.top, 6)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                PoolPalette.heroGradient
                FMW.sunwash
            }
        }
    }
}

// MARK: - "Today" open-hours card

private struct TodayCard: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Text("◆").font(.system(size: 8))
                Text("OPEN NOW")
                    .font(FMW.ui(11, .bold))
                    .tracking(1.5)
            }
            .foregroundStyle(FMW.pine)

            Text("11:00 AM – 8:00 PM")
                .font(FMW.display(30, .bold))
                .foregroundStyle(FMW.ink)
                .monospacedDigit()
                .padding(.top, 6)

            Text("Today · Wednesday, Jul 22")
                .font(FMW.ui(13))
                .foregroundStyle(FMW.muted)
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .poolCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Open now. Today, Wednesday, July 22. 11:00 AM to 8:00 PM.")
    }
}

// MARK: - Section header

private struct PoolSectionHead: View {
    let title: String
    var body: some View {
        HStack {
            Text(title).font(FMW.display(18, .semibold)).foregroundStyle(FMW.ink)
            Spacer()
        }
    }
}

// MARK: - Hours row (prototype `.card.itemrow`)

private struct PoolViewRow: View {
    var barColor: Color
    var title: String
    var badge: String? = nil
    var amount: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(barColor)
                .frame(width: 4)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FMW.ui(14, .semibold))
                    .foregroundStyle(FMW.ink)
                if let badge {
                    Text(badge)
                        .font(FMW.ui(11, .heavy))
                        .tracking(0.4)
                        .foregroundStyle(FMW.muted)
                }
            }

            Spacer(minLength: 8)

            Text(amount)
                .font(FMW.ui(13.5, .bold))
                .foregroundStyle(FMW.ink)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .poolCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(badge == nil
            ? "\(title), \(amount)"
            : "\(title), \(badge!), \(amount)")
    }
}

// MARK: - Shared card chrome (prototype `.card` — paper, radius, hairline, soft shadow)

private struct PoolCardChrome: ViewModifier {
    var radius: CGFloat = FMW.radius
    func body(content: Content) -> some View {
        content
            .background(FMW.paper)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(FMW.line.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: FMW.ink.opacity(0.14), radius: 10, x: 0, y: 6)
    }
}

private extension View {
    func poolCard(radius: CGFloat = FMW.radius) -> some View {
        modifier(PoolCardChrome(radius: radius))
    }
}

#Preview {
    PoolView()
}
