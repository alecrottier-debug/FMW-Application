import Foundation
import AuthenticationServices
import UIKit
@preconcurrency import GoogleSignIn

/// Native **Sign in with Apple** + **Google Sign-In**. The provider gives an identity
/// token; we send it to `/auth/session`, the API verifies it and returns our own
/// session token, which we store in the Keychain and use for every request.
@MainActor
@Observable
final class AuthService {
    var currentUser: APIUser?
    var isLoading = false
    var errorMessage: String?

    var isSignedIn: Bool { currentUser != nil }

    private let keychain = KeychainStore()
    private var appleCoordinator: AppleSignInCoordinator?

    private var api: APIClient {
        let keychain = keychain
        return APIClient(baseURL: AppConfig.apiBaseURL, tokenProvider: { keychain.token })
    }

    /// Restore the session on launch.
    func restore() async {
        guard keychain.token != nil else { return }
        await loadMe()
    }

    // MARK: - Sign in with Apple

    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let (idToken, name) = try await requestAppleCredential()
            try await exchange(provider: "apple", idToken: idToken, name: name)
        } catch let error as ASAuthorizationError where error.code == .canceled {
            // user dismissed — not an error
        } catch {
            setError(error)
        }
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() async {
        guard let clientID = AppConfig.googleClientID else {
            errorMessage = "Google sign-in isn’t configured yet."
            return
        }
        guard let presenter = Self.topViewController() else {
            errorMessage = "Couldn’t find a view controller to present from."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else { throw AuthError.noIdentityToken }
            try await exchange(provider: "google", idToken: idToken, name: result.user.profile?.name)
        } catch let error as NSError where error.code == GIDSignInError.canceled.rawValue {
            // user cancelled
        } catch {
            setError(error)
        }
    }

    func signOut() {
        keychain.token = nil
        currentUser = nil
        GIDSignIn.sharedInstance.signOut()
    }

    /// Update the signed-in member's own account details (name, phone). Refreshes currentUser.
    func updateProfile(name: String, phone: String?) async throws {
        let updated: APIUser = try await api.post(
            "users/me",
            body: UpdateProfileRequest(name: name, phone: phone)
        )
        currentUser = updated
    }

    // MARK: - Session exchange

    private func exchange(provider: String, idToken: String, name: String?) async throws {
        let session: SessionResponse = try await api.post(
            "auth/session",
            body: SessionRequest(provider: provider, idToken: idToken, name: name)
        )
        keychain.token = session.token
        currentUser = session.user
    }

    private func loadMe() async {
        do {
            currentUser = try await api.get("users/me")
        } catch {
            setError(error)
        }
    }

    private func setError(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func requestAppleCredential() async throws -> (idToken: String, name: String?) {
        try await withCheckedThrowingContinuation { continuation in
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let coordinator = AppleSignInCoordinator(continuation: continuation)
            appleCoordinator = coordinator
            controller.delegate = coordinator
            controller.presentationContextProvider = coordinator
            controller.performRequests()
        }
    }

    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var top = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

enum AuthError: LocalizedError {
    case noIdentityToken
    var errorDescription: String? { "No identity token was returned by the provider." }
}

struct SessionRequest: Encodable, Sendable {
    let provider: String
    let idToken: String
    let name: String?
}

struct SessionResponse: Decodable {
    let token: String
    let user: APIUser
}

struct UpdateProfileRequest: Encodable, Sendable {
    let name: String
    let phone: String?
}

/// Bridges ASAuthorizationController's delegate callbacks to an async continuation.
final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    private let continuation: CheckedContinuation<(idToken: String, name: String?), Error>
    private var finished = false

    init(continuation: CheckedContinuation<(idToken: String, name: String?), Error>) {
        self.continuation = continuation
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8)
        else {
            finish(.failure(AuthError.noIdentityToken))
            return
        }
        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        finish(.success((token, name.isEmpty ? nil : name)))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        finish(.failure(error))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }

    private func finish(_ result: Result<(idToken: String, name: String?), Error>) {
        guard !finished else { return }
        finished = true
        continuation.resume(with: result)
    }
}
