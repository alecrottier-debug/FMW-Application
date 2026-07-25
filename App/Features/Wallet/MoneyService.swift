import Foundation

/// Committee money dashboard data — the reconciled books for one event
/// (`GET /api/events/{id}/summary`). Everything ties back to line items so the
/// budget ring, payments-in, sales-by-item, who-paid-what, and owed-to-volunteers
/// all agree.
struct MoneyService {
    var client: APIClient = .shared

    func events() async throws -> [EventSummary] {
        let response: MoneyEventsEnvelope = try await client.get("events")
        return response.events
    }

    func summary(eventId: String) async throws -> MoneySummaryDTO {
        try await client.get("events/\(eventId)/summary")
    }
}

private struct MoneyEventsEnvelope: Decodable { let events: [EventSummary] }

struct MoneySummaryDTO: Decodable, Sendable {
    let event: EventRef
    let budget: BudgetDTO
    let paymentsIn: [PaymentSourceDTO]
    let salesByItem: [ItemSaleDTO]
    let whoPaidWhat: [OrderDTO]
    let owedToVolunteers: [OwedDTO]

    struct EventRef: Decodable, Sendable {
        let id: String
        let title: String
        let budgetTarget: Double?
    }
    struct BudgetDTO: Decodable, Sendable {
        let collected: Double
        let spent: Double
        let budget: Double?
    }
    struct PaymentSourceDTO: Decodable, Sendable, Identifiable {
        let source: String
        let count: Int
        let amount: Double
        var id: String { source }
    }
    struct ItemSaleDTO: Decodable, Sendable, Identifiable {
        let itemId: String
        let name: String
        let unitPrice: Double
        let quantity: Int
        let amount: Double
        var id: String { itemId }
    }
    struct OrderDTO: Decodable, Sendable, Identifiable {
        let orderId: String
        let userId: String
        let name: String
        let method: String?
        let date: String?
        let total: Double
        let lines: [OrderLineDTO]
        var id: String { orderId }
    }
    struct OrderLineDTO: Decodable, Sendable {
        let label: String
        let value: Double
    }
    struct OwedDTO: Decodable, Sendable, Identifiable {
        let userId: String
        let name: String
        let detail: String?
        let owed: Double
        var id: String { userId }
    }
}
