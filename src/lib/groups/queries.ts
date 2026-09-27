import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";

import { createServerSupabaseClient } from "@/lib/supabase/server";
import { groupActionSchema, groupSlugSchema } from "@/lib/validations/group";
import type { Database } from "@/types/database";

import { decodeGroupCursor, encodeGroupCursor } from "./cursor";
import type {
  CursorPage,
  GroupMemberPresentation,
  GroupOwnerTransfer,
  GroupRelation,
  GroupReview,
  GroupSummary,
  MyGroup,
  PublicGroup,
} from "./types";

type AppClient = SupabaseClient<Database>;
type Row = Record<string, unknown>;

export class GroupQueryError extends Error {
  constructor(public readonly code: "validation_error" | "temporary_error") {
    super(code === "validation_error" ? "Os dados informados são inválidos." : "Não foi possível carregar os grupos agora.");
    this.name = "GroupQueryError";
  }
}

const text = (value: unknown) => (typeof value === "string" ? value : null);
function required(row: Row, key: string): string {
  const value = text(row[key]);
  if (!value) throw new GroupQueryError("temporary_error");
  return value;
}
function summary(row: Row): GroupSummary {
  return {
    id: required(row, "id"), slug: required(row, "slug"), name: required(row, "name"),
    type: required(row, "group_type") as GroupSummary["type"],
    joinPolicy: required(row, "join_policy") as GroupSummary["joinPolicy"],
    status: required(row, "status") as GroupSummary["status"],
    avatarUrl: text(row.avatar_url), updatedAt: required(row, "updated_at"),
  };
}
function publicGroup(row: Row): PublicGroup {
  return {
    ...summary(row), description: required(row, "description"),
    city: { id: required(row, "city_id"), name: required(row, "city_name") },
    ownerUserId: required(row, "owner_user_id"), coverUrl: text(row.cover_url),
    approvedAt: text(row.approved_at), createdAt: required(row, "created_at"),
    isOwner: row.is_owner === true,
  };
}
async function client(provided?: AppClient) { return provided ?? createServerSupabaseClient(); }
async function rpc(name: string, args: Record<string, unknown>, provided?: AppClient): Promise<Row[]> {
  const supabase = await client(provided);
  const { data, error } = await supabase.rpc(name as never, args as never);
  if (error) throw new GroupQueryError("temporary_error");
  return (data ?? []) as Row[];
}

export async function getGroupBySlug(slug: string, provided?: AppClient): Promise<PublicGroup | null> {
  const parsed = groupSlugSchema.safeParse(slug);
  if (!parsed.success) return null;
  const rows = await rpc("get_group_by_slug", { target_slug: parsed.data }, provided);
  return rows[0] ? publicGroup(rows[0]) : null;
}

export async function listMyGroups(input: { cursor?: string }, provided?: AppClient): Promise<CursorPage<MyGroup>> {
  const cursor = input.cursor ? decodeGroupCursor(input.cursor) : null;
  if (input.cursor && !cursor) throw new GroupQueryError("validation_error");
  const rows = await rpc("list_my_groups", { after_updated_at: cursor?.sort, after_id: cursor?.id, page_size: 21 }, provided);
  const mapped = rows.map((row) => ({
    ...summary(row), rejectionReason: text(row.rejection_reason),
    relation: { role: required(row, "relation_role"), status: required(row, "relation_status") },
  }) as MyGroup);
  const items = mapped.slice(0, 20);
  const last = mapped.length > 20 ? items.at(-1) : null;
  return { items, nextCursor: last ? encodeGroupCursor({ sort: last.updatedAt, id: last.id }) : null };
}

export async function listGroupReviewQueue(input: { cursor?: string }, provided?: AppClient): Promise<CursorPage<GroupReview>> {
  const cursor = input.cursor ? decodeGroupCursor(input.cursor) : null;
  if (input.cursor && !cursor) throw new GroupQueryError("validation_error");
  const rows = await rpc("list_group_review_queue", { after_created_at: cursor?.sort, after_id: cursor?.id, page_size: 21 }, provided);
  const mapped = rows.map((row) => ({ ...publicGroup({ ...row, avatar_url: null, cover_url: null, approved_at: null, is_owner: false }), createdBy: required(row, "created_by") }) as GroupReview);
  const items = mapped.slice(0, 20);
  const last = mapped.length > 20 ? items.at(-1) : null;
  return { items, nextCursor: last ? encodeGroupCursor({ sort: last.createdAt, id: last.id }) : null };
}

export async function getGroupReview(groupId: string, provided?: AppClient): Promise<(GroupReview & { rejectionReason: string | null }) | null> {
  const parsed = groupActionSchema.safeParse({ groupId });
  if (!parsed.success) return null;
  const rows = await rpc("get_group_review", { target_group_id: parsed.data.groupId }, provided);
  if (!rows[0]) return null;
  return { ...publicGroup({ ...rows[0], approved_at: null, is_owner: false }), createdBy: required(rows[0], "created_by"), rejectionReason: text(rows[0].rejection_reason) };
}

export async function getCurrentGroupRelation(groupId: string, provided?: AppClient): Promise<GroupRelation | null> {
  const parsed = groupActionSchema.safeParse({ groupId });
  if (!parsed.success) return null;
  const rows = await rpc("get_current_group_relation", { target_group_id: parsed.data.groupId }, provided);
  return rows[0] ? { role: required(rows[0], "relation_role") as GroupRelation["role"], status: required(rows[0], "relation_status") as GroupRelation["status"], joinedAt: text(rows[0].joined_at) } : null;
}

export async function listGroupMembers(groupId: string, status: "active" | "pending" | "blocked", provided?: AppClient): Promise<GroupMemberPresentation[]> {
  const parsed = groupActionSchema.safeParse({ groupId });
  if (!parsed.success) throw new GroupQueryError("validation_error");
  const rows = await rpc("list_group_members", { target_group_id: parsed.data.groupId, requested_status: status, after_username: null, after_user_id: null, page_size: 20 }, provided);
  return rows.map((row) => ({ userId: required(row, "user_id"), username: required(row, "username"), fullName: required(row, "full_name"), avatarUrl: text(row.avatar_url), visibility: required(row, "visibility") as GroupMemberPresentation["visibility"], role: required(row, "member_role") as GroupMemberPresentation["role"], status: required(row, "member_status") as GroupMemberPresentation["status"], joinedAt: text(row.joined_at) }));
}

export async function getGroupOwnerTransfer(groupId: string, provided?: AppClient): Promise<GroupOwnerTransfer | null> {
  const parsed = groupActionSchema.safeParse({ groupId });
  if (!parsed.success) throw new GroupQueryError("validation_error");
  const rows = await rpc("get_group_owner_transfer", { target_group_id: parsed.data.groupId }, provided);
  if (!rows[0]) return null;
  return {
    transferId: required(rows[0], "transfer_id"), groupId: required(rows[0], "group_id"),
    fromUserId: required(rows[0], "from_user_id"), toUserId: required(rows[0], "to_user_id"),
    status: required(rows[0], "effective_status") as GroupOwnerTransfer["status"],
    expiresAt: required(rows[0], "expires_at"), createdAt: required(rows[0], "created_at"),
  };
}
