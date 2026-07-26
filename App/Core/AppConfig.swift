import Foundation

/// App configuration from Info.plist (set per build config), with safe fallbacks.
/// Nothing secret here — only the API URL and public client ids.
enum AppConfig {
    static let apiBaseURL: URL =
        URL(string: infoString("API_BASE_URL") ?? "https://REPLACE-WITH-FUNC-APP.azurewebsites.net/api")!

    /// Google OAuth **iOS** client id (…apps.googleusercontent.com). Empty = Google disabled.
    static let googleClientID = infoString("GOOGLE_CLIENT_ID")

    /// Stripe publishable key — dues use Stripe ACH (card/bank data goes direct to Stripe, PCI SAQ A).
    static let stripePublishableKey = infoString("STRIPE_PUBLISHABLE_KEY") ?? ""

    /// True once a real API base URL is set (otherwise the app runs in demo mode).
    static var isAPIConfigured: Bool { infoString("API_BASE_URL") != nil }

    /// Once the API is configured, require sign-in; otherwise stay in demo mode.
    static var isAuthConfigured: Bool { isAPIConfigured }

    private static func infoString(_ key: String) -> String? {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String).flatMap { $0.isEmpty ? nil : $0 }
    }
}
