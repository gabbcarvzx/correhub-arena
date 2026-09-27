import { beforeEach, describe, expect, it, vi } from "vitest";

const { createServerSupabaseClient, getCurrentAccountState, revalidatePath } = vi.hoisted(() => ({
  createServerSupabaseClient: vi.fn(),
  getCurrentAccountState: vi.fn(),
  revalidatePath: vi.fn(),
}));
vi.mock("@/lib/supabase/server", () => ({ createServerSupabaseClient }));
vi.mock("@/lib/auth/current-account", () => ({ getCurrentAccountState }));
vi.mock("next/cache", () => ({ revalidatePath }));

import { followProfile, unfollowProfile } from "./actions";

const actor = "31000000-0000-4000-8000-000000000001";
const target = "31000000-0000-4000-8000-000000000002";

describe("social actions", () => {
  const insert = vi.fn();
  const deleteSelect = vi.fn();
  const deleteEqTarget = vi.fn(() => ({ select: deleteSelect }));
  const deleteEqActor = vi.fn(() => ({ eq: deleteEqTarget }));
  const remove = vi.fn(() => ({ eq: deleteEqActor }));
  const from = vi.fn(() => ({ insert, delete: remove }));

  beforeEach(() => {
    insert.mockReset().mockResolvedValue({ error: null });
    deleteSelect.mockReset().mockResolvedValue({ data: [{ followed_id: target }], error: null });
    [deleteEqTarget, deleteEqActor, remove, from, revalidatePath].forEach((mock) => mock.mockClear());
    createServerSupabaseClient.mockReset().mockResolvedValue({ from });
    getCurrentAccountState.mockReset().mockResolvedValue({ kind: "active", userId: actor, onboardingCompleted: true });
  });

  it("derives the follower from the session and inserts only the pair", async () => {
    await expect(followProfile(target, "runner_two")).resolves.toEqual({ ok: true, following: true });
    expect(insert).toHaveBeenCalledWith({ follower_id: actor, followed_id: target });
  });

  it("treats duplicate follow and missing unfollow as idempotent end states", async () => {
    insert.mockResolvedValue({ error: { code: "23505", message: "duplicate SQL" } });
    await expect(followProfile(target, "runner_two")).resolves.toEqual({ ok: true, following: true });
    deleteSelect.mockResolvedValue({ data: [], error: null });
    await expect(unfollowProfile(target, "runner_two")).resolves.toEqual({ ok: true, following: false });
  });

  it("rejects invalid, self and unavailable actors without a mutation", async () => {
    await expect(followProfile("bad", "runner_two")).resolves.toMatchObject({ ok: false, code: "validation_error" });
    await expect(followProfile(actor, "runner_one")).resolves.toMatchObject({ ok: false, code: "forbidden" });
    getCurrentAccountState.mockResolvedValue({ kind: "suspended", userId: actor });
    await expect(followProfile(target, "runner_two")).resolves.toMatchObject({ ok: false, code: "forbidden" });
    expect(insert).not.toHaveBeenCalled();
  });

  it("maps RLS denial without leaking SQL", async () => {
    insert.mockResolvedValue({ error: { code: "42501", message: "new row violates row-level security policy" } });
    const result = await followProfile(target, "runner_two");
    expect(result).toMatchObject({ ok: false, code: "not_found" });
    expect(JSON.stringify(result)).not.toMatch(/row-level|42501/i);
  });
});
