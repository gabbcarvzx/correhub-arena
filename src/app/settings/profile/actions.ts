"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";

import { getCurrentAccountState } from "@/lib/auth/current-account";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { profileEditSchema } from "@/lib/validations/profile";

type ActionCode =
  | "unauthenticated"
  | "forbidden"
  | "validation_error"
  | "conflict"
  | "temporary_error";

export type UpdateProfileResult =
  | { ok: true; username: string }
  | {
      ok: false;
      code: ActionCode;
      message: string;
      fieldErrors?: Record<string, string>;
    };

function validationFailure(error: z.ZodError): UpdateProfileResult {
  const fieldErrors: Record<string, string> = {};
  for (const issue of error.issues) {
    const field = issue.path[0];
    if (typeof field === "string" && !fieldErrors[field]) fieldErrors[field] = issue.message;
  }
  return { ok: false, code: "validation_error", message: "Revise os campos indicados.", fieldErrors };
}

function databaseFailure(error: { code?: string; message?: string }): UpdateProfileResult {
  if (error.code === "23505") {
    return {
      ok: false,
      code: "conflict",
      message: "Revise os campos indicados.",
      fieldErrors: { username: "Este nome de usuário já está em uso" },
    };
  }
  if (error.code === "23514" && error.message?.includes("username is reserved")) {
    return {
      ok: false,
      code: "validation_error",
      message: "Revise os campos indicados.",
      fieldErrors: { username: "Este nome de usuário é reservado" },
    };
  }
  if (error.code === "23514" && error.message?.includes("city must be active")) {
    return {
      ok: false,
      code: "validation_error",
      message: "Revise os campos indicados.",
      fieldErrors: { city_id: "Selecione uma cidade ativa" },
    };
  }
  return {
    ok: false,
    code: "temporary_error",
    message: "Não foi possível salvar o perfil agora. Tente novamente.",
  };
}

export async function updateProfile(input: unknown): Promise<UpdateProfileResult> {
  try {
    const supabase = await createServerSupabaseClient();
    const state = await getCurrentAccountState(supabase);
    if (state.kind === "anonymous") {
      return { ok: false, code: "unauthenticated", message: "Sua sessão expirou. Entre novamente." };
    }
    if (state.kind !== "active" || !state.onboardingCompleted) {
      return {
        ok: false,
        code: state.kind === "unavailable" ? "temporary_error" : "forbidden",
        message:
          state.kind === "unavailable"
            ? "Não foi possível validar sua conta agora."
            : "Esta conta não pode editar o perfil.",
      };
    }

    const parsed = profileEditSchema.safeParse(input);
    if (!parsed.success) return validationFailure(parsed.error);

    const current = await supabase
      .from("profiles")
      .select("username")
      .eq("id", state.userId)
      .maybeSingle();
    if (current.error || !current.data?.username) {
      return { ok: false, code: "temporary_error", message: "Não foi possível carregar o perfil agora." };
    }

    const updated = await supabase
      .from("profiles")
      .update(parsed.data)
      .eq("id", state.userId)
      .select("username")
      .maybeSingle();
    if (updated.error) return databaseFailure(updated.error);
    if (!updated.data?.username) {
      return { ok: false, code: "forbidden", message: "Esta conta não pode editar o perfil." };
    }

    for (const path of [
      "/me",
      "/settings/profile",
      "/people",
      `/u/${current.data.username}`,
      `/u/${updated.data.username}`,
    ]) {
      revalidatePath(path);
    }
    return { ok: true, username: updated.data.username };
  } catch {
    return {
      ok: false,
      code: "temporary_error",
      message: "Não foi possível salvar o perfil agora. Tente novamente.",
    };
  }
}
