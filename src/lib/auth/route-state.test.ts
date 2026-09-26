import { describe, expect, it } from "vitest";

import { resolveAuthRouteState } from "./route-state";

describe("resolveAuthRouteState", () => {
  it("sends anonymous protected requests to login with a safe return", () => {
    expect(resolveAuthRouteState({ kind: "anonymous" }, "protected", "/area?x=1")).toEqual({
      action: "redirect",
      destination: "/login?returnTo=%2Farea%3Fx%3D1",
    });
    expect(resolveAuthRouteState({ kind: "anonymous" }, "protected", "https://evil.example")).toEqual({
      action: "redirect",
      destination: "/login",
    });
  });

  it("allows public, login and logout routes for visitors", () => {
    expect(resolveAuthRouteState({ kind: "anonymous" }, "public")).toEqual({ action: "allow" });
    expect(resolveAuthRouteState({ kind: "anonymous" }, "login")).toEqual({ action: "allow" });
    expect(resolveAuthRouteState({ kind: "anonymous" }, "logout")).toEqual({ action: "allow" });
  });

  it("routes an active incomplete account only to onboarding", () => {
    const state = { kind: "active", userId: "user-a", onboardingCompleted: false } as const;

    expect(resolveAuthRouteState(state, "onboarding", "/area")).toEqual({ action: "allow" });
    expect(resolveAuthRouteState(state, "login", "/area")).toEqual({
      action: "redirect",
      destination: "/onboarding?returnTo=%2Farea",
    });
    expect(resolveAuthRouteState(state, "protected", "/area")).toEqual({
      action: "redirect",
      destination: "/onboarding?returnTo=%2Farea",
    });
  });

  it("keeps a complete account out of login and onboarding", () => {
    const state = { kind: "active", userId: "user-a", onboardingCompleted: true } as const;

    expect(resolveAuthRouteState(state, "login", "/area")).toEqual({
      action: "redirect",
      destination: "/area",
    });
    expect(resolveAuthRouteState(state, "onboarding", "/onboarding")).toEqual({
      action: "redirect",
      destination: "/",
    });
    expect(resolveAuthRouteState(state, "protected", "/area")).toEqual({ action: "allow" });
  });

  it.each(["suspended", "deleted"] as const)("blocks %s accounts predictably", (kind) => {
    const state = { kind, userId: "user-a" } as const;

    expect(resolveAuthRouteState(state, "onboarding")).toEqual({
      action: "redirect",
      destination: "/account-unavailable",
    });
    expect(resolveAuthRouteState(state, "account-unavailable")).toEqual({ action: "allow" });
    expect(resolveAuthRouteState(state, "logout")).toEqual({ action: "allow" });
  });

  it("fails closed without creating redirect loops when account state is unavailable", () => {
    expect(resolveAuthRouteState({ kind: "unavailable" }, "account-unavailable")).toEqual({
      action: "allow",
    });
    expect(resolveAuthRouteState({ kind: "unavailable" }, "protected", "/area")).toEqual({
      action: "redirect",
      destination: "/account-unavailable",
    });
  });
});
