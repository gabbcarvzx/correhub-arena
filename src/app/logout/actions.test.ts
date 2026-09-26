import { beforeEach, describe, expect, it, vi } from "vitest";

const { createServerSupabaseClient, redirect, revalidatePath, signOut } = vi.hoisted(() => ({
  createServerSupabaseClient: vi.fn(),
  redirect: vi.fn(),
  revalidatePath: vi.fn(),
  signOut: vi.fn(),
}));

vi.mock("@/lib/supabase/server", () => ({ createServerSupabaseClient }));
vi.mock("next/navigation", () => ({ redirect }));
vi.mock("next/cache", () => ({ revalidatePath }));

import { logoutAction } from "./actions";

describe("logoutAction", () => {
  beforeEach(() => {
    signOut.mockReset().mockResolvedValue({ error: null });
    createServerSupabaseClient.mockReset().mockResolvedValue({ auth: { signOut } });
    redirect.mockReset();
    revalidatePath.mockReset();
  });

  it("ends only the local Supabase session and redirects safely", async () => {
    await logoutAction();

    expect(signOut).toHaveBeenCalledOnce();
    expect(signOut).toHaveBeenCalledWith({ scope: "local" });
    expect(revalidatePath).toHaveBeenCalledWith("/", "layout");
    expect(redirect).toHaveBeenCalledWith("/");
  });

  it("is safe to repeat when no server session remains", async () => {
    signOut.mockResolvedValue({ error: { code: "session_not_found" } });

    await expect(logoutAction()).resolves.toBeUndefined();
    expect(redirect).toHaveBeenCalledWith("/");
  });
});
