// @vitest-environment node

import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

const {
  createServerSupabaseClient,
  exchangeCodeForSession,
  ensureFoundation,
  getCurrentAuthUser,
  getCurrentAccountState,
} = vi.hoisted(() => ({
  createServerSupabaseClient: vi.fn(),
  exchangeCodeForSession: vi.fn(),
  ensureFoundation: vi.fn(),
  getCurrentAuthUser: vi.fn(),
  getCurrentAccountState: vi.fn(),
}));

vi.mock("@/lib/supabase/server", () => ({ createServerSupabaseClient }));
vi.mock("@/lib/auth/current-account", () => ({
  getCurrentAuthUser,
  getCurrentAccountState,
}));

import { GET } from "./route";

function request(query = "") {
  return new NextRequest(`http://untrusted.example/auth/callback${query}`);
}

describe("GET /auth/callback", () => {
  beforeEach(() => {
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "http://127.0.0.1:54321");
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "sb_publishable_callback-test");
    vi.stubEnv("NEXT_PUBLIC_SITE_URL", "http://localhost:3000");
    exchangeCodeForSession.mockReset().mockResolvedValue({ data: {}, error: null });
    ensureFoundation.mockReset().mockResolvedValue({
      data: [{ account_status: "active", onboarding_completed: false }],
      error: null,
    });
    createServerSupabaseClient.mockReset().mockResolvedValue({
      auth: { exchangeCodeForSession },
      rpc: ensureFoundation,
    });
    getCurrentAuthUser.mockReset().mockResolvedValue({ id: "user-a" });
    getCurrentAccountState.mockReset().mockResolvedValue({
      kind: "active",
      userId: "user-a",
      onboardingCompleted: false,
    });
  });

  it("rejects a missing code before creating an Auth client", async () => {
    const response = await GET(request("?returnTo=/area"));

    expect(response.headers.get("location")).toBe(
      "http://localhost:3000/auth/auth-code-error",
    );
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    expect(createServerSupabaseClient).not.toHaveBeenCalled();
  });

  it("exchanges the code, repairs the current account and sends incomplete users to onboarding", async () => {
    const response = await GET(request("?code=opaque-code&returnTo=/area?x=1"));

    expect(exchangeCodeForSession).toHaveBeenCalledWith("opaque-code");
    expect(ensureFoundation).toHaveBeenCalledWith("ensure_current_account_foundation");
    expect(getCurrentAccountState).toHaveBeenCalled();
    expect(response.headers.get("location")).toBe(
      "http://localhost:3000/onboarding?returnTo=%2Farea%3Fx%3D1",
    );
    expect(response.headers.get("location")).not.toContain("opaque-code");
  });

  it("sends a completed user to the sanitized internal destination", async () => {
    getCurrentAccountState.mockResolvedValue({
      kind: "active",
      userId: "user-a",
      onboardingCompleted: true,
    });

    const response = await GET(
      request("?code=opaque-code&returnTo=https://evil.example"),
    );

    expect(response.headers.get("location")).toBe("http://localhost:3000/");
  });

  it.each(["suspended", "deleted"])("blocks a %s account", async (kind) => {
    getCurrentAccountState.mockResolvedValue({ kind, userId: "user-a" });

    const response = await GET(request("?code=opaque-code"));

    expect(response.headers.get("location")).toBe(
      "http://localhost:3000/account-unavailable",
    );
  });

  it("contains invalid, replayed or unavailable exchanges without exposing details", async () => {
    exchangeCodeForSession.mockResolvedValue({
      data: { session: null },
      error: new Error("SQL provider token secret"),
    });

    const response = await GET(request("?code=replayed-secret-code"));
    const location = response.headers.get("location") ?? "";

    expect(location).toBe("http://localhost:3000/auth/auth-code-error");
    expect(location).not.toMatch(/replayed|secret|sql|token/i);
  });

  it("fails safely when provisioning or identity validation is unavailable", async () => {
    ensureFoundation.mockResolvedValue({ data: null, error: { code: "database_down" } });
    const provisioningFailure = await GET(request("?code=opaque-code"));
    expect(provisioningFailure.headers.get("location")).toBe(
      "http://localhost:3000/auth/auth-code-error",
    );

    ensureFoundation.mockRejectedValue(new Error("network secret"));
    const unavailable = await GET(request("?code=another-code"));
    expect(unavailable.headers.get("location")).toBe(
      "http://localhost:3000/auth/auth-code-error",
    );
  });
});
