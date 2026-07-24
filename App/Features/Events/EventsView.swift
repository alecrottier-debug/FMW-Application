import SwiftUI

/// Events — list → detail → RSVP/pay → My Tickets. Coordinators get
/// "plan a new event" and the itemized event editor (paid items repeater).
struct EventsView: View {
    var body: some View {
        PlaceholderScreen(
            title: "Events",
            subtitle: "Upcoming events, itemized checkout, and the coordinator event editor land here.",
            symbol: "calendar.badge.plus"
        )
    }
}

#Preview {
    EventsView()
}
