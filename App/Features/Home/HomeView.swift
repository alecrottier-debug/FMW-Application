import SwiftUI

/// Home — the neighborhood hub: next event, notices, and the module grid
/// (Events, Pavilion, Directory, Pool & Tennis). New modules surface here.
struct HomeView: View {
    var body: some View {
        PlaceholderScreen(
            title: "Home",
            subtitle: "Next event, notices, and the module grid land here. New modules surface on Home — never as a new tab.",
            symbol: "house.fill"
        )
    }
}

#Preview {
    HomeView()
}
