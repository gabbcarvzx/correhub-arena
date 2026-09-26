import { beforeEach, describe, expect, it, vi } from "vitest";

const cookieGetAll = vi.fn();
const cookieSet = vi.fn();
const cookies = vi.fn();
const createServerClient = vi.fn();

vi.mock("next/headers", () => ({ cookies }));
vi.mock("@supabase/ssr", () => ({ createServerClient }));

describe("createServerSupabaseClient", () => {
  beforeEach(() => {
    vi.resetModules();
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "http://127.0.0.1:54321");
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "sb_publishable_server-test");
    vi.stubEnv("NEXT_PUBLIC_SITE_URL", "http://localhost:3000");
    cookieGetAll.mockReset().mockReturnValue([{ name: "session", value: "one" }]);
    cookieSet.mockReset();
    cookies.mockReset().mockResolvedValue({ getAll: cookieGetAll, set: cookieSet });
    createServerClient.mockReset().mockImplementation(() => ({ kind: "server-client" }));
  });

  it("creates a new server client per call with the request cookie adapter", async () => {
    const { createServerSupabaseClient } = await import("./server");

    const first = await createServerSupabaseClient();
    const second = await createServerSupabaseClient();

    expect(first).not.toBe(second);
    expect(createServerClient).toHaveBeenCalledTimes(2);

    const options = createServerClient.mock.calls[0][2];
    expect(options.cookies.getAll()).toEqual([{ name: "session", value: "one" }]);
    options.cookies.setAll([
      { name: "session", value: "two", options: { httpOnly: true, sameSite: "lax" } },
    ]);
    expect(cookieSet).toHaveBeenCalledWith("session", "two", {
      httpOnly: true,
      sameSite: "lax",
    });
  });
});
