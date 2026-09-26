import { beforeEach, describe, expect, it, vi } from "vitest";

const createBrowserClient = vi.fn();

vi.mock("@supabase/ssr", () => ({ createBrowserClient }));

describe("createBrowserSupabaseClient", () => {
  beforeEach(() => {
    vi.resetModules();
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "http://127.0.0.1:54321");
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "sb_publishable_browser-test");
    vi.stubEnv("NEXT_PUBLIC_SITE_URL", "http://localhost:3000");
    createBrowserClient.mockReset();
    createBrowserClient.mockReturnValue({ kind: "browser-client" });
  });

  it("creates one browser client and reuses it", async () => {
    const { createBrowserSupabaseClient } = await import("./client");

    const first = createBrowserSupabaseClient();
    const second = createBrowserSupabaseClient();

    expect(first).toBe(second);
    expect(createBrowserClient).toHaveBeenCalledOnce();
    expect(createBrowserClient).toHaveBeenCalledWith(
      "http://127.0.0.1:54321",
      "sb_publishable_browser-test",
    );
  });
});
