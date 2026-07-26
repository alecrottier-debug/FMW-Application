import Foundation
import UIKit
@preconcurrency import BraintreeDropIn

/// Event / rental checkout via Braintree (a PayPal service): the Drop-in shows
/// **Apple Pay + card + PayPal**, funds settle to the community's bank. The app
/// only ever handles a one-time payment nonce; card/bank data goes to Braintree.
@MainActor
@Observable
final class BraintreeService {
    var lastError: String?

    private let client = APIClient.shared

    /// Fetch a client token, present the Drop-in, then send the nonce + line items to
    /// the API to charge and record the Order. Returns true on a completed payment.
    @discardableResult
    func checkout(eventId: String, lines: [OrderLineInput]) async -> Bool {
        guard AppConfig.isAPIConfigured else {
            lastError = "Payments aren’t configured yet."
            return false
        }
        do {
            let token: ClientTokenResponse = try await client.get("braintree/client-token")
            guard let nonce = try await presentDropIn(clientToken: token.clientToken) else {
                return false // user cancelled
            }
            let _: CheckoutResponse = try await client.post(
                "braintree/checkout",
                body: CheckoutRequest(eventId: eventId, lines: lines, paymentMethodNonce: nonce)
            )
            return true
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    private func presentDropIn(clientToken: String) async throws -> String? {
        guard let presenter = Self.topViewController() else { throw BraintreeError.noPresenter }
        return try await withCheckedThrowingContinuation { continuation in
            let request = BTDropInRequest()
            let controller = BTDropInController(authorization: clientToken, request: request) { controller, result, error in
                controller.dismiss(animated: true)
                if let error {
                    continuation.resume(throwing: error)
                } else if result == nil || result?.isCanceled == true {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: result?.paymentMethod?.nonce)
                }
            }
            guard let controller else {
                continuation.resume(throwing: BraintreeError.dropInUnavailable)
                return
            }
            presenter.present(controller, animated: true)
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var top = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

enum BraintreeError: LocalizedError {
    case noPresenter
    case dropInUnavailable
    var errorDescription: String? {
        switch self {
        case .noPresenter: "Couldn’t find a view controller to present checkout from."
        case .dropInUnavailable: "Checkout is unavailable right now."
        }
    }
}

private struct ClientTokenResponse: Decodable { let clientToken: String }
private struct CheckoutResponse: Decodable { let orderId: String; let status: String }
private struct CheckoutRequest: Encodable, Sendable {
    let eventId: String
    let lines: [OrderLineInput]
    let paymentMethodNonce: String
}
