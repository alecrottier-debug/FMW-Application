import SwiftUI

/// You — the profile & settings screen (spec IA "You" tab). A centered profile
/// header (avatar, name, role chip), the connected sign-in accounts (Apple /
/// Google via Entra External ID), notification & payment preferences, an in-app
/// account-deletion row (App Store 5.1.1(v)), and Sign out.
/// Built to match Design/prototype.html (data-screen="you").
struct YouView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileHeader()

                // Connected sign-in accounts (Apple / Google).
                SettingsCard(rows: [
                    YouRow(symbol: "apple.logo", title: "Apple", subtitle: "alex.rivera@icloud.com", accessory: .connected),
                    YouRow(symbol: "g.circle", title: "Google", subtitle: "alexrivera@gmail.com", accessory: .connected),
                ])

                // Preferences.
                SettingsCard(rows: [
                    YouRow(symbol: "bell", title: "Notifications", subtitle: "Event reminders on", accessory: .chevron),
                    YouRow(symbol: "creditcard", title: "Payment methods", subtitle: "Visa ···· 4242", accessory: .chevron),
                ])

                // In-app account deletion (destructive).
                SettingsCard(rows: [
                    YouRow(symbol: "trash", title: "Delete account", subtitle: "Permanently remove your account and data", accessory: .chevron, destructive: true),
                ])

                SignOutButton()
                    .padding(.horizontal, 18)
                    .padding(.top, 18)

                Color.clear.frame(height: 24)
            }
        }
        .scrollIndicators(.hidden)
        .background(FMW.cream.ignoresSafeArea())
    }
}

// One-off shades sampled from Design/prototype.html that aren't in the tokens.
private enum YouPalette {
    static let chevron    = Color(hex: 0xC7C0AF) // .lc chevron grey
    static let dangerSoft = Color(hex: 0xFBE3DC) // soft danger surface (.pill-unpaid bg)
}

// MARK: - Profile header (.profhead)

private struct ProfileHeader: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("A")
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

            Text("Alex Rivera")
                .font(FMW.display(22, .bold))
                .foregroundStyle(FMW.ink)

            RoleChip()
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Alex Rivera, Fox Mill Woods resident")
    }
}

/// Role pill (.rolechip) — resident tier by default; client gating is UX only.
private struct RoleChip: View {
    var body: some View {
        HStack(spacing: 7) {
            Text("◆").font(FMW.ui(10))
            Text("Fox Mill Woods resident").font(FMW.ui(12.5, .bold))
        }
        .foregroundStyle(FMW.pineDeep)
        .padding(.horizontal, 13)
        .padding(.vertical, 6)
        .background(FMW.mint, in: Capsule())
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
private struct YouViewRow: View {
    let row: YouRow

    private var tint: Color { row.destructive ? FMW.danger : FMW.pine }
    private var iconBackground: Color { row.destructive ? YouPalette.dangerSoft : FMW.mint }
    private var titleColor: Color { row.destructive ? FMW.danger : FMW.ink }

    var body: some View {
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

// MARK: - Sign out (.btn.btn-outline)

private struct SignOutButton: View {
    var body: some View {
        Button(action: {}) {
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
}
