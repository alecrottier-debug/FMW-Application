import SwiftUI

/// App entry point. The whole product hangs off a single stable tab shell —
/// new modules surface inside those tabs (on Home), never as new tabs. See CLAUDE.md.
@main
struct FoxMillWoodsApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
