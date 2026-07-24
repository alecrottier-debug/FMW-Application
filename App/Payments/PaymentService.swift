import Foundation
import UIKit
@preconcurrency import StripePaymentSheet

/// Presents Stripe PaymentSheet for event checkout and annual dues. Card/bank data
/// goes directly to Stripe (PCI SAQ A) — the app only ever handles a client secret.
///
/// For ACH, "completed" means the customer *authorized* the debit; the money clears
/// asynchronously and `membershipStatus` flips only on the Stripe webhook (spec §8a).
@MainActor
@Observable
final class PaymentService {
    var lastError: String?

    private let client = APIClient.shared
    private var currentSheet: PaymentSheet?

    init() {
        if !AppConfig.stripePublishableKey.isEmpty {
            StripeAPI.defaultPublishableKey = AppConfig.stripePublishableKey
        }
    }

    /// Annual dues via bank (ACH) or card.
    @discardableResult
    func payDues(method: String) async -> Bool {
        await pay(path: "dues/intent", body: DuesIntentRequest(method: method))
    }

    /// Itemized event checkout (Order/OrderLines priced server-side).
    @discardableResult
    func payOrder(eventId: String, lines: [OrderLineInput]) async -> Bool {
        await pay(path: "payments/intent", body: OrderIntentRequest(eventId: eventId, lines: lines))
    }

    private func pay<B: Encodable & Sendable>(path: String, body: B) async -> Bool {
        guard AppConfig.isAPIConfigured, !AppConfig.stripePublishableKey.isEmpty else {
            lastError = "Payments aren’t configured yet — set the API URL and Stripe publishable key."
            return false
        }
        do {
            let intent: IntentResponse = try await client.post(path, body: body)
            return await present(clientSecret: intent.clientSecret)
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    private func present(clientSecret: String) async -> Bool {
        var config = PaymentSheet.Configuration()
        config.merchantDisplayName = "Fox Mill Woods"
        config.allowsDelayedPaymentMethods = true // ACH settles later

        let sheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: config)
        currentSheet = sheet // keep alive during presentation

        guard let presenter = Self.topViewController() else {
            lastError = "Couldn’t find a view controller to present from."
            return false
        }

        let completed: Bool = await withCheckedContinuation { continuation in
            sheet.present(from: presenter) { result in
                switch result {
                case .completed: continuation.resume(returning: true)
                case .canceled: continuation.resume(returning: false)
                case .failed(let error):
                    self.lastError = error.localizedDescription
                    continuation.resume(returning: false)
                }
            }
        }
        currentSheet = nil
        return completed
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var top = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

struct OrderLineInput: Encodable {
    let eventItemId: String
    let quantity: Int
}

private struct DuesIntentRequest: Encodable { let method: String }
private struct OrderIntentRequest: Encodable {
    let eventId: String
    let lines: [OrderLineInput]
}
private struct IntentResponse: Decodable { let clientSecret: String }
