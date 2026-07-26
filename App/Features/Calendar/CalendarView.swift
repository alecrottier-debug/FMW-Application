import SwiftUI

/// Calendar — the whole-neighborhood month view (spec IA "Calendar" tab).
/// Filter chips (All · Events · Rentals · Pool & Tennis) toggle what shows,
/// a month grid card marks today and paints colored event/rental dots, and a
/// grouped agenda lists upcoming items with a colored left bar and type tag.
/// Built to match Design/prototype.html (data-screen="calendar"). August 2026:
/// Aug 1 falls on Saturday, events on the 9th & 30th, rentals on the 17th & 23rd,
/// today is the 22nd.
struct CalendarView: View {
    @State private var showEvents = true
    @State private var showRentals = true

    private var allOn: Bool { showEvents && showRentals }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 14)

                Color.clear.frame(height: 12)

                filterBar
                    .padding(.top, 4)

                CalendarMonthGrid(showEvents: showEvents, showRentals: showRentals)
                    .padding(.horizontal, 18)
                    .padding(.top, 14)

                CalendarAgenda(showEvents: showEvents, showRentals: showRentals)
                    .padding(.horizontal, 12)
                    .padding(.top, 16)

                Color.clear.frame(height: 24)
            }
        }
        .scrollIndicators(.hidden)
        .background(FMW.cream.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "map")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FMW.pine)
                Text("NEIGHBORHOOD")
                    .font(FMW.ui(11, .bold))
                    .tracking(1.5)
                    .foregroundStyle(FMW.pine)
            }
            Text("Calendar")
                .font(FMW.display(26, .bold))
                .foregroundStyle(FMW.ink)
                .padding(.top, 6)
        }
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                CalendarFilterChip(
                    title: "All", dotColor: nil, isOn: allOn,
                    onBackground: FMW.ink, onForeground: .white
                ) {
                    let turningOn = !allOn
                    showEvents = turningOn
                    showRentals = turningOn
                }
                CalendarFilterChip(
                    title: "Events", dotColor: FMW.pine, isOn: showEvents,
                    onBackground: FMW.pine, onForeground: .white
                ) { showEvents.toggle() }
                CalendarFilterChip(
                    title: "Rentals", dotColor: FMW.sun, isOn: showRentals,
                    onBackground: FMW.sun, onForeground: FMW.sunInk
                ) { showRentals.toggle() }
                CalendarFilterChip(
                    title: "Pool & Tennis", dotColor: FMW.water, isOn: false,
                    onBackground: FMW.water, onForeground: .white
                ) { /* coming soon — Pool & Tennis has no calendar feed yet */ }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 2)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Filter chip

private struct CalendarFilterChip: View {
    let title: String
    let dotColor: Color?
    let isOn: Bool
    let onBackground: Color
    let onForeground: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let dotColor {
                    Circle().fill(dotColor).frame(width: 9, height: 9)
                }
                Text(title).font(FMW.ui(13, .semibold))
            }
            .foregroundStyle(isOn ? onForeground : FMW.pineDeep)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isOn ? onBackground : FMW.paper, in: Capsule())
            .overlay(
                Capsule().stroke(isOn ? onBackground : FMW.lineMint, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Month grid

private struct CalendarMonthGrid: View {
    let showEvents: Bool
    let showRentals: Bool

    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    // August 2026: Aug 1 falls on Saturday, so six leading blank cells.
    private var days: [CalendarDay] {
        var out: [CalendarDay] = []
        for i in 0..<6 { out.append(CalendarDay(id: -1 - i, number: nil)) }
        for d in 1...31 {
            out.append(CalendarDay(
                id: d,
                number: d,
                isToday: d == 22,
                hasEvent: d == 9 || d == 30,
                hasRental: d == 17 || d == 23
            ))
        }
        return out
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("August 2026")
                    .font(FMW.display(16, .semibold))
                    .foregroundStyle(FMW.ink)
                Spacer()
                HStack(spacing: 10) {
                    Image(systemName: "chevron.left")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FMW.muted)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 10)

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(weekdays.indices, id: \.self) { i in
                    Text(weekdays[i])
                        .font(FMW.ui(10, .bold))
                        .foregroundStyle(FMW.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 4)
                }
                ForEach(days) { day in
                    CalendarDayCell(day: day, showEvents: showEvents, showRentals: showRentals)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(FMW.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: FMW.ink.opacity(0.18), radius: 9, x: 0, y: 6)
    }
}

private struct CalendarDay: Identifiable {
    let id: Int
    var number: Int? = nil
    var isToday: Bool = false
    var hasEvent: Bool = false
    var hasRental: Bool = false
}

private struct CalendarDayCell: View {
    let day: CalendarDay
    let showEvents: Bool
    let showRentals: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(day.isToday ? FMW.mint : Color.clear)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let n = day.number {
                    VStack(spacing: 2) {
                        Text("\(n)")
                            .font(FMW.ui(12.5, .semibold))
                            .foregroundStyle(FMW.ink)
                        HStack(spacing: 2) {
                            if day.hasEvent && showEvents {
                                Circle().fill(FMW.pine).frame(width: 5, height: 5)
                            }
                            if day.hasRental && showRentals {
                                Circle().fill(FMW.sun).frame(width: 5, height: 5)
                            }
                        }
                        .frame(height: 5)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(day.number.map { "August \($0)\(day.isToday ? ", today" : "")" } ?? "")
            .accessibilityHidden(day.number == nil)
    }
}

// MARK: - Agenda

private struct CalendarAgenda: View {
    let showEvents: Bool
    let showRentals: Bool

    private let entries: [CalendarAgendaEntry] = [
        .init(header: "Sat · Aug 9",  title: "Summer Sunset Social",
              subtitle: "7:00 PM · Pavilion · Adults", isEvent: true),
        .init(header: "Sun · Aug 17", title: "Pavilion — Ramirez birthday",
              subtitle: "12:00–4:00 PM · Booked", isEvent: false),
        .init(header: "Sat · Aug 23", title: "Pavilion — Book club potluck",
              subtitle: "5:00–9:00 PM · Booked", isEvent: false),
        .init(header: "Sat · Aug 30", title: "End-of-Summer Luau",
              subtitle: "6:00 PM · Pool · Family", isEvent: true),
    ]

    private func isVisible(_ entry: CalendarAgendaEntry) -> Bool {
        entry.isEvent ? showEvents : showRentals
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(entries) { entry in
                if isVisible(entry) {
                    Text(entry.header.uppercased())
                        .font(FMW.ui(11.5, .heavy))
                        .tracking(0.7)
                        .foregroundStyle(FMW.muted)
                        .padding(.horizontal, 6)
                        .padding(.top, 14)
                        .padding(.bottom, 6)

                    CalendarAgendaRow(entry: entry)
                        .padding(.bottom, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CalendarAgendaEntry: Identifiable {
    let id = UUID()
    let header: String
    let title: String
    let subtitle: String
    let isEvent: Bool
}

private struct CalendarAgendaRow: View {
    let entry: CalendarAgendaEntry

    private var barColor: Color { entry.isEvent ? FMW.pine : FMW.sun }
    private var tagText: String { entry.isEvent ? "Event" : "Rental" }
    private var tagBg: Color { entry.isEvent ? FMW.mint : FMW.pillSunBg }
    private var tagFg: Color { entry.isEvent ? FMW.pineDeep : FMW.pillSunFg }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(barColor)
                .frame(width: 4)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(FMW.display(14.5, .semibold))
                    .foregroundStyle(FMW.ink)
                Text(entry.subtitle)
                    .font(FMW.ui(12))
                    .foregroundStyle(FMW.muted)
            }

            Spacer(minLength: 8)

            Text(tagText)
                .font(FMW.ui(10, .heavy))
                .foregroundStyle(tagFg)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(tagBg, in: Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FMW.paper, in: RoundedRectangle(cornerRadius: FMW.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FMW.radius, style: .continuous)
                .stroke(FMW.line.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: FMW.ink.opacity(0.16), radius: 9, x: 0, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.header). \(entry.title). \(entry.subtitle). \(tagText).")
    }
}

#Preview {
    CalendarView()
}
