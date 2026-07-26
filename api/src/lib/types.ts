// Shared domain types (mirror the SQL schema / spec §5).

export type Role = "resident" | "eventCoordinator" | "boardMember";
export type UserStatus = "pending" | "active";
export type MembershipStatus = "paid" | "unpaid" | "pending" | "processing";

export interface User {
  id: string;
  name: string;
  email: string;
  phone: string | null;
  role: Role;
  status: UserStatus;
  membershipStatus: MembershipStatus;
  duesPaidThrough: string | null;
  householdId: string | null;
  authProviderSub: string;
  emailVisibleToNeighbors: boolean;
}

const rank: Record<Role, number> = {
  resident: 0,
  eventCoordinator: 1,
  boardMember: 2,
};

/** resident ⊂ eventCoordinator ⊂ boardMember. */
export const roleAtLeast = (role: Role, min: Role): boolean => rank[role] >= rank[min];
