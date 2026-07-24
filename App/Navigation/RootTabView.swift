import SwiftUI

/// The stable five-tab shell: **Home · Events · Calendar · Wallet · You**.
///
/// Do not add tabs. New modules surface on Home (or inside an existing tab),
/// never as a sixth tab. Scan is a coordinator/board action inside the money
/// context, not a tab. See CLAUDE.md "Navigation".
///
/// Each screen draws its own prototype-style header, so the tabs don't use a
/// system navigation bar. Inter-screen push navigation (Home tiles → Rentals/
/// Directory/Pool, Events row → detail, Wallet → dues/scan) is wired separately.
struct RootTabView: View {
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
        // QA hook: `SIMCTL_CHILD_FMW_SCREEN=<name>` renders one screen full-bleed
        // so any screen (including pushed/detail ones) can be captured on the
        // simulator. Inert in normal launches.
        if let name = ProcessInfo.processInfo.environment["FMW_SCREEN"], !name.isEmpty {
            DebugScreen(name: name)
        } else {
            tabs
        }
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            NavigationStack {
                HomeView(onOpenEvents: { selection = .events })
                    .toolbar(.hidden, for: .navigationBar)
                    .fmwDestinations()
            }
            .tag(Tab.home)
            .tabItem { Label(Tab.home.title, systemImage: Tab.home.symbol) }

            NavigationStack {
                EventsView()
                    .toolbar(.hidden, for: .navigationBar)
                    .fmwDestinations()
            }
            .tag(Tab.events)
            .tabItem { Label(Tab.events.title, systemImage: Tab.events.symbol) }

            CalendarView()
                .tag(Tab.calendar)
                .tabItem { Label(Tab.calendar.title, systemImage: Tab.calendar.symbol) }

            NavigationStack {
                WalletView()
                    .toolbar(.hidden, for: .navigationBar)
                    .fmwDestinations()
            }
            .tag(Tab.wallet)
            .tabItem { Label(Tab.wallet.title, systemImage: Tab.wallet.symbol) }

            YouView()
                .tag(Tab.you)
                .tabItem { Label(Tab.you.title, systemImage: Tab.you.symbol) }
        }
        .tint(FMW.pine)
    }
}

/// Push destinations shared by every tab's NavigationStack, so a
/// `NavigationLink(value: AppRoute.x)` anywhere resolves regardless of host tab.
enum AppRoute: Hashable {
    case eventDetail, eventEditor, rentals, directory, pool, dues, scan
}

private extension View {
    func fmwDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            AppRouteView(route: route)
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

/// Concrete-view switch (no `AnyView`) mapping a route to its screen.
private struct AppRouteView: View {
    let route: AppRoute
    @ViewBuilder var body: some View {
        switch route {
        case .eventDetail: EventDetailView()
        case .eventEditor: EventEditorView()
        case .rentals:     RentalsView()
        case .directory:   DirectoryView()
        case .pool:        PoolView()
        case .dues:        DuesView()
        case .scan:        ScanView()
        }
    }
}

/// Concrete-view switch (no `AnyView`) used only by the QA screenshot hook.
private struct DebugScreen: View {
    let name: String

    @ViewBuilder var body: some View {
        switch name {
        case "home":              HomeView()
        case "events":            EventsView()
        case "event":             EventDetailView()
        case "calendar":          CalendarView()
        case "rentals":           RentalsView()
        case "wallet":            WalletView()
        case "wallet-committee":  WalletView(role: .boardMember)
        case "scan":              ScanView()
        case "you":               YouView()
        case "editor":            EventEditorView()
        case "directory":         DirectoryView()
        case "directory-board":   DirectoryView(role: .boardMember)
        case "pool":              PoolView()
        case "dues":              DuesView()
        default:                  HomeView()
        }
    }
}

#Preview {
    RootTabView()
}
