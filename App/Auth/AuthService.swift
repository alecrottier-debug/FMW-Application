import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

/// Sign-in via Entra External ID (OAuth 2.0 Authorization Code + PKCE, brokered to
/// Apple/Google). The app never stores a password; the access token lives in the
/// Keychain and is validated server-side. Stays disabled until Entra is configured.
@MainActor
@Observable
final class AuthService {
    var currentUser: APIUser?
    var isLoading = false
    var errorMessage: String?

    var isSignedIn: Bool { currentUser != nil }

    private let keychain = KeychainStore()
    private let presenter = WebAuthPresenter()

    private var api: APIClient {
        let keychain = keychain // capture the value type, not self (keeps APIClient Sendable)
        return APIClient(baseURL: AppConfig.apiBaseURL, tokenProvider: { keychain.token })
    }

    /// On launch, restore the session if a token is present.
    func restore() async {
        guard keychain.token != nil else { return }
        await loadMe()
    }

    /// `idpHint` = "apple" or "google" (Entra domain_hint), or nil to let Entra choose.
    func signIn(idpHint: String?) async {
        guard AppConfig.isAuthConfigured else {
            errorMessage = "Sign-in isn’t configured yet — set your Entra values (see the go-live checklist)."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let verifier = Self.randomURLSafe(byteCount: 48)
            let challenge = Self.codeChallenge(for: verifier)
            let code = try await authorize(challenge: challenge, idpHint: idpHint)
            let token = try await exchange(code: code, verifier: verifier)
            keychain.token = token
            await loadMe()
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // user dismissed the sheet — not an error
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func signOut() {
        keychain.token = nil
        currentUser = nil
    }

    private func loadMe() async {
        do {
            currentUser = try await api.get("users/me")
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - OAuth (Authorization Code + PKCE)

    private func authorize(challenge: String, idpHint: String?) async throws -> String {
        var components = URLComponents(string: AppConfig.entraAuthorizeURL)!
        var items = [
            URLQueryItem(name: "client_id", value: AppConfig.entraClientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: AppConfig.entraRedirectURI),
            URLQueryItem(name: "scope", value: AppConfig.entraScopes),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        if let idpHint { items.append(URLQueryItem(name: "domain_hint", value: idpHint)) }
        components.queryItems = items

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: components.url!,
                callbackURLScheme: AppConfig.callbackScheme
            ) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: error ?? URLError(.userCancelledAuthentication))
                }
            }
            session.presentationContextProvider = presenter
            session.start()
        }

        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value
        else {
            throw APIError.http(400, "No authorization code in the callback")
        }
        return code
    }

    private func exchange(code: String, verifier: String) async throws -> String {
        var request = URLRequest(url: URL(string: AppConfig.entraTokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let form = [
            "client_id": AppConfig.entraClientID,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": AppConfig.entraRedirectURI,
            "code_verifier": verifier,
            "scope": AppConfig.entraScopes,
        ]
        request.httpBody = form
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw APIError.http(status, String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data).access_token
    }

    // MARK: - PKCE

    private static func randomURLSafe(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private static func codeChallenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
    }
}

private struct TokenResponse: Decodable {
    let access_token: String
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}

/// Presents the ASWebAuthenticationSession from the key window.
final class WebAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}
