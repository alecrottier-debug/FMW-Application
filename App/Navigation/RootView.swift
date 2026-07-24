import SwiftUI

/// Top-level gate. Once Entra sign-in is configured, unauthenticated users see the
/// Auth screen; otherwise the app runs in demo mode (straight to the tab shell) so
/// the UI stays usable before the backend is wired.
struct RootView: View {
    @Environment(AuthService.self) private var auth

    var body: some View {
        Group {
            if AppConfig.isAuthConfigured && !auth.isSignedIn {
                AuthView()
            } else {
                RootTabView()
            }
        }
        .task { await auth.restore() }
    }
}
