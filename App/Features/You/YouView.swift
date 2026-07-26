import SwiftUI

/// You — the profile & settings screen (spec IA "You" tab). Shows the real
/// signed-in member, lets them edit their own details (name/phone), routes board
/// members to the members & roles editor, explains how payments work, and signs
/// out. Built to match Design/prototype.html (data-screen="you").
struct YouView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.openURL) private var openURL

    @State private var showEditProfile = false
    @State private var showPayments = false
    @State private var showMembers = false
    @State private var showDeleteConfirm = false
    @State private var deleting = false
    @State private var deleteError: String?

    private var user: APIUser? { auth.currentUser }
    private var isBoard: Bool { (user?.role ?? .resident) >= .boardMember }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileHeader(name: user?.name ?? "Fox Mill Woods", role: user?.role ?? .resident)
                    .contentShape(Rectangle())
                    .onTapGesture { if user != nil { showEditProfile = true } }

                if let email = user?.email {
                    SettingsCard(rows: [
                        YouRow(symbol: "envelope", title: "Signed in", subtitle: email, accessory: .connected),
                    ])
                }

                SettingsCard(rows: [
                    YouRow(symbol: "person.text.rectangle", title: "Edit profile",
                           subtitle: "Your name & phone", accessory: .chevron,
                           action: user != nil ? { showEditProfile = true } : nil),
                    YouRow(symbol: "creditcard", title: "Payment methods",
                           subtitle: "How you pay dues & tickets", accessory: .chevron,
                           action: { showPayments = true }),
                ])

                if isBoard {
                    SettingsCard(rows: [
                        YouRow(symbol: "person.2.badge.gearshape", title: "Members & roles",
                               subtitle: "Approve, assign roles, remove access", accessory: .chevron,
                               action: { showMembers = true }),
                    ])
                }

                SettingsCard(rows: [
                    YouRow(symbol: "hand.raised", title: "Privacy policy",
                           subtitle: "How your data is used", accessory: .chevron,
                           action: { openURL(Self.privacyURL) }),
                    YouRow(symbol: "trash", title: "Delete account",
                           subtitle: "Permanently remove your account and data",
                           accessory: .chevron, destructive: true,
                           action: user != nil ? { showDeleteConfirm = true } : nil),
                ])

                if let deleteError {
                    Text(deleteError)
                        .font(FMW.ui(12.5, .semibold))
                        .foregroundStyle(FMW.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22).padding(.top, 8)
                }

                SignOutButton { auth.signOut() }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)

                Color.clear.frame(height: 24)
            }
        }
        .scrollIndicators(.hidden)
        .background(FMW.cream.ignoresSafeArea())
        .sheet(isPresented: $showEditProfile) {
            if let user { EditProfileView(user: user) }
        }
        .sheet(isPresented: $showPayments) { PaymentInfoView() }
        .sheet(isPresented: $showMembers) { MembersAdminView() }
        .alert("Delete account?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await deleteAccount() } }
        } message: {
            Text("This removes your name, email, phone, and address, and signs you out. This can’t be undone.")
        }
    }

    private static var privacyURL: URL {
        AppConfig.apiBaseURL.appendingPathComponent("privacy")
    }

    private func deleteAccount() async {
        deleting = true
        deleteError = nil
        do {
            try await auth.deleteAccount() // server anonymizes PII, then signs out
        } catch {
            deleteError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            deleting = false
        }
    }
}

// One-off shades sampled from Design/prototype.html that aren't in the tokens.
private enum YouPalette {
    static let chevron    = Color(hex: 0xC7C0AF) // .lc chevron grey
    static let dangerSoft = Color(hex: 0xFBE3DC) // soft danger surface (.pill-unpaid bg)
}

// MARK: - Profile header (.profhead)

private struct ProfileHeader: View {
    let name: String
    let role: FMWRole

    private var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "•" : String(letters).uppercased()
    }
    private var roleLabel: String {
        switch role {
        case .resident: "Fox Mill Woods resident"
        case .eventCoordinator: "Event coordinator"
        case .boardMember: "Board member"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(initials)
                .font(FMW.display(30, .bold))
                .foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .background(
                    LinearGradient(colors: [FMW.sun2, FMW.coral],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
                .shadow(color: FMW.ink.opacity(0.12), radius: 10, x: 0, y: 6)
                .padding(.bottom, 10)

            Text(name)
                .font(FMW.display(22, .bold))
                .foregroundStyle(FMW.ink)

            HStack(spacing: 7) {
                Text("◆").font(FMW.ui(10))
                Text(roleLabel).font(FMW.ui(12.5, .bold))
            }
            .foregroundStyle(FMW.pineDeep)
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .background(FMW.mint, in: Capsule())
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(roleLabel)")
    }
}

// MARK: - Settings list card (.card.listcard)

private enum YouAccessory { case chevron, connected }

private struct YouRow: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let subtitle: String
    let accessory: YouAccessory
    var destructive = false
    var action: (() -> Void)? = nil
}

private struct SettingsCard: View {
    let rows: [YouRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                YouViewRow(row: row)
                if index < rows.count - 1 {
                    Rectangle().fill(FMW.line).frame(height: 1)
                }
            }
        }
        .background(FMW.paper)
        .clipShape(RoundedRectangle(cornerRadius: FMW.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FMW.radius, style: .continuous)
                .stroke(FMW.line.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: FMW.ink.opacity(0.12), radius: 10, x: 0, y: 6)
        .padding(.horizontal, 12)
        .padding(.top, 16)
    }
}

/// A single settings row (.lrow): icon tile, title + subtitle, trailing accessory.
/// Becomes a button when the row carries an action.
private struct YouViewRow: View {
    let row: YouRow

    var body: some View {
        if let action = row.action {
            Button(action: action) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }

    private var tint: Color { row.destructive ? FMW.danger : FMW.pine }
    private var iconBackground: Color { row.destructive ? YouPalette.dangerSoft : FMW.mint }
    private var titleColor: Color { row.destructive ? FMW.danger : FMW.ink }

    private var content: some View {
        HStack(spacing: 13) {
            Image(systemName: row.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(iconBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(row.title)
                    .font(FMW.ui(14.5, .semibold))
                    .foregroundStyle(titleColor)
                Text(row.subtitle)
                    .font(FMW.ui(12))
                    .foregroundStyle(FMW.muted)
            }

            Spacer(minLength: 8)
            accessory
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private var accessory: some View {
        switch row.accessory {
        case .chevron:
            Text("›")
                .font(FMW.ui(20, .medium))
                .foregroundStyle(YouPalette.chevron)
        case .connected:
            HStack(spacing: 6) {
                Circle().fill(FMW.pine).frame(width: 7, height: 7)
                Text("Connected").font(FMW.ui(12, .bold))
            }
            .foregroundStyle(FMW.pine)
        }
    }
}

// MARK: - Edit profile (own account details)

private struct EditProfileView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss
    let user: APIUser

    @State private var name: String
    @State private var phone: String
    @State private var emailVisible: Bool
    @State private var saving = false
    @State private var errorText: String?

    init(user: APIUser) {
        self.user = user
        _name = State(initialValue: user.name)
        _phone = State(initialValue: user.phone ?? "")
        _emailVisible = State(initialValue: user.emailVisibleToNeighbors ?? true)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your details") {
                    TextField("Name", text: $name).textContentType(.name)
                    TextField("Phone (optional)", text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber)
                }
                if let email = user.email {
                    Section("Email") {
                        Text(email).foregroundStyle(FMW.muted)
                        Toggle("Show my email to neighbors", isOn: $emailVisible)
                            .tint(FMW.pine)
                    }
                }
                if let errorText {
                    Section { Text(errorText).font(FMW.ui(13)).foregroundStyle(FMW.danger) }
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView() }
                    else { Button("Save") { save() }.disabled(trimmedName.isEmpty) }
                }
            }
        }
    }

    private func save() {
        saving = true
        errorText = nil
        let cleanPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                try await auth.updateProfile(name: trimmedName,
                                             phone: cleanPhone.isEmpty ? nil : cleanPhone,
                                             emailVisibleToNeighbors: emailVisible)
                dismiss()
            } catch {
                errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                saving = false
            }
        }
    }
}

// MARK: - Payment methods (honest explanation; cards are entered at checkout)

private struct PaymentInfoView: View {
    @Environment(\.dismiss) private var dismiss
    private var cardConfigured: Bool { !AppConfig.stripePublishableKey.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Your card is never stored in the app", systemImage: "lock.shield")
                        .font(FMW.ui(15, .bold))
                        .foregroundStyle(FMW.pineDeep)

                    Text("When you pay annual dues or buy event tickets, your card is entered on a secure sheet and sent straight to our payment processor. Fox Mill Woods never sees or keeps your card number.")
                        .font(FMW.ui(14))
                        .foregroundStyle(FMW.ink)

                    VStack(alignment: .leading, spacing: 8) {
                        bullet("Annual dues", "Wallet → Pay dues (bank transfer or card).")
                        bullet("Event tickets", "Open an event → buy items (Apple Pay, card, or PayPal).")
                    }

                    if !cardConfigured {
                        Label("Card payments aren’t switched on yet — the board needs to connect the community’s Stripe & PayPal accounts.",
                              systemImage: "info.circle")
                            .font(FMW.ui(13))
                            .foregroundStyle(FMW.muted)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(FMW.mint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(FMW.cream.ignoresSafeArea())
            .navigationTitle("Payment methods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func bullet(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(FMW.pine).font(.system(size: 14))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(FMW.ui(13.5, .bold)).foregroundStyle(FMW.ink)
                Text(detail).font(FMW.ui(12.5)).foregroundStyle(FMW.muted)
            }
        }
    }
}

// MARK: - Sign out (.btn.btn-outline)

private struct SignOutButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("Sign out")
                .font(FMW.ui(15, .bold))
                .foregroundStyle(FMW.pineDeep)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(FMW.lineMint, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    YouView()
        .environment(AuthService())
}
