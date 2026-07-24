import Foundation

/// Talks to the SQL-backed Events API (build-order step 2).
struct EventsService {
    var client: APIClient = .shared

    func list() async throws -> [EventSummary] {
        let response: EventsResponse = try await client.get("events")
        return response.events
    }

    func detail(id: String) async throws -> EventDetail {
        try await client.get("events/\(id)")
    }

    @discardableResult
    func create(_ body: CreateEventRequest) async throws -> EventSummary {
        try await client.post("events", body: body)
    }
}

private struct EventsResponse: Decodable {
    let events: [EventSummary]
}

/// Body for `POST /api/events` — mirrors the event editor (paid-items repeater).
struct CreateEventRequest: Encodable {
    var title: String
    var startAt: String
    var endAt: String?
    var location: String?
    var audience: String?
    var description: String?
    var ticketingType: String = "free"
    var budgetTarget: Double?
    var visibility: String = "all"
    var status: String = "draft"
    var items: [CreateEventItem] = []
}

struct CreateEventItem: Encodable {
    var name: String
    var price: Double
    var limit: Int?
    var isOptional: Bool = false
}
