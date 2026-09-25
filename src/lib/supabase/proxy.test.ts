// @vitest-environment node

import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

const createServerClient = vi.fn();

vi.mock("@supabase/ssr", () => ({ createServerClient }));

describe("updateSession", () => {
  beforeEach(() => {
    vi.resetModules();
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "http://127.0.0.1:54321");
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "sb_publishable_proxy-test");
    vi.stubEnv("NEXT_PUBLIC_SITE_URL", "http://localhost:3000");
    createServerClient.mockReset();
  });

  it("calls getClaims and mirrors refreshed cookies to request and response", async () => {
    const getClaims = vi.fn();
    createServerClient.mockImplementation((_url, _key, options) => {
      getClaims.mockImplementation(async () => {
        options.cookies.setAll([
          {
            name: "sb-local-auth-token",
            value: "refreshed",
            options: { httpOnly: true, sameSite: "lax", path: "/" },
          },
        ]);
        return { data: { claims: { sub: "user-a" } }, error: null };
      });
      return { auth: { getClaims } };
    });

    const request = new NextRequest("http://localhost:3000/onboarding", {
      headers: { cookie: "sb-local-auth-token=stale", "x-correlation-id": "request-a" },
    });
    const { updateSession } = await import("./proxy");
    const response = await updateSession(request);

    expect(getClaims).toHaveBeenCalledOnce();
    expect(request.cookies.get("sb-local-auth-token")?.value).toBe("refreshed");
    expect(response.cookies.get("sb-local-auth-token")?.value).toBe("refreshed");
    expect(response.headers.get("cache-control")).toBe("private, no-store");
  });

  it("contains an invalid refresh without logging its error", async () => {
    const consoleError = vi.spyOn(console, "error").mockImplementation(() => undefined);
    createServerClient.mockReturnValue({
      auth: {
        getClaims: vi.fn().mockRejectedValue(new Error("refresh-token-secret")),
      },
    });
    const request = new NextRequest("http://localhost:3000/onboarding", {
      headers: { cookie: "sb-local-auth-token=invalid" },
    });
    const { updateSession } = await import("./proxy");

    await expect(updateSession(request)).resolves.toBeDefined();
    expect(consoleError).not.toHaveBeenCalled();
    consoleError.mockRestore();
  });

  it("uses isolated response state for consecutive anonymous requests", async () => {
    createServerClient.mockReturnValue({
      auth: { getClaims: vi.fn().mockResolvedValue({ data: { claims: null }, error: null }) },
    });
    const { updateSession } = await import("./proxy");

    const first = await updateSession(new NextRequest("http://localhost:3000/"));
    first.headers.set("x-test-identity", "first-user");
    const second = await updateSession(new NextRequest("http://localhost:3000/"));

    expect(second).not.toBe(first);
    expect(second.headers.get("x-test-identity")).toBeNull();
    expect(second.headers.get("cache-control")).toBeNull();
  });
});
