import { describe, expect, it, vi } from "vitest";

import {
  getCurrentAccountState,
  getCurrentAuthUser,
  requireClaims,
} from "./current-account";

function clientWith({
  claims = { data: { claims: { sub: "user-a" } }, error: null },
  rpc = { data: [{ account_status: "active", onboarding_completed: false }], error: null },
  user = { data: { user: { id: "user-a", user_metadata: { full_name: "Runner" } } }, error: null },
}: { claims?: unknown; rpc?: unknown; user?: unknown } = {}) {
  return {
    auth: {
      getClaims: vi.fn().mockResolvedValue(claims),
      getUser: vi.fn().mockResolvedValue(user),
    },
    rpc: vi.fn().mockResolvedValue(rpc),
  };
}

describe("requireClaims", () => {
  it("returns validated claims without using getSession", async () => {
    const client = clientWith();

    await expect(requireClaims(client as never)).resolves.toEqual({
      status: "authenticated",
      claims: { sub: "user-a" },
    });
    expect("getSession" in client.auth).toBe(false);
  });

  it("treats missing and expired sessions as anonymous", async () => {
    const missing = clientWith({ claims: { data: { claims: null }, error: null } });
    const expired = clientWith({
      claims: { data: { claims: null }, error: { code: "bad_jwt", status: 401 } },
    });

    await expect(requireClaims(missing as never)).resolves.toEqual({ status: "anonymous" });
    await expect(requireClaims(expired as never)).resolves.toEqual({ status: "anonymous" });
  });

  it("distinguishes temporary Auth unavailability", async () => {
    const client = clientWith({
      claims: { data: { claims: null }, error: { code: "network_error", status: 503 } },
    });

    await expect(requireClaims(client as never)).resolves.toEqual({ status: "unavailable" });
  });
});

describe("getCurrentAccountState", () => {
  it.each([
    ["active", false, { kind: "active", userId: "user-a", onboardingCompleted: false }],
    ["active", true, { kind: "active", userId: "user-a", onboardingCompleted: true }],
    ["suspended", false, { kind: "suspended", userId: "user-a" }],
    ["deleted", false, { kind: "deleted", userId: "user-a" }],
  ])("maps %s/%s account state", async (accountStatus, onboardingCompleted, expected) => {
    const client = clientWith({
      rpc: { data: [{ account_status: accountStatus, onboarding_completed: onboardingCompleted }], error: null },
    });

    await expect(getCurrentAccountState(client as never)).resolves.toEqual(expected);
    expect(client.rpc).toHaveBeenCalledWith("get_current_account_state");
  });

  it("fails closed for missing rows, duplicate rows and database errors", async () => {
    const missing = clientWith({ rpc: { data: [], error: null } });
    const duplicate = clientWith({
      rpc: {
        data: [
          { account_status: "active", onboarding_completed: false },
          { account_status: "active", onboarding_completed: false },
        ],
        error: null,
      },
    });
    const failed = clientWith({ rpc: { data: null, error: { code: "database_unavailable" } } });

    await expect(getCurrentAccountState(missing as never)).resolves.toEqual({ kind: "unavailable" });
    await expect(getCurrentAccountState(duplicate as never)).resolves.toEqual({ kind: "unavailable" });
    await expect(getCurrentAccountState(failed as never)).resolves.toEqual({ kind: "unavailable" });
  });

  it("does not call account RPC for anonymous or unavailable claims", async () => {
    const anonymous = clientWith({ claims: { data: { claims: null }, error: null } });
    const unavailable = clientWith({
      claims: { data: { claims: null }, error: { code: "network_error", status: 503 } },
    });

    await expect(getCurrentAccountState(anonymous as never)).resolves.toEqual({ kind: "anonymous" });
    await expect(getCurrentAccountState(unavailable as never)).resolves.toEqual({ kind: "unavailable" });
    expect(anonymous.rpc).not.toHaveBeenCalled();
    expect(unavailable.rpc).not.toHaveBeenCalled();
  });
});

describe("getCurrentAuthUser", () => {
  it("uses getUser for fresh provider metadata", async () => {
    const client = clientWith();

    await expect(getCurrentAuthUser(client as never)).resolves.toMatchObject({ id: "user-a" });
    expect(client.auth.getUser).toHaveBeenCalledOnce();
  });

  it("returns null when Auth cannot validate the user", async () => {
    const client = clientWith({ user: { data: { user: null }, error: { code: "bad_jwt" } } });
    await expect(getCurrentAuthUser(client as never)).resolves.toBeNull();
  });
});
