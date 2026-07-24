import SwiftUI

/// Calendar — cross-module, filterable by type (Events, Rentals, +future):
/// month grid with type dots plus an agenda list.
struct CalendarView: View {
    var body: some View {
        PlaceholderScreen(
            title: "Calendar",
            subtitle: "A cross-module month grid and agenda, filterable by type, land here.",
            symbol: "calendar"
        )
    }
}

#Preview {
    CalendarView()
}
