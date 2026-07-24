import SwiftUI

/// Directory — the neighbor directory (Design/prototype.html, data-screen="directory").
/// A soft mint hero with a back button and a Fraunces title, a role-aware stat bar,
/// a search field, dues filters (committee), a sort row, and a compact A–Z list of
/// neighbors with a native section index.
///
/// **Field visibility is tiered by role and enforced server-side.** The client only
/// renders what the role's DTO returns — a resident sees name + email only (never
/// phone, address, or dues status); a coordinator adds phone + dues; a board member
/// adds home address and can see pending members. Never hide a field with a client
/// filter alone; the Azure API is the authority.
struct DirectoryView: View {
    /// Set by the parent; the API returns a role-specific DTO. Client gating is UX only.
    let role: FMWRole

    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var sort: DirSort = .name
    @State private var filter: DuesFilter = .all

    init(role: FMWRole = .resident) {
        self.role = role
    }

    // MARK: - Derived role capabilities (mirror the server DTO tiers)

    private var seesDues: Bool    { role.seesDirectoryDues }
    private var seesPhone: Bool   { role.seesDirectoryPhone }
    private var seesAddress: Bool { role.seesDirectoryAddress }
    private var seesPending: Bool { role.seesPendingMembers }

    /// Falls back to name if the selected sort isn't permitted for this role.
    private var effectiveSort: DirSort {
        switch sort {
        case .status:  return seesDues ? .status : .name
        case .address: return seesAddress ? .address : .name
        default:       return sort
        }
    }
    private var grouped: Bool { effectiveSort == .name }

    private var availableSorts: [DirSort] {
        var s: [DirSort] = [.name]
        if seesDues { s.append(.status) }
        if seesAddress { s.append(.address) }
        s.append(.role)
        return s
    }
    private var availableFilters: [DuesFilter] {
        var f: [DuesFilter] = [.all, .paid, .unpaid]
        if seesPending { f.append(.pending) }
        return f
    }

    // MARK: - Data pipeline

    private var filteredMembers: [DirectoryMember] {
        var rows = Self.members.filter { m in
            // Pending members are board-only.
            if !seesPending && m.status == .pending { return false }
            // Dues filter is committee-only.
            if seesDues {
                switch filter {
                case .all:     break
                case .paid:    if m.status != .paid { return false }
                case .unpaid:  if m.status != .unpaid { return false }
                case .pending: if m.status != .pending { return false }
                }
            }
            return true
        }

        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            rows = rows.filter { m in
                var hay = m.name.lowercased() + " " + m.email.lowercased()
                if seesPhone { hay += " " + m.phone.lowercased() }
                if seesAddress { hay += " " + m.address.lowercased() }
                return hay.contains(q)
            }
        }

        return rows.sorted { a, b in
            switch effectiveSort {
            case .name:
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .status:
                if a.status.sortRank != b.status.sortRank { return a.status.sortRank < b.status.sortRank }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .role:
                if a.role.rank != b.role.rank { return a.role.rank < b.role.rank }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .address:
                return a.address.localizedCaseInsensitiveCompare(b.address) == .orderedAscending
            }
        }
    }

    /// Grouped into A–Z sections when sorted by name; otherwise a single flat section.
    private var sections: [(letter: String, members: [DirectoryMember])] {
        let rows = filteredMembers
        guard grouped else { return [(letter: "", members: rows)] }
        var order: [String] = []
        var map: [String: [DirectoryMember]] = [:]
        for m in rows {
            let key = String(m.name.prefix(1)).uppercased()
            if map[key] == nil { order.append(key) }
            map[key, default: []].append(m)
        }
        return order.map { (letter: $0, members: map[$0] ?? []) }
    }

    // MARK: - Body

    var body: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    headerHero.dirPlainRow()
                    statBar.dirPlainRow()
                    searchField.dirPlainRow()
                    if seesDues { filterBar.dirPlainRow() }
                    sortRow.dirPlainRow()
                }

                ForEach(sections, id: \.letter) { section in
                    memberSection(section)
                }

                Section {
                    noticeCard.dirPlainRow()
                    Color.clear.frame(height: 24).dirPlainRow()
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(FMW.cream)
            .overlay(alignment: .trailing) {
                if grouped { azRail(proxy) }
            }
        }
    }

    // MARK: - Member sections

    @ViewBuilder
    private func memberSection(_ section: (letter: String, members: [DirectoryMember])) -> some View {
        if grouped {
            Section {
                ForEach(section.members) { m in memberRow(m).dirPlainRow() }
            } header: {
                sectionHeaderLabel(section.letter)
            }
            .id("dsec-\(section.letter)")
        } else {
            Section {
                ForEach(section.members) { m in memberRow(m).dirPlainRow() }
            }
        }
    }

    private func memberRow(_ m: DirectoryMember) -> some View {
        DirectoryViewRow(
            member: m,
            showsDues: seesDues,
            showsPhone: seesPhone,
            showsAddress: seesAddress
        )
    }

    private func sectionHeaderLabel(_ letter: String) -> some View {
        Text(letter)
            .font(FMW.display(12, .bold))
            .tracking(0.7)
            .foregroundStyle(FMW.pine)
            .textCase(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 24)
            .padding(.trailing, 12)
            .padding(.top, 12)
            .padding(.bottom, 5)
            .background(FMW.cream)
            .listRowInsets(EdgeInsets())
    }

    // MARK: - A–Z rail

    private func azRail(_ proxy: ScrollViewProxy) -> some View {
        let present = Set(sections.map(\.letter))
        return VStack(spacing: 0) {
            ForEach(Self.alphabet, id: \.self) { letter in
                let has = present.contains(letter)
                Button {
                    if has {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo("dsec-\(letter)", anchor: .top)
                        }
                    }
                } label: {
                    Text(letter)
                        .font(FMW.ui(9.5, .heavy))
                        .foregroundStyle(FMW.pine)
                        .opacity(has ? 0.75 : 0.22)
                        .frame(width: 17, height: 13)
                }
                .buttonStyle(.plain)
                .disabled(!has)
            }
        }
        .padding(.vertical, 6)
        .padding(.trailing, 2)
        .accessibilityLabel("Section index")
    }

    // MARK: - Header

    private var headerHero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { dismiss() } label: {
                HStack(spacing: 6) {
                    Text("‹").font(FMW.ui(16, .semibold))
                    Text("Home").font(FMW.ui(13, .semibold))
                }
                .foregroundStyle(FMW.pineDeep)
                .padding(.leading, 10)
                .padding(.trailing, 13)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.7), in: Capsule())
                .overlay(Capsule().stroke(FMW.lineMint, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to Home")

            Text(roleKicker)
                .font(FMW.ui(11, .heavy))
                .tracking(1.3)
                .foregroundStyle(roleKickerColor)
                .padding(.top, 12)

            Text("Directory")
                .font(FMW.display(25, .bold))
                .foregroundStyle(FMW.ink)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(DirTokens.heroGradient)
        .clipped()
    }

    private var roleKicker: String {
        switch role {
        case .resident:         "FOX MILL WOODS"
        case .eventCoordinator: "EVENT COORDINATOR"
        case .boardMember:      "BOARD MEMBER"
        }
    }
    private var roleKickerColor: Color { role == .eventCoordinator ? FMW.sun : FMW.pine }

    // MARK: - Stat bar

    private var statBar: some View {
        HStack(spacing: 9) {
            if seesDues {
                DirStatCard(value: "168", label: "Paid", valueColor: FMW.pine)
                DirStatCard(value: "44", label: "Unpaid", valueColor: FMW.danger)
                if seesPending {
                    DirStatCard(value: "2", label: "Pending", valueColor: DirTokens.pendingGold)
                }
            } else {
                DirStatCard(value: "212", label: "Neighbors")
                DirStatCard(value: "96", label: "Households")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
    }

    // MARK: - Search

    private var searchField: some View {
        TextField(
            "Search neighbors",
            text: $searchText,
            prompt: Text("Search neighbors…").foregroundStyle(DirTokens.placeholder)
        )
        .font(FMW.ui(15, .semibold))
        .foregroundStyle(FMW.ink)
        .tint(FMW.pine)
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled()
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background(FMW.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FMW.line, lineWidth: 1.5)
        )
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    // MARK: - Filter bar (committee only)

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableFilters, id: \.self) { f in
                    DirFilterChip(
                        title: f.title,
                        dot: f.dotColor,
                        isOn: filter == f
                    ) { filter = f }
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.top, 12)
    }

    // MARK: - Sort row

    private var sortRow: some View {
        HStack(spacing: 8) {
            Text("Sort")
                .font(FMW.ui(12, .bold))
                .foregroundStyle(FMW.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(availableSorts, id: \.self) { s in
                        DirSortChip(title: s.label, isOn: effectiveSort == s) { sort = s }
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 2)
    }

    // MARK: - Notice

    private var noticeCard: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "lock.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FMW.pine)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(noticeTitle)
                    .font(FMW.ui(13.5, .bold))
                    .foregroundStyle(FMW.ink)
                Text(noticeBody)
                    .font(FMW.ui(12.5))
                    .foregroundStyle(FMW.muted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FMW.mint)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FMW.lineMint, lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.top, 14)
    }

    private var noticeTitle: String {
        switch role {
        case .resident:         "What neighbors can see"
        case .eventCoordinator: "Coordinator view"
        case .boardMember:      "Board view · full records"
        }
    }
    private var noticeBody: String {
        switch role {
        case .resident:
            "You see names and email addresses only. Your address and phone stay private to the board, and dues status is never shown to other residents. You can hide your email in Settings."
        case .eventCoordinator:
            "You can see dues status, email, and phone to run events. Home addresses are board-only. Every record you open is logged."
        case .boardMember:
            "You see every field, including addresses. Used to verify residency and track membership — never shared or sold. Dues and role changes are written to the audit log."
        }
    }

    // MARK: - Sample data (copied from the prototype)

    private static let alphabet: [String] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(String.init)

    private static let members: [DirectoryMember] = [
        .init(name: "Sarah M.",      initials: "SM", email: "sarah.m@email.com",  phone: "(703) 555-0142", address: "2630 Black Fir Ct", role: .coordinator, status: .paid,    tint: Color(hex: 0xE86F4E)),
        .init(name: "Alex Rivera",   initials: "AR", email: "alex.r@email.com",   phone: "(703) 555-0118", address: "2634 Black Fir Ct", role: .board,       status: .paid,    tint: Color(hex: 0x2E7D63)),
        .init(name: "Dana R.",       initials: "DR", email: "dana.r@email.com",   phone: "(703) 555-0177", address: "2639 Black Fir Ct", role: .coordinator, status: .paid,    tint: Color(hex: 0x5FB4AE)),
        .init(name: "Kim W.",        initials: "KW", email: "kim.w@email.com",    phone: "(703) 555-0163", address: "2648 Black Fir Ct", role: .resident,    status: .unpaid,  tint: Color(hex: 0xC99A3A)),
        .init(name: "Mike K.",       initials: "MK", email: "mike.k@email.com",   phone: "(703) 555-0129", address: "2612 Fox Mill Rd",  role: .resident,    status: .paid,    tint: Color(hex: 0x8A7CC9)),
        .init(name: "Priya N.",      initials: "PN", email: "priya.n@email.com",  phone: "(703) 555-0195", address: "2655 Black Fir Ct", role: .resident,    status: .unpaid,  tint: Color(hex: 0x4B8FB5)),
        .init(name: "Tom & Lisa B.", initials: "TB", email: "the.bs@email.com",   phone: "(703) 555-0151", address: "2601 Fox Mill Rd",  role: .resident,    status: .paid,    tint: Color(hex: 0xB5654B)),
        .init(name: "Jordan Tull",   initials: "JT", email: "jordan.t@email.com", phone: "(703) 555-0184", address: "2641 Black Fir Ct", role: .resident,    status: .pending, tint: Color(hex: 0x8A7CC9)),
        .init(name: "Grace O.",      initials: "GO", email: "grace.o@email.com",  phone: "(703) 555-0136", address: "2660 Fox Mill Rd",  role: .resident,    status: .pending, tint: Color(hex: 0x6A9C78)),
        .init(name: "Ben Ortiz",     initials: "BO", email: "ben.o@email.com",    phone: "(703) 555-0110", address: "2622 Fox Mill Rd",  role: .resident,    status: .paid,    tint: Color(hex: 0x7B9C5A)),
        .init(name: "Elena Voss",    initials: "EV", email: "elena.v@email.com",  phone: "(703) 555-0172", address: "2668 Black Fir Ct", role: .resident,    status: .paid,    tint: Color(hex: 0xA0679C)),
        .init(name: "Hank Delgado",  initials: "HD", email: "hank.d@email.com",   phone: "(703) 555-0158", address: "2607 Fox Mill Rd",  role: .resident,    status: .unpaid,  tint: Color(hex: 0x4B7FB5)),
        .init(name: "Nina Patel",    initials: "NP", email: "nina.p@email.com",   phone: "(703) 555-0191", address: "2652 Black Fir Ct", role: .resident,    status: .paid,    tint: Color(hex: 0xC97A5A)),
        .init(name: "Wes Carter",    initials: "WC", email: "wes.c@email.com",    phone: "(703) 555-0104", address: "2615 Fox Mill Rd",  role: .resident,    status: .paid,    tint: Color(hex: 0x5A8C8C)),
        .init(name: "Ana Whitfield", initials: "AW", email: "ana.w@email.com",    phone: "(703) 555-0166", address: "2644 Black Fir Ct", role: .resident,    status: .paid,    tint: Color(hex: 0xB58A4B)),
        .init(name: "Marco Silva",   initials: "MS", email: "marco.s@email.com",  phone: "(703) 555-0123", address: "2618 Fox Mill Rd",  role: .resident,    status: .unpaid,  tint: Color(hex: 0x6A7FB5)),
        .init(name: "Beth Kowalski", initials: "BK", email: "beth.k@email.com",   phone: "(703) 555-0147", address: "2663 Black Fir Ct", role: .resident,    status: .paid,    tint: Color(hex: 0x9C6A7B)),
        .init(name: "Sam Whitaker",  initials: "SW", email: "sam.w@email.com",    phone: "(703) 555-0139", address: "2609 Fox Mill Rd",  role: .resident,    status: .paid,    tint: Color(hex: 0x5A9C6A)),
        .init(name: "Deb Ferraro",   initials: "DF", email: "deb.f@email.com",    phone: "(703) 555-0188", address: "2657 Black Fir Ct", role: .resident,    status: .unpaid,  tint: Color(hex: 0xC9865A))
    ]
}

// MARK: - Row

/// One compact ~52pt directory row: avatar, name + optional role tag, a single
/// truncated detail line (fields depend on role), and a dues-status dot for committee.
private struct DirectoryViewRow: View {
    let member: DirectoryMember
    let showsDues: Bool
    let showsPhone: Bool
    let showsAddress: Bool

    private var detail: String {
        var s = member.email
        if showsPhone { s += " · " + member.phone }
        if showsAddress { s += " · " + member.address }
        return s
    }

    var body: some View {
        HStack(spacing: 11) {
            Text(member.initials)
                .font(FMW.ui(12, .heavy))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(member.tint, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(member.name)
                        .font(FMW.ui(14, .semibold))
                        .foregroundStyle(FMW.ink)
                    if let tag = member.role.tag {
                        Text(tag)
                            .font(FMW.ui(9, .heavy))
                            .tracking(0.5)
                            .foregroundStyle(member.role.tagFg)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(member.role.tagBg, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }
                Text(detail)
                    .font(FMW.ui(11.5))
                    .foregroundStyle(FMW.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 6)

            if showsDues {
                Circle()
                    .fill(DirectoryViewRow.duesColor(member.status))
                    .frame(width: 9, height: 9)
                    .accessibilityLabel(member.status.label)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FMW.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(FMW.line.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: FMW.ink.opacity(0.12), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 12)
        .padding(.bottom, 5)
        .accessibilityElement(children: .combine)
    }

    /// Dues dot colors match the prototype's DUECOLOR (pending uses a muted gold).
    private static func duesColor(_ status: MembershipStatus) -> Color {
        switch status {
        case .paid:       FMW.pine
        case .unpaid:     FMW.danger
        case .pending:    DirTokens.pendingGold
        case .processing: FMW.water
        }
    }
}

// MARK: - Stat card

private struct DirStatCard: View {
    let value: String
    let label: String
    var valueColor: Color = FMW.ink

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(FMW.display(20, .bold))
                .monospacedDigit()
                .foregroundStyle(valueColor)
            Text(label.uppercased())
                .font(FMW.ui(10, .heavy))
                .tracking(0.7)
                .foregroundStyle(FMW.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(FMW.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FMW.line.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: FMW.ink.opacity(0.10), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Chips

private struct DirFilterChip: View {
    let title: String
    let dot: Color?
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let dot {
                    Circle().fill(dot).frame(width: 9, height: 9)
                }
                Text(title).font(FMW.ui(13, .semibold))
            }
            .foregroundStyle(isOn ? Color.white : FMW.pineDeep)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isOn ? FMW.ink : FMW.paper, in: Capsule())
            .overlay(Capsule().stroke(isOn ? FMW.ink : FMW.lineMint, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

private struct DirSortChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(FMW.ui(12.5, .bold))
                .foregroundStyle(isOn ? Color.white : FMW.pineDeep)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isOn ? FMW.ink : FMW.paper, in: Capsule())
                .overlay(Capsule().stroke(isOn ? FMW.ink : FMW.lineMint, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Model

private struct DirectoryMember: Identifiable {
    let id = UUID()
    let name: String
    let initials: String
    let email: String
    let phone: String
    let address: String
    let role: DirectoryMemberRole
    let status: MembershipStatus
    let tint: Color
}

/// A member's standing in the directory, separate from the viewer's `FMWRole`.
/// Only board & coordinator members carry a visible tag.
private enum DirectoryMemberRole {
    case resident, coordinator, board

    /// Short uppercase tag (prototype: role.toUpperCase().slice(0,5)); residents show none.
    var tag: String? {
        switch self {
        case .board:       "BOARD"
        case .coordinator: "COORD"
        case .resident:    nil
        }
    }
    var tagBg: Color {
        switch self {
        case .board:       FMW.mint
        case .coordinator: FMW.pillSunBg
        case .resident:    .clear
        }
    }
    var tagFg: Color {
        switch self {
        case .board:       FMW.pineDeep
        case .coordinator: FMW.pillSunFg
        case .resident:    .clear
        }
    }
    /// Sort rank for the "Role" sort (board first).
    var rank: Int {
        switch self {
        case .board:       0
        case .coordinator: 1
        case .resident:    2
        }
    }
}

private enum DirSort: Hashable {
    case name, status, address, role
    var label: String {
        switch self {
        case .name:    "Name"
        case .status:  "Dues status"
        case .address: "Address"
        case .role:    "Role"
        }
    }
}

private enum DuesFilter: Hashable {
    case all, paid, unpaid, pending
    var title: String {
        switch self {
        case .all:     "All"
        case .paid:    "Paid"
        case .unpaid:  "Unpaid"
        case .pending: "Pending"
        }
    }
    var dotColor: Color? {
        switch self {
        case .all:     nil
        case .paid:    FMW.pine
        case .unpaid:  FMW.danger
        case .pending: DirTokens.chipGold
        }
    }
}

// MARK: - Local tokens (shades sampled from the prototype; not in DesignTokens)

private enum DirTokens {
    static let heroMid     = Color(hex: 0xDCEEDF)  // detail-hero mid stop
    static let heroEnd     = Color(hex: 0xDDF0EE)  // detail-hero end stop (teal-mint)
    static let placeholder = Color(hex: 0xB8B2A3)  // .tinput placeholder
    static let pendingGold = Color(hex: 0xC9A23A)  // DUECOLOR.pending dot
    static let chipGold    = Color(hex: 0xC9B46A)  // pending filter chip dot

    // detail-hero override: linear-gradient(165deg,#EAF4EC,#DCEEDF 60%,#DDF0EE)
    static let heroGradient = LinearGradient(
        stops: [
            .init(color: FMW.mint, location: 0),
            .init(color: heroMid,  location: 0.6),
            .init(color: heroEnd,  location: 1.0)
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Local helpers

private extension View {
    /// Strips a List row down to the prototype look: no insets, no separator, cream base.
    func dirPlainRow() -> some View {
        self
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(FMW.cream)
    }
}

#Preview("Resident") {
    DirectoryView()
}

#Preview("Board") {
    // The parent injects role from the session; board sees every field + pending members.
    DirectoryView(role: .boardMember)
}
