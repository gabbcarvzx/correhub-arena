"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";

import { getCurrentAccountState } from "@/lib/auth/current-account";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { profileUsernameSchema } from "@/lib/validations/profile";

export type SocialActionResult =
  | { ok: true; following: boolean }
  | {
      ok: false;
      code: "unauthenticated" | "forbidden" | "not_found" | "validation_error" | "temporary_error";
      message: string;
    };

const inputSchema = z.object({ targetUserId: z.uuid(), username: profileUsernameSchema }).strict();

async function mutationContext(targetUserId: unknown, username: unknown) {
  const parsed = inputSchema.safeParse({ targetUserId, username });
  if (!parsed.success) {
    return { error: { ok: false, code: "validation_error", message: "Perfil inválido." } as SocialActionResult };
  }
  const supabase = await createServerSupabaseClient();
  const state = await getCurrentAccountState(supabase);
  if (state.kind === "anonymous") {
    return { error: { ok: false, code: "unauthenticated", message: "Entre para seguir corredores." } as SocialActionResult };
  }
  if (state.kind !== "active" || !state.onboardingCompleted || state.userId === parsed.data.targetUserId) {
    return { error: { ok: false, code: "forbidden", message: "Esta ação não está disponível." } as SocialActionResult };
  }
  return { supabase, state, input: parsed.data };
}

function revalidateSocial(username: string) {
  for (const path of ["/me", "/people", `/u/${username}`, `/u/${username}/followers`, `/u/${username}/following`]) {
    revalidatePath(path);
  }
}

export async function followProfile(targetUserId: unknown, username: unknown): Promise<SocialActionResult> {
  try {
    const context = await mutationContext(targetUserId, username);
    if (context.error) return context.error;
    const { error } = await context.supabase.from("user_follows").insert({
      follower_id: context.state.userId,
      followed_id: context.input.targetUserId,
    });
    if (error?.code === "23505") return { ok: true, following: true };
    if (error?.code === "42501" || error?.code === "23514") {
      return { ok: false, code: "not_found", message: "Perfil indisponível." };
    }
    if (error) {
      return { ok: false, code: "temporary_error", message: "Não foi possível seguir agora." };
    }
    revalidateSocial(context.input.username);
    return { ok: true, following: true };
  } catch {
    return { ok: false, code: "temporary_error", message: "Não foi possível seguir agora." };
  }
}

export async function unfollowProfile(targetUserId: unknown, username: unknown): Promise<SocialActionResult> {
  try {
    const context = await mutationContext(targetUserId, username);
    if (context.error) return context.error;
    const { error } = await context.supabase
      .from("user_follows")
      .delete()
      .eq("follower_id", context.state.userId)
      .eq("followed_id", context.input.targetUserId)
      .select("followed_id");
    if (error?.code === "42501") {
      return { ok: false, code: "forbidden", message: "Esta ação não está disponível." };
    }
    if (error) {
      return { ok: false, code: "temporary_error", message: "Não foi possível deixar de seguir agora." };
    }
    revalidateSocial(context.input.username);
    return { ok: true, following: false };
  } catch {
    return { ok: false, code: "temporary_error", message: "Não foi possível deixar de seguir agora." };
  }
}
