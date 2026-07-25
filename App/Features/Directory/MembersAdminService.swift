import Foundation

/// Board-only member administration. The API enforces boardMember on every write
/// (client gating is UX only) — see /users/{id}/role and /users/{id}/status.
struct MembersAdminService {
    var client: APIClient = .shared

    /// All members, including pending sign-ups (the board DTO from /directory).
    func members() async throws -> [DirectoryEntry] {
        let response: DirectoryEnvelope = try await client.get("directory")
        return response.neighbors
    }

    /// Change a member's role (resident ⊂ eventCoordinator ⊂ boardMember).
    func setRole(_ userId: String, to role: FMWRole) async throws {
        let _: OKResponse = try await client.post("users/\(userId)/role", body: RoleBody(role: role.rawValue))
    }

    /// Activate (approve/add) or suspend (remove access for) a member.
    func setStatus(_ userId: String, to status: String) async throws {
        let _: StatusResponse = try await client.post("users/\(userId)/status", body: StatusBody(status: status))
    }
}

private struct DirectoryEnvelope: Decodable { let neighbors: [DirectoryEntry] }
private struct RoleBody: Encodable { let role: String }
private struct StatusBody: Encodable { let status: String }
private struct OKResponse: Decodable { let ok: Bool }
private struct StatusResponse: Decodable { let ok: Bool; let status: String }
