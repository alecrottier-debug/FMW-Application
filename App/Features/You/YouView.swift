import SwiftUI

/// You — profile, role chip, connected accounts (Apple/Google), payment methods,
/// notifications, and in-app account deletion. Board gets member admin.
struct YouView: View {
    var body: some View {
        PlaceholderScreen(
            title: "You",
            subtitle: "Profile, role, connected accounts, payment methods, and account deletion land here.",
            symbol: "person.crop.circle.fill"
        )
    }
}

#Preview {
    YouView()
}
