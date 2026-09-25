import type { JwtPayload, User } from "@supabase/supabase-js";
import type { SupabaseClient } from "@supabase/supabase-js";

import { createServerSupabaseClient } from "@/lib/supabase/server";
import type { Database } from "@/types/database";

type AppSupabaseClient = SupabaseClient<Database>;

export type ClaimsState =
  | { status: "authenticated"; claims: JwtPayload & { sub: string } }
  | { status: "anonymous" }
  | { status: "unavailable" };

export type CurrentAccountState =
  | { kind: "anonymous" }
  | { kind: "active"; userId: string; onboardingCompleted: boolean }
  | { kind: "suspended"; userId: string }
  | { kind: "deleted"; userId: string }
  | { kind: "unavailable" };

const ANONYMOUS_AUTH_CODES = new Set([
  "bad_jwt",
  "invalid_jwt",
  "refresh_token_not_found",
  "session_not_found",
  "user_not_found",
]);

function isAuthenticationFailure(error: unknown): boolean {
  if (!error || typeof error !== "object") {
    return false;
  }

  const candidate = error as { code?: unknown; status?: unknown };
  return (
    (typeof candidate.code === "string" && ANONYMOUS_AUTH_CODES.has(candidate.code)) ||
    candidate.status === 401 ||
    candidate.status === 403
  );
}

async function resolveClient(client?: AppSupabaseClient): Promise<AppSupabaseClient> {
  return client ?? createServerSupabaseClient();
}

export async function requireClaims(client?: AppSupabaseClient): Promise<ClaimsState> {
  try {
    const supabase = await resolveClient(client);
    const { data, error } = await supabase.auth.getClaims();

    if (error) {
      return isAuthenticationFailure(error) ? { status: "anonymous" } : { status: "unavailable" };
    }

    if (!data?.claims || typeof data.claims.sub !== "string" || !data.claims.sub) {
      return { status: "anonymous" };
    }

    return {
      status: "authenticated",
      claims: data.claims as JwtPayload & { sub: string },
    };
  } catch {
    return { status: "unavailable" };
  }
}

export async function getCurrentAuthUser(client?: AppSupabaseClient): Promise<User | null> {
  try {
    const supabase = await resolveClient(client);
    const { data, error } = await supabase.auth.getUser();
    return error ? null : data.user;
  } catch {
    return null;
  }
}

export async function getCurrentAccountState(
  client?: AppSupabaseClient,
): Promise<CurrentAccountState> {
  let supabase: AppSupabaseClient;
  try {
    supabase = await resolveClient(client);
  } catch {
    return { kind: "unavailable" };
  }
  const claims = await requireClaims(supabase);

  if (claims.status === "anonymous") {
    return { kind: "anonymous" };
  }

  if (claims.status === "unavailable") {
    return { kind: "unavailable" };
  }

  try {
    const { data, error } = await supabase.rpc("get_current_account_state");
    if (error || !data || data.length !== 1) {
      return { kind: "unavailable" };
    }

    const [state] = data;
    if (state.account_status === "active" && typeof state.onboarding_completed === "boolean") {
      return {
        kind: "active",
        userId: claims.claims.sub,
        onboardingCompleted: state.onboarding_completed,
      };
    }

    if (state.account_status === "suspended" || state.account_status === "deleted") {
      return { kind: state.account_status, userId: claims.claims.sub };
    }

    return { kind: "unavailable" };
  } catch {
    return { kind: "unavailable" };
  }
}
