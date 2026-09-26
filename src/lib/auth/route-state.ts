import { sanitizeInternalReturnTo } from "./return-to";
import type { CurrentAccountState } from "./current-account";

export type AuthRoute =
  | "public"
  | "login"
  | "callback"
  | "onboarding"
  | "logout"
  | "account-unavailable"
  | "protected";

export type AuthRouteDecision =
  | { action: "allow" }
  | { action: "redirect"; destination: string };

function withSafeReturn(path: "/login" | "/onboarding", returnTo?: unknown): string {
  const safeReturn = sanitizeInternalReturnTo(returnTo);
  if (safeReturn === "/") {
    return path;
  }

  const params = new URLSearchParams({ returnTo: safeReturn });
  return `${path}?${params.toString()}`;
}

export function resolveAuthRouteState(
  state: CurrentAccountState,
  route: AuthRoute,
  returnTo?: unknown,
): AuthRouteDecision {
  if (state.kind === "anonymous") {
    if (route === "protected") {
      return { action: "redirect", destination: withSafeReturn("/login", returnTo) };
    }
    if (route === "onboarding" || route === "account-unavailable") {
      return { action: "redirect", destination: "/login" };
    }
    return { action: "allow" };
  }

  if (state.kind === "unavailable") {
    if (route === "protected" || route === "onboarding") {
      return { action: "redirect", destination: "/account-unavailable" };
    }
    return { action: "allow" };
  }

  if (state.kind === "suspended" || state.kind === "deleted") {
    if (
      route === "public" ||
      route === "callback" ||
      route === "logout" ||
      route === "account-unavailable"
    ) {
      return { action: "allow" };
    }
    return { action: "redirect", destination: "/account-unavailable" };
  }

  if (!state.onboardingCompleted) {
    if (route === "onboarding" || route === "public" || route === "callback" || route === "logout") {
      return { action: "allow" };
    }
    return { action: "redirect", destination: withSafeReturn("/onboarding", returnTo) };
  }

  if (route === "login" || route === "onboarding" || route === "account-unavailable") {
    return { action: "redirect", destination: sanitizeInternalReturnTo(returnTo) };
  }

  return { action: "allow" };
}
