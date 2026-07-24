import SwiftUI

/// Events — the Crooked Fox Collective hub (spec IA "Events", prototype
/// data-screen="events"): a sunny title block, then the "Upcoming" list of
/// date-chip rows (month + day, title, time · price, chevron), plus the
/// coordinator-only "Plan a new event" entry. Rows are tappable — the parent
/// navigates to the detail/editor; this view only builds the visuals.
/// Built to match Design/prototype.html.
struct EventsView: View {
    // Chevron / trailing glyph tint from the prototype (.evrow .chev = #c7c0af).
    private static let chevron = Color(hex: 0xC7C0AF)

    // Upcoming events — sample data copied verbatim from the prototype.
    private let events: [EventsViewRowData] = [
        .init(month: "Jul", day: "22", title: "Float Night at the Pool",
              detail: "5:00 PM", price: "Free", isFree: true),
        .init(month: "Aug", day: "09", title: "Summer Sunset Social",
              detail: "7:00 PM · Adults", price: "$35", isFree: false),
        .init(month: "Aug", day: "30", title: "End-of-Summer Luau",
              detail: "6:00 PM · Family", price: "$20", isFree: false),
        .init(month: "Oct", day: "11", title: "Fall Chili Cook-off",
              detail: "4:00 PM · Household", price: "$15", isFree: false),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 14)

                sectionHead
                    .padding(.horizontal, 18)
                    .padding(.top, 22)
                    .padding(.bottom, 10)

                ForEach(events) { event in
                    EventsViewRow(data: event, chevron: Self.chevron)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                }

                PlanEventCard()
                    .padding(.horizontal, 12)
                    .padding(.top, 12)

                Color.clear.frame(height: 24)
            }
        }
        .scrollIndicators(.hidden)
        .background(FMW.cream.ignoresSafeArea())
    }

    // MARK: Title block (.pad eyebrow + h2.disp + muted lede)

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Text("◆").font(.system(size: 8))
                Text("THE CROOKED FOX COLLECTIVE")
                    .font(FMW.ui(11, .bold))
                    .tracking(1.5)
            }
            .foregroundStyle(FMW.pine)

            Text("Events")
                .font(FMW.display(26, .bold))
                .foregroundStyle(FMW.ink)
                .padding(.top, 6)

            Text("Neighborhood socials, all summer and into the fall.")
                .font(FMW.ui(13.5))
                .foregroundStyle(FMW.muted)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Section header (.section-head)

    private var sectionHead: some View {
        HStack(alignment: .lastTextBaseline) {
            Text("Upcoming")
                .font(FMW.display(18, .semibold))
                .foregroundStyle(FMW.ink)
            Spacer()
            Text("My tickets →")
                .font(FMW.ui(12.5, .semibold))
                .foregroundStyle(FMW.pine)
        }
    }
}

// MARK: - Row model

private struct EventsViewRowData: Identifiable {
    let id = UUID()
    let month: String
    let day: String
    let title: String
    let detail: String   // time, optionally "· Audience"
    let price: String    // "Free" or "$35"
    let isFree: Bool
}

// MARK: - Event row (.card.evrow)

private struct EventsViewRow: View {
    let data: EventsViewRowData
    let chevron: Color

    var body: some View {
        HStack(spacing: 13) {
            dateChip

            VStack(alignment: .leading, spacing: 2) {
                Text(data.title)
                    .font(FMW.display(16, .semibold))
                    .foregroundStyle(FMW.ink)
                HStack(spacing: 8) {
                    Text(data.detail)
                        .font(FMW.ui(12.5))
                        .foregroundStyle(FMW.muted)
                    Text("·")
                        .font(FMW.ui(12.5))
                        .foregroundStyle(FMW.muted)
                    if data.isFree {
                        FMWPill(text: data.price, bg: FMW.pillFreeBg, fg: FMW.pillFreeFg)
                    } else {
                        FMWPill(text: data.price, bg: FMW.pillSunBg, fg: FMW.pillSunFg)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("›")
                .font(FMW.ui(20, .medium))
                .foregroundStyle(chevron)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(FMW.paper)
        .clipShape(RoundedRectangle(cornerRadius: FMW.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FMW.radius, style: .continuous)
                .stroke(FMW.line.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: FMW.ink.opacity(0.16), radius: 10, x: 0, y: 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(data.title), \(data.month) \(data.day), \(data.detail), \(data.price)")
        .accessibilityAddTraits(.isButton)
    }

    private var dateChip: some View {
        VStack(spacing: 0) {
            Text(data.month.uppercased())
                .font(FMW.ui(10, .heavy))
                .tracking(0.8)
                .foregroundStyle(FMW.sun)
            Text(data.day)
                .font(FMW.display(22, .bold))
                .foregroundStyle(FMW.pineDeep)
        }
        .frame(width: 52, height: 56)
        .background(FMW.mint)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Coordinator "Plan a new event" entry (.committee-only card)

private struct PlanEventCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(FMW.pine)

            VStack(alignment: .leading, spacing: 2) {
                Text("Plan a new event")
                    .font(FMW.ui(14, .bold))
                    .foregroundStyle(FMW.ink)
                Text("Coordinator tools · budget, tickets, expenses")
                    .font(FMW.ui(12))
                    .foregroundStyle(FMW.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("New →")
                .font(FMW.ui(13.5, .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(FMW.pine, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FMW.mint)
        .clipShape(RoundedRectangle(cornerRadius: FMW.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FMW.radius, style: .continuous)
                .strokeBorder(FMW.lineMint, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Plan a new event. Coordinator tools: budget, tickets, expenses.")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    EventsView()
}
