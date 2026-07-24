import Foundation

/// The signed-in user's record from `GET /api/users/me`. Roles/membership reuse
/// the shared enums in DesignTokens.swift (rawValues match the API + SQL).
struct APIUser: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let email: String?
    let phone: String?
    let role: FMWRole
    let status: String
    let membershipStatus: MembershipStatus
    let duesPaidThrough: String?
    let householdId: String?
    let emailVisibleToNeighbors: Bool?

    var isActive: Bool { status == "active" }
}

/// One row from `GET /api/directory` — fields present depend on the viewer's role
/// (the server omits what the role can't see; missing fields decode as nil).
struct DirectoryEntry: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let role: FMWRole
    let email: String?
    let phone: String?
    let membershipStatus: MembershipStatus?
    let address: String?
    let status: String?
}

// MARK: - Events

struct EventSummary: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let startAt: String // ISO-8601
    let endAt: String?
    let location: String?
    let audience: String?
    let ticketingType: String // "free" | "paid"
    let status: String
    let itemCount: Int?
}

struct EventItemDTO: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let price: Double
    let limit: Int?
    let isOptional: Bool
}

struct EventDetail: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let startAt: String
    let endAt: String?
    let location: String?
    let audience: String?
    let description: String?
    let ticketingType: String
    let status: String
    let items: [EventItemDTO]
}
