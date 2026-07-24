import SwiftUI

/// Wallet — residents: annual dues card, ticket stubs (line items), receipts.
/// Coordinators/board: the money dashboard (sales by item, who paid for what).
struct WalletView: View {
    var body: some View {
        PlaceholderScreen(
            title: "Wallet",
            subtitle: "Annual dues, itemized ticket stubs, and — for coordinators/board — the money dashboard land here.",
            symbol: "wallet.pass.fill"
        )
    }
}

#Preview {
    WalletView()
}
