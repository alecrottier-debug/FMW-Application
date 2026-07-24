import SwiftUI

/// App entry point. The whole product hangs off a single stable tab shell (behind
/// an auth gate) — new modules surface inside those tabs, never as new tabs.
@main
struct FoxMillWoodsApp: App {
    @State private var auth = AuthService()
    @State private var payments = PaymentService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(payments)
        }
    }
}
