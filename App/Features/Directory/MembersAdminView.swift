import SwiftUI

/// Roles & responsibilities editor (board only). List members, approve pending
/// sign-ups (add), change roles, and remove access. Every action calls the
/// board-gated API — a coordinator or resident who reached this screen would be
/// rejected server-side, so it's surfaced only to board members.
struct MembersAdminView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth

    @State private var members: [DirectoryEntry] = []
    @State private var loading = true
    @State private var errorText: String?
    @State private var busyId: String?

    private let service = MembersAdminService()

    private var pending: [DirectoryEntry] { members.filter { $0.status == "pending" } }
    private var active: [DirectoryEntry] { members.filter { $0.status != "pending" } }

    var body: some View {
        NavigationStack {
            List {
                if let errorText {
                    Text(errorText).font(FMW.ui(13)).foregroundStyle(FMW.danger)
                }

                if !pending.isEmpty {
                    Section("Pending — approve to add") {
                        ForEach(pending) { memberRow($0) }
                    }
                }

                Section(active.isEmpty ? "Members" : "\(active.count) members") {
                    if active.isEmpty && !loading {
                        Text("No active members yet.").font(FMW.ui(13)).foregroundStyle(FMW.muted)
                    }
                    ForEach(active) { memberRow($0) }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Members & roles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay { if loading { ProgressView() } }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    // MARK: Row

    private func memberRow(_ m: DirectoryEntry) -> some View {
        HStack(spacing: 12) {
            Text(initials(m.name))
                .font(FMW.ui(13, .heavy))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(FMW.pine, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(m.name).font(FMW.ui(15, .semibold)).foregroundStyle(FMW.ink)
                HStack(spacing: 6) {
                    Text(roleLabel(m.role))
                        .font(FMW.ui(11, .bold))
                        .foregroundStyle(FMW.pineDeep)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(FMW.mint, in: Capsule())
                    if m.status == "pending" {
                        Text("PENDING")
                            .font(FMW.ui(10, .bold)).tracking(0.4)
                            .foregroundStyle(FMW.sun)
                    }
                }
            }
            Spacer(minLength: 8)

            if busyId == m.id {
                ProgressView()
            } else {
                Menu {
                    if m.status == "pending" {
                        Button("Approve member") { act(m) { try await service.setStatus(m.id, to: "active") } }
                    }
                    Menu("Set role") {
                        ForEach([FMWRole.resident, .eventCoordinator, .boardMember], id: \.self) { r in
                            Button {
                                act(m) { try await service.setRole(m.id, to: r) }
                            } label: {
                                if m.role == r { Label(roleLabel(r), systemImage: "checkmark") }
                                else { Text(roleLabel(r)) }
                            }
                        }
                    }
                    if m.status == "active" {
                        Button("Remove access", role: .destructive) {
                            act(m) { try await service.setStatus(m.id, to: "pending") }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(FMW.pine)
                }
                .disabled(m.id == auth.currentUser?.id) // can't edit yourself (server rejects too)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Actions

    private func act(_ m: DirectoryEntry, _ op: @escaping () async throws -> Void) {
        busyId = m.id
        errorText = nil
        Task {
            do {
                try await op()
                await load()
            } catch {
                errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            busyId = nil
        }
    }

    private func load() async {
        loading = members.isEmpty
        defer { loading = false }
        do {
            members = try await service.members()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func roleLabel(_ r: FMWRole) -> String {
        switch r {
        case .resident: "Resident"
        case .eventCoordinator: "Event coordinator"
        case .boardMember: "Board member"
        }
    }

    private func initials(_ name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "•" : String(letters).uppercased()
    }
}
