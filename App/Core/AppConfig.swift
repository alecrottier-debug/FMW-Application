import Foundation

/// App configuration. Values come from Info.plist keys (set per build config) and
/// fall back to placeholders. Sign-in stays disabled until the Entra values are set
/// — see the go-live checklist. Nothing secret lives here (public client ids only).
enum AppConfig {
    static let apiBaseURL: URL =
        URL(string: infoString("API_BASE_URL") ?? "https://REPLACE-WITH-FUNC-APP.azurewebsites.net/api")!

    // Entra External ID (public OIDC client — no secret in the app).
    static let entraAuthorizeURL = infoString("ENTRA_AUTHORIZE_URL") ?? ""
    static let entraTokenURL = infoString("ENTRA_TOKEN_URL") ?? ""
    static let entraClientID = infoString("ENTRA_CLIENT_ID") ?? ""
    static let entraRedirectURI = infoString("ENTRA_REDIRECT_URI") ?? "foxmillwoods://auth"
    static let entraScopes = "openid profile email offline_access"

    /// Custom URL scheme used as the OAuth redirect callback.
    static let callbackScheme = "foxmillwoods"

    static var isAuthConfigured: Bool {
        !entraClientID.isEmpty && !entraAuthorizeURL.isEmpty && !entraTokenURL.isEmpty
    }

    private static func infoString(_ key: String) -> String? {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String).flatMap { $0.isEmpty ? nil : $0 }
    }
}
