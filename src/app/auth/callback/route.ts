import { NextResponse, type NextRequest } from "next/server";

import {
  getCurrentAccountState,
  getCurrentAuthUser,
} from "@/lib/auth/current-account";
import { getConfiguredAppOrigin } from "@/lib/auth/origin";
import { sanitizeInternalReturnTo } from "@/lib/auth/return-to";
import { createServerSupabaseClient } from "@/lib/supabase/server";

function privateRedirect(path: string): NextResponse {
  const response = NextResponse.redirect(new URL(path, getConfiguredAppOrigin()), 303);
  response.headers.set("Cache-Control", "private, no-store");
  return response;
}

function authError(): NextResponse {
  return privateRedirect("/auth/auth-code-error");
}

function onboardingDestination(returnTo: string): string {
  if (returnTo === "/") {
    return "/onboarding";
  }

  return `/onboarding?${new URLSearchParams({ returnTo }).toString()}`;
}

export async function GET(request: NextRequest): Promise<NextResponse> {
  const code = request.nextUrl.searchParams.get("code");
  const returnTo = sanitizeInternalReturnTo(request.nextUrl.searchParams.get("returnTo"));

  if (!code || !code.trim() || code.length > 4096) {
    return authError();
  }

  try {
    const supabase = await createServerSupabaseClient();
    const { error: exchangeError } = await supabase.auth.exchangeCodeForSession(code);
    if (exchangeError) {
      return authError();
    }

    const user = await getCurrentAuthUser(supabase);
    if (!user) {
      return authError();
    }

    const { data: foundation, error: foundationError } = await supabase.rpc(
      "ensure_current_account_foundation",
    );
    if (foundationError || !foundation || foundation.length !== 1) {
      return authError();
    }

    const state = await getCurrentAccountState(supabase);
    if (state.kind === "suspended" || state.kind === "deleted") {
      return privateRedirect("/account-unavailable");
    }
    if (state.kind !== "active") {
      return authError();
    }
    if (!state.onboardingCompleted) {
      return privateRedirect(onboardingDestination(returnTo));
    }

    return privateRedirect(returnTo);
  } catch {
    return authError();
  }
}
