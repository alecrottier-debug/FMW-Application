import Testing
@testable import FoxMillWoods

/// Guards the client-side representation of spec invariants (roles, directory
/// field tiers, dues status ordering, ACH asynchrony). The server remains the
/// authority for access control — these tests protect the UX-gating flags only.
struct RoleAndTokenTests {

    @Test("Roles inherit: resident ⊂ eventCoordinator ⊂ boardMember")
    func roleInheritanceOrdering() {
        #expect(FMWRole.resident < .eventCoordinator)
        #expect(FMWRole.eventCoordinator < .boardMember)
        #expect(!FMWRole.resident.canCreateEvents)
        #expect(FMWRole.eventCoordinator.canCreateEvents)
        #expect(FMWRole.boardMember.canAdministerMembers)
        #expect(!FMWRole.eventCoordinator.canAdministerMembers)
    }

    @Test("Directory field tiers match the spec §2 matrix")
    func directoryFieldTiers() {
        // Residents: name + email only — never phone, dues, or address.
        #expect(!FMWRole.resident.seesDirectoryPhone)
        #expect(!FMWRole.resident.seesDirectoryDues)
        #expect(!FMWRole.resident.seesDirectoryAddress)
        #expect(!FMWRole.resident.seesPendingMembers)

        // Coordinators: + phone + dues status, still no address.
        #expect(FMWRole.eventCoordinator.seesDirectoryPhone)
        #expect(FMWRole.eventCoordinator.seesDirectoryDues)
        #expect(!FMWRole.eventCoordinator.seesDirectoryAddress)

        // Board: + address + pending members.
        #expect(FMWRole.boardMember.seesDirectoryAddress)
        #expect(FMWRole.boardMember.seesPendingMembers)
    }

    @Test("Dues sort surfaces action-needed statuses first")
    func duesSortRankOrder() {
        let ranked = [MembershipStatus.pending, .unpaid, .processing, .paid]
        #expect(ranked.map(\.sortRank) == [0, 1, 2, 3])
    }

    @Test("Only bank (ACH) settles asynchronously — never mark paid on submit")
    func onlyBankIsAsynchronous() {
        #expect(PaymentMethodKind.bank.isAsynchronous)
        for method in [PaymentMethodKind.card, .venmo, .cash, .check] {
            #expect(!method.isAsynchronous)
        }
    }
}
