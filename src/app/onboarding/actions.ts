"use server";

import { redirect } from "next/navigation";
import { z } from "zod";

import { getCurrentAccountState } from "@/lib/auth/current-account";
import { sanitizeInternalReturnTo } from "@/lib/auth/return-to";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { onboardingSchema } from "@/lib/validations/onboarding";

export type OnboardingActionResult =
  | { ok: true }
  | {
      ok: false;
      message: string;
      fieldErrors?: Record<string, string>;
    };

type DatabaseError = { code?: string; message?: string };

function validationFailure(error: z.ZodError): OnboardingActionResult {
  const fieldErrors: Record<string, string> = {};
  for (const issue of error.issues) {
    const field = issue.path[0];
    if (typeof field === "string" && fieldErrors[field] === undefined) {
      fieldErrors[field] = issue.message;
    }
  }

  return {
    ok: false,
    message: "Revise os campos indicados.",
    fieldErrors,
  };
}

function databaseFailure(error: DatabaseError): OnboardingActionResult {
  if (error.code === "23505") {
    return {
      ok: false,
      message: "Revise os campos indicados.",
      fieldErrors: { username: "Este nome de usuário já está em uso" },
    };
  }

  if (error.code === "23514" && error.message?.includes("username is reserved")) {
    return {
      ok: false,
      message: "Revise os campos indicados.",
      fieldErrors: { username: "Este nome de usuário é reservado" },
    };
  }

  if (error.code === "23514" && error.message?.includes("city must be active")) {
    return {
      ok: false,
      message: "Revise os campos indicados.",
      fieldErrors: { city_id: "Selecione uma cidade ativa" },
    };
  }

  return { ok: false, message: "Não foi possível concluir o cadastro. Tente novamente." };
}

export async function completeOnboarding(
  input: unknown,
  returnTo: unknown,
): Promise<OnboardingActionResult> {
  try {
    const supabase = await createServerSupabaseClient();
    const state = await getCurrentAccountState(supabase);

    if (state.kind === "anonymous") {
      return { ok: false, message: "Sua sessão expirou. Entre novamente." };
    }
    if (state.kind === "suspended" || state.kind === "deleted") {
      return { ok: false, message: "Esta conta não pode concluir o cadastro." };
    }
    if (state.kind !== "active") {
      return { ok: false, message: "Não foi possível validar sua conta agora." };
    }
    if (state.onboardingCompleted) {
      redirect(sanitizeInternalReturnTo(returnTo));
      return { ok: true };
    }

    const parsed = onboardingSchema.safeParse(input);
    if (!parsed.success) {
      return validationFailure(parsed.error);
    }

    const { data, error } = await supabase
      .from("profiles")
      .update({ ...parsed.data, onboarding_completed: true })
      .eq("id", state.userId)
      .select("id")
      .maybeSingle();

    if (error) {
      return databaseFailure(error);
    }
    if (!data) {
      return { ok: false, message: "Esta conta não pode concluir o cadastro." };
    }

    redirect(sanitizeInternalReturnTo(returnTo));
    return { ok: true };
  } catch (error) {
    if (error && typeof error === "object" && "digest" in error) {
      throw error;
    }
    return { ok: false, message: "Não foi possível concluir o cadastro. Tente novamente." };
  }
}
