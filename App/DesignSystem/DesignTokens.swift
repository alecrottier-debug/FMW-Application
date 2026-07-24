import SwiftUI

// MARK: - Fox Mill Woods design tokens
// Bright, sunny palette sampled from the Fox Mill Woods identity:
// pine green primary + sunset orange accent on cream/mint surfaces.
// Fonts: Fraunces (display) + Figtree (UI). Add the .ttf files to the
// target and register them in Info.plist (ATSApplicationFontsPath / UIAppFonts).

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

enum FMW {
    // Surfaces
    static let cream    = Color(hex: 0xFBFAF3)   // warm paper base
    static let mint     = Color(hex: 0xEAF4EC)   // soft green surface
    static let mint2    = Color(hex: 0xDBEBDD)
    static let paper    = Color(hex: 0xFFFFFF)
    static let line     = Color(hex: 0xE7E1D2)

    // Brand
    static let pine     = Color(hex: 0x2E7D63)   // primary
    static let pineDeep = Color(hex: 0x1B5245)
    static let ink      = Color(hex: 0x143229)   // text

    // Accents
    static let sun      = Color(hex: 0xF2913D)   // sunset orange
    static let sun2     = Color(hex: 0xF8B45E)
    static let coral    = Color(hex: 0xE86F4E)
    static let water    = Color(hex: 0x5FB4AE)   // pool teal
    static let danger   = Color(hex: 0xC4553B)

    // Type — display (Fraunces) & UI (Figtree)
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .custom("Fraunces", size: size).weight(weight)
    }
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Figtree", size: size).weight(weight)
    }

    // Radii & shadow
    static let radius: CGFloat = 20
    static let shadow = Color.black.opacity(0.10)
}

// Convenience roles enum used across the app (enforced server-side).
enum FMWRole: String, Codable, Comparable {
    case resident, eventCoordinator, boardMember
    private var rank: Int {
        switch self { case .resident: 0; case .eventCoordinator: 1; case .boardMember: 2 }
    }
    static func < (l: FMWRole, r: FMWRole) -> Bool { l.rank < r.rank }
    var canCreateEvents: Bool { self >= .eventCoordinator }
    var canAdministerMembers: Bool { self == .boardMember }

    // Directory field tiers — mirror these on the server; the API must return
    // a role-specific DTO rather than relying on the client to hide fields.
    var seesDirectoryPhone: Bool   { self >= .eventCoordinator }
    var seesDirectoryDues: Bool    { self >= .eventCoordinator }
    var seesDirectoryAddress: Bool { self == .boardMember }
    var seesPendingMembers: Bool   { self == .boardMember }
}

/// Membership dues status. Board + coordinator only — never surface to residents.
enum MembershipStatus: String, Codable {
    case paid, unpaid, pending, processing   // `processing` = ACH submitted, not yet cleared

    var label: String {
        switch self {
        case .paid:       "Dues paid"
        case .unpaid:     "Unpaid"
        case .pending:    "Pending"
        case .processing: "Processing"
        }
    }
    var tint: Color {
        switch self {
        case .paid:       FMW.pine
        case .unpaid:     FMW.danger
        case .pending:    FMW.sun
        case .processing: FMW.water
        }
    }
    /// Sort order for the directory's "dues status" sort.
    var sortRank: Int {
        switch self { case .pending: 0; case .unpaid: 1; case .processing: 2; case .paid: 3 }
    }
}

/// How a member paid. Bank (ACH) is offered first — far cheaper at dues-sized amounts,
/// but it settles asynchronously, so never mark dues paid until the webhook confirms.
enum PaymentMethodKind: String, Codable {
    case bank, card, venmo, cash, check

    var isAsynchronous: Bool { self == .bank }   // ACH: up to 4 business days, can fail after the fact
    var title: String {
        switch self {
        case .bank:  "Bank account"
        case .card:  "Card"
        case .venmo: "Venmo"
        case .cash:  "Cash"
        case .check: "Check"
        }
    }
}
