import SwiftUI
import GoogleSignIn

/// App entry point. The whole product hangs off a single stable tab shell (behind
/// an auth gate) — new modules surface inside those tabs, never as new tabs.
@main
struct FoxMillWoodsApp: App {
    @State private var auth = AuthService()
    @State private var payments = PaymentService()
    @State private var braintree = BraintreeService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(payments)
                .environment(braintree)
                .onOpenURL { url in
                    // Google Sign-In redirect callback.
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
