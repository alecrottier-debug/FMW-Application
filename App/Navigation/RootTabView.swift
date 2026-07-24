import SwiftUI

/// The stable five-tab shell: **Home · Events · Calendar · Wallet · You**.
///
/// Do not add tabs. New modules surface on Home (or inside an existing tab),
/// never as a sixth tab. Scan is a coordinator/board action inside the money
/// context, not a tab. See CLAUDE.md "Navigation".
struct RootTabView: View {
    /// The five function-oriented sections of the app.
    enum Tab: Hashable {
        case home, events, calendar, wallet, you

        var title: String {
            switch self {
            case .home:     "Home"
            case .events:   "Events"
            case .calendar: "Calendar"
            case .wallet:   "Wallet"
            case .you:      "You"
            }
        }

        var symbol: String {
            switch self {
            case .home:     "house.fill"
            case .events:   "calendar.badge.plus"
            case .calendar: "calendar"
            case .wallet:   "wallet.pass.fill"
            case .you:      "person.crop.circle.fill"
            }
        }
    }

    @State private var selection: Tab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tag(Tab.home)
                .tabItem { Label(Tab.home.title, systemImage: Tab.home.symbol) }

            EventsView()
                .tag(Tab.events)
                .tabItem { Label(Tab.events.title, systemImage: Tab.events.symbol) }

            CalendarView()
                .tag(Tab.calendar)
                .tabItem { Label(Tab.calendar.title, systemImage: Tab.calendar.symbol) }

            WalletView()
                .tag(Tab.wallet)
                .tabItem { Label(Tab.wallet.title, systemImage: Tab.wallet.symbol) }

            YouView()
                .tag(Tab.you)
                .tabItem { Label(Tab.you.title, systemImage: Tab.you.symbol) }
        }
        .tint(FMW.pine)
    }
}

#Preview {
    RootTabView()
}
