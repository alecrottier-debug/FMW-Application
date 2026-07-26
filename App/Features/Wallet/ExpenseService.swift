import Foundation

/// Talks to the SQL-backed Expenses API (Scan → expense). Also loads the events and
/// neighbors that populate the review-form pickers, so "apply to event" and "paid by"
/// bind to real ids, not free text.
struct ExpenseService {
    var client: APIClient = .shared

    @discardableResult
    func create(_ body: CreateExpenseRequest) async throws -> ExpenseDTO {
        try await client.post("expenses", body: body)
    }

    func events() async throws -> [EventSummary] {
        let response: EventsEnvelope = try await client.get("events")
        return response.events
    }

    func neighbors() async throws -> [DirectoryEntry] {
        let response: NeighborsEnvelope = try await client.get("directory")
        return response.neighbors
    }
}

private struct EventsEnvelope: Decodable { let events: [EventSummary] }
private struct NeighborsEnvelope: Decodable { let neighbors: [DirectoryEntry] }

/// Body for `POST /api/expenses` — the receipt image rides along as base64.
struct CreateExpenseRequest: Encodable, Sendable {
    var eventId: String?
    var paidByUserId: String?
    var merchant: String?
    var date: String? // "YYYY-MM-DD"
    var amount: Double
    var tax: Double?
    var category: String?
    var receiptBase64: String?
    var receiptContentType: String?
}

struct ExpenseDTO: Decodable, Identifiable, Sendable {
    let id: String
    let eventId: String?
    let paidByUserId: String
    let paidByName: String?
    let merchant: String?
    let date: String?
    let amount: Double
    let tax: Double?
    let category: String?
    let reimbursedStatus: String
    let receiptPath: String? // resolve against AppConfig.apiBaseURL to view the image
}
