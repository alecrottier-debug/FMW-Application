import SwiftUI

/// On-brand placeholder for a not-yet-built screen. Uses design tokens only
/// (no hardcoded hex / font names) so the shell already reads as Fox Mill Woods.
/// Replace each feature's body with the real screen as modules land.
struct PlaceholderScreen: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        NavigationStack {
            ZStack {
                FMW.cream.ignoresSafeArea()

                VStack(spacing: 14) {
                    Image(systemName: symbol)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(FMW.pine)
                        .padding(22)
                        .background(FMW.mint, in: Circle())
                        .accessibilityHidden(true)

                    Text(title)
                        .font(FMW.display(28))
                        .foregroundStyle(FMW.ink)

                    Text(subtitle)
                        .font(FMW.ui(15))
                        .foregroundStyle(FMW.ink.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    PlaceholderScreen(
        title: "Home",
        subtitle: "The neighborhood hub lands here.",
        symbol: "house.fill"
    )
}
