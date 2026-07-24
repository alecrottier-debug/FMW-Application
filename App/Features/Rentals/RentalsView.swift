import SwiftUI

/// Rentals — The Pavilion (spec "Pavilion Rentals" module, reached from the Home
/// module grid). A sun-toned detail hero, an info card (fee + instant booking),
/// a month picker that shows open vs. booked dates, and a sticky-style pay bar that
/// reserves the selected date. Built to match Design/prototype.html (data-screen="rentals").
///
/// Instant-book model: a date is confirmed the moment it's reserved *if it's open*.
/// Booked dates are non-selectable. (The real fee is a line item on an Order, per the
/// spec — this screen is the client slice; the API is the authority on availability.)
struct RentalsView: View {
    @Environment(\.dismiss) private var dismiss

    // August 2026 opens on a Saturday, so 6 leading blanks before day 1.
    private let leadingBlanks = 6
    private let daysInMonth = 31
    private let bookedDays: Set<Int> = [17, 23]   // prototype BOOKED = [17, 23]

    @State private var selectedDay: Int?
    @State private var confirmed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                RentalsHero(onBack: { dismiss() })

                RentalsInfoCard()
                    .padding(.horizontal, 12)
                    .padding(.top, -14)

                RentalsSectionHead()
                    .padding(.horizontal, 18)
                    .padding(.top, 22)
                    .padding(.bottom, 10)

                VStack(spacing: 0) {
                    RentalsMonthGrid(
                        leadingBlanks: leadingBlanks,
                        daysInMonth: daysInMonth,
                        bookedDays: bookedDays,
                        selectedDay: selectedDay,
                        onSelect: select
                    )
                    RentalsLegend()
                        .padding(.horizontal, 4)
                        .padding(.top, 12)
                }
                .padding(.horizontal, 18)

                RentalsPayBar(
                    caption: payCaption,
                    confirmed: confirmed,
                    enabled: selectedDay != nil,
                    onReserve: reserve
                )
                .padding(.top, 8)

                Color.clear.frame(height: 8)
            }
        }
        .scrollIndicators(.hidden)
        .background(FMW.cream.ignoresSafeArea())
    }

    // MARK: Interaction

    private func select(_ day: Int) {
        selectedDay = day
        confirmed = false
    }

    private func reserve() {
        guard selectedDay != nil else { return }
        confirmed = true
    }

    private var payCaption: String {
        guard let d = selectedDay else { return "Tap an open date to select it" }
        let label = "\(weekday(d)), Aug \(d) · 12–4 PM"
        return confirmed ? "Reserved — \(label)" : "Selected \(label) · open"
    }

    /// Weekday abbreviation for August 2026 (Aug 1 is a Saturday).
    private func weekday(_ day: Int) -> String {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return names[(day + 5) % 7]
    }
}

// MARK: - One-off shades / gradients (no raw hex in view bodies, per CLAUDE.md)

private extension FMW {
    /// .detail-hero override: linear-gradient(165deg,#FDECD2,#F8DDB6 55%,#EAF4EC)
    static let rentalHeroGradient = LinearGradient(
        colors: [Color(hex: 0xFDECD2), Color(hex: 0xF8DDB6), Color(hex: 0xEAF4EC)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    /// .btn-sun: linear-gradient(180deg,var(--sun-2),var(--sun))
    static let sunButton = LinearGradient(
        colors: [FMW.sun2, FMW.sun], startPoint: .top, endPoint: .bottom
    )
    /// .paybar fade: from transparent cream up to solid cream at ~26%.
    static let payFade = LinearGradient(
        stops: [
            .init(color: FMW.cream.opacity(0), location: 0),
            .init(color: FMW.cream, location: 0.26),
            .init(color: FMW.cream, location: 1)
        ],
        startPoint: .top, endPoint: .bottom
    )
}

// MARK: - Hero

private struct RentalsHero: View {
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Text("‹").font(FMW.ui(15, .semibold))
                    Text("Home").font(FMW.ui(13, .semibold))
                }
                .foregroundStyle(FMW.pineDeep)
                .padding(.leading, 10)
                .padding(.trailing, 13)
                .padding(.vertical, 8)
                .background(FMW.paper.opacity(0.7), in: Capsule())
                .overlay(Capsule().stroke(FMW.lineMint, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to Home")

            Text("RESIDENT RENTAL")
                .font(FMW.ui(11, .heavy))
                .tracking(1.3)
                .foregroundStyle(FMW.sun)
                .padding(.top, 14)

            Text("The Pavilion")
                .font(FMW.display(28, .bold))
                .foregroundStyle(FMW.ink)
                .padding(.top, 14)

            Text("Covered pavilion at Black Fir Court — picnic tables, grill, and open lawn.")
                .font(FMW.ui(13.5))
                .foregroundStyle(FMW.pineDeep)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 250, alignment: .leading)
                .padding(.top, 8)
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                FMW.rentalHeroGradient
                FMW.sunwash
            }
        }
    }
}

// MARK: - Info card

private struct RentalsInfoCard: View {
    var body: some View {
        VStack(spacing: 0) {
            RentalsInfoRow(
                symbol: "dollarsign",
                label: "Rental fee",
                value: "$75 · per 4-hour block"
            )
            Rectangle()
                .fill(FMW.line)
                .frame(height: 1)
                .padding(.horizontal, 14)
            RentalsInfoRow(
                symbol: "checkmark",
                label: "Booking",
                value: "Instant — confirmed if the date’s open"
            )
        }
        .padding(4)
        .background(FMW.paper, in: RoundedRectangle(cornerRadius: FMW.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FMW.radius, style: .continuous)
                .stroke(FMW.line.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: FMW.ink.opacity(0.16), radius: 10, x: 0, y: 6)
    }
}

private struct RentalsInfoRow: View {
    let symbol: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(FMW.mint)
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(FMW.pine)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(FMW.ui(11.5, .semibold))
                    .foregroundStyle(FMW.muted)
                Text(value)
                    .font(FMW.ui(14.5, .semibold))
                    .foregroundStyle(FMW.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Section head

private struct RentalsSectionHead: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Pick an open date")
                .font(FMW.display(18, .semibold))
                .foregroundStyle(FMW.ink)
            Spacer()
            Text("See calendar →")
                .font(FMW.ui(12.5, .semibold))
                .foregroundStyle(FMW.pine)
        }
    }
}

// MARK: - Month grid

private struct RentalsMonthGrid: View {
    let leadingBlanks: Int
    let daysInMonth: Int
    let bookedDays: Set<Int>
    let selectedDay: Int?
    let onSelect: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let dow = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("August 2026")
                    .font(FMW.display(16, .semibold))
                    .foregroundStyle(FMW.ink)
                Spacer()
                Text("‹ ›")
                    .font(FMW.ui(12))
                    .foregroundStyle(FMW.muted)
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(dow.enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .font(FMW.ui(10, .bold))
                        .foregroundStyle(FMW.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 4)
                }

                ForEach(0..<(leadingBlanks + daysInMonth), id: \.self) { index in
                    if index < leadingBlanks {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                    } else {
                        let day = index - leadingBlanks + 1
                        RentalsDayCell(
                            day: day,
                            isBooked: bookedDays.contains(day),
                            isSelected: selectedDay == day,
                            onTap: { onSelect(day) }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(FMW.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: FMW.ink.opacity(0.16), radius: 10, x: 0, y: 6)
    }
}

private struct RentalsDayCell: View {
    let day: Int
    let isBooked: Bool
    let isSelected: Bool
    let onTap: () -> Void

    private var textColor: Color {
        if isSelected { return .white }
        if isBooked { return FMW.pillSunFg }
        return FMW.ink
    }

    private var fill: Color {
        if isSelected { return FMW.pine }
        if isBooked { return FMW.pillSunBg }
        return .clear
    }

    var body: some View {
        Button(action: { if !isBooked { onTap() } }) {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(FMW.ui(12.5, .semibold))
                    .foregroundStyle(textColor)
                // .dots reserves a 5pt strip; booked dates carry a sun dot.
                Circle()
                    .fill(isBooked ? FMW.sun : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isBooked)
        .accessibilityLabel("August \(day)")
        .accessibilityValue(isBooked ? "Booked" : (isSelected ? "Selected" : "Open"))
    }
}

private struct RentalsLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            item(color: FMW.mint2, label: "Open")
            item(color: FMW.sun, label: "Booked")
            item(color: FMW.pine, label: "Selected")
            Spacer(minLength: 0)
        }
    }

    private func item(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(label)
                .font(FMW.ui(11.5, .semibold))
                .foregroundStyle(FMW.muted)
        }
    }
}

// MARK: - Pay bar

private struct RentalsPayBar: View {
    let caption: String
    let confirmed: Bool
    let enabled: Bool
    let onReserve: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                if confirmed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(FMW.pine)
                }
                Text(caption)
                    .font(FMW.ui(13, confirmed ? .semibold : .regular))
                    .foregroundStyle(confirmed ? FMW.pineDeep : FMW.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 10)

            Button(action: onReserve) {
                HStack(spacing: 8) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 15, weight: .bold))
                    Text("Reserve · pay $75")
                        .font(FMW.ui(15, .bold))
                }
                .foregroundStyle(FMW.sunInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .background(FMW.sunButton, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: FMW.sun.opacity(0.5), radius: 12, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
            .accessibilityLabel("Reserve the pavilion and pay 75 dollars")
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 18)
        .background(FMW.payFade)
    }
}

#Preview {
    RentalsView()
}
