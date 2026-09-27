export type GroupType = "community" | "professional";
export type GroupJoinPolicy = "open" | "approval_required";
export type GroupStatus = "pending" | "approved" | "rejected" | "suspended";
export type GroupMemberRole = "member" | "admin" | "owner";
export type GroupMemberStatus = "pending" | "active" | "blocked";

export type GroupCursor = { sort: string; id: string };
export type CursorPage<T> = { items: T[]; nextCursor: string | null };

export interface GroupSummary {
  id: string;
  slug: string;
  name: string;
  type: GroupType;
  joinPolicy: GroupJoinPolicy;
  status: GroupStatus;
  avatarUrl: string | null;
  updatedAt: string;
}

export interface PublicGroup extends GroupSummary {
  description: string;
  city: { id: string; name: string };
  ownerUserId: string;
  coverUrl: string | null;
  approvedAt: string | null;
  createdAt: string;
  isOwner: boolean;
}

export interface MyGroup extends GroupSummary {
  rejectionReason: string | null;
  relation: { role: GroupMemberRole; status: GroupMemberStatus };
}

export interface GroupReview extends Omit<PublicGroup, "approvedAt" | "isOwner"> {
  createdBy: string;
}

export interface GroupRelation {
  role: GroupMemberRole;
  status: GroupMemberStatus;
  joinedAt: string | null;
}

export interface GroupMemberPresentation {
  userId: string;
  username: string;
  fullName: string;
  avatarUrl: string | null;
  visibility: "public" | "private";
  role: GroupMemberRole;
  status: GroupMemberStatus;
  joinedAt: string | null;
}

export interface GroupOwnerTransfer {
  transferId: string;
  groupId: string;
  fromUserId: string;
  toUserId: string;
  status: "pending" | "accepted" | "cancelled" | "expired";
  expiresAt: string;
  createdAt: string;
}
