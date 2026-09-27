"use server";

import { revalidatePath } from "next/cache";

import { getCurrentAccountState } from "@/lib/auth/current-account";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import {
  groupActionSchema,
  groupFollowActionSchema,
  groupMemberActionSchema,
  groupReasonSchema,
  groupRequestSchema,
  groupTransferActionSchema,
} from "@/lib/validations/group";

export type GroupActionErrorCode = "unauthenticated" | "forbidden" | "not_found" | "validation_error" | "conflict" | "state_changed" | "temporary_error";
export type GroupActionFailure = { ok: false; code: GroupActionErrorCode; message: string };
export type GroupActionResult<T = undefined> = { ok: true; data?: T } | GroupActionFailure;

function failure(code: GroupActionErrorCode, message: string): GroupActionFailure { return { ok: false, code, message }; }
async function context() {
  const supabase = await createServerSupabaseClient();
  const state = await getCurrentAccountState(supabase);
  if (state.kind === "anonymous") return { error: failure("unauthenticated", "Entre para continuar.") };
  if (state.kind !== "active" || !state.onboardingCompleted) return { error: failure("forbidden", "Esta ação não está disponível.") };
  return { supabase, state };
}
function mapError(error: { code?: string; message?: string } | null, fallback: string): GroupActionFailure | null {
  if (!error) return null;
  if (error.code === "P0001") return failure("state_changed", "O estado mudou. Atualize a página e tente novamente.");
  if (error.code === "23505") return failure("conflict", "Este valor já está em uso.");
  if (error.code === "P0002") return failure("not_found", "Grupo indisponível.");
  if (error.code === "42501" || error.code === "23514" || error.code === "22023") return failure("forbidden", "Esta ação não está disponível.");
  return failure("temporary_error", fallback);
}
function refresh(slug?: string) {
  ["/grupos/meus", "/admin/grupos", slug ? `/grupos/${slug}` : null].filter(Boolean).forEach((path) => revalidatePath(path!));
}

export async function requestGroup(input: unknown): Promise<
  | { ok: true; groupId: string; slug: string }
  | GroupActionFailure
> {
  const parsed = groupRequestSchema.safeParse(input);
  if (!parsed.success) return failure("validation_error", "Revise os dados do grupo.");
  const ctx = await context(); if (ctx.error) return ctx.error;
  const { data, error } = await ctx.supabase.rpc("request_group", { requested_name: parsed.data.name, requested_slug: parsed.data.slug, requested_description: parsed.data.description, requested_city_id: parsed.data.city_id, requested_type: parsed.data.group_type, requested_join_policy: parsed.data.join_policy });
  const mapped = mapError(error, "Não foi possível enviar a solicitação agora."); if (mapped) return mapped;
  refresh(parsed.data.slug);
  return { ok: true, groupId: data as string, slug: parsed.data.slug };
}

async function rpcAction(name: string, input: unknown, args: (data: { groupId: string }) => Record<string, unknown>, slug?: string): Promise<GroupActionResult> {
  const parsed = groupActionSchema.safeParse(input); if (!parsed.success) return failure("validation_error", "Grupo inválido.");
  const ctx = await context(); if (ctx.error) return ctx.error;
  const { error } = await ctx.supabase.rpc(name as never, args(parsed.data) as never);
  const mapped = mapError(error, "Não foi possível concluir a ação agora."); if (mapped) return mapped;
  refresh(slug); return { ok: true };
}
export const approveGroup = (input: unknown) => rpcAction("approve_group_request", input, ({ groupId }) => ({ target_group_id: groupId }));
export async function rejectGroup(input: unknown, reason: unknown) {
  const parsedReason = groupReasonSchema.safeParse(reason); if (!parsedReason.success) return failure("validation_error", "Informe um motivo válido.");
  return rpcAction("reject_group_request", input, ({ groupId }) => ({ target_group_id: groupId, reason: parsedReason.data }));
}
export const resubmitGroup = (input: unknown) => rpcAction("resubmit_group", input, ({ groupId }) => ({ target_group_id: groupId }));
export const joinGroup = (input: unknown, slug?: string) => rpcAction("join_group", input, ({ groupId }) => ({ target_group_id: groupId }), slug);
export const leaveGroup = (input: unknown, slug?: string) => rpcAction("leave_group", input, ({ groupId }) => ({ target_group_id: groupId }), slug);

async function memberAction(name: string, input: unknown, slug?: string): Promise<GroupActionResult> {
  const parsed = groupMemberActionSchema.safeParse(input); if (!parsed.success) return failure("validation_error", "Membro inválido.");
  const ctx = await context(); if (ctx.error) return ctx.error;
  const { error } = await ctx.supabase.rpc(name as never, { target_group_id: parsed.data.groupId, target_user_id: parsed.data.userId } as never);
  const mapped = mapError(error, "Não foi possível atualizar o membro agora."); if (mapped) return mapped;
  refresh(slug); return { ok: true };
}
export const approveGroupMember = (input: unknown, slug?: string) => memberAction("approve_group_member", input, slug);
export const rejectGroupMember = (input: unknown, slug?: string) => memberAction("reject_group_member_request", input, slug);
export const blockGroupMember = (input: unknown, slug?: string) => memberAction("block_group_member", input, slug);
export const promoteGroupAdmin = (input: unknown, slug?: string) => memberAction("promote_group_admin", input, slug);
export const demoteGroupAdmin = (input: unknown, slug?: string) => memberAction("demote_group_admin", input, slug);

export async function followGroup(input: unknown): Promise<GroupActionResult & { following?: boolean }> {
  const parsed = groupFollowActionSchema.safeParse(input); if (!parsed.success) return failure("validation_error", "Grupo inválido.");
  const ctx = await context(); if (ctx.error) return ctx.error;
  const { error } = await ctx.supabase.from("group_follows").insert({ user_id: ctx.state.userId, group_id: parsed.data.groupId });
  if (error?.code === "23505") return { ok: true, following: true };
  const mapped = mapError(error, "Não foi possível seguir o grupo agora."); if (mapped) return mapped;
  refresh(parsed.data.slug); return { ok: true, following: true };
}
export async function unfollowGroup(input: unknown): Promise<GroupActionResult & { following?: boolean }> {
  const parsed = groupFollowActionSchema.safeParse(input); if (!parsed.success) return failure("validation_error", "Grupo inválido.");
  const ctx = await context(); if (ctx.error) return ctx.error;
  const { error } = await ctx.supabase.from("group_follows").delete().eq("user_id", ctx.state.userId).eq("group_id", parsed.data.groupId);
  const mapped = mapError(error, "Não foi possível deixar de seguir agora."); if (mapped) return mapped;
  refresh(parsed.data.slug); return { ok: true, following: false };
}

export async function acceptOwnerTransfer(input: unknown) {
  const parsed = groupTransferActionSchema.safeParse(input); if (!parsed.success) return failure("validation_error", "Transferência inválida.");
  const ctx = await context(); if (ctx.error) return ctx.error;
  const { error } = await ctx.supabase.rpc("accept_group_owner_transfer", { target_transfer_id: parsed.data.transferId });
  const mapped = mapError(error, "Não foi possível aceitar a transferência agora."); if (mapped) return mapped;
  refresh(); return { ok: true } as GroupActionResult;
}
