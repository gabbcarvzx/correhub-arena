import { beforeEach, describe, expect, it, vi } from "vitest";

const { createServerSupabaseClient, getCurrentAccountState, revalidatePath } = vi.hoisted(() => ({
  createServerSupabaseClient: vi.fn(),
  getCurrentAccountState: vi.fn(),
  revalidatePath: vi.fn(),
}));

vi.mock("@/lib/supabase/server", () => ({ createServerSupabaseClient }));
vi.mock("@/lib/auth/current-account", () => ({ getCurrentAccountState }));
vi.mock("next/cache", () => ({ revalidatePath }));

import { updateProfile } from "./actions";

const valid = {
  username: "runner_new",
  full_name: "Runner New",
  city_id: "10000000-0000-4000-8000-000000000001",
  running_level: "beginner",
  preferred_distance: "up_to_5k",
  bio: "",
  pace: "6:30",
  is_private: true,
};

describe("updateProfile", () => {
  const oldMaybeSingle = vi.fn();
  const updatedMaybeSingle = vi.fn();
  const updateSelect = vi.fn(() => ({ maybeSingle: updatedMaybeSingle }));
  const updateEq = vi.fn(() => ({ select: updateSelect }));
  const update = vi.fn(() => ({ eq: updateEq }));
  const oldEq = vi.fn(() => ({ maybeSingle: oldMaybeSingle }));
  const select = vi.fn(() => ({ eq: oldEq }));
  const from = vi.fn(() => ({ select, update }));

  beforeEach(() => {
    oldMaybeSingle.mockReset().mockResolvedValue({ data: { username: "runner_old" }, error: null });
    updatedMaybeSingle.mockReset().mockResolvedValue({ data: { username: "runner_new" }, error: null });
    [updateSelect, updateEq, update, oldEq, select, from, revalidatePath].forEach((mock) =>
      mock.mockClear(),
    );
    createServerSupabaseClient.mockReset().mockResolvedValue({ from });
    getCurrentAccountState.mockReset().mockResolvedValue({
      kind: "active",
      userId: "31000000-0000-4000-8000-000000000001",
      onboardingCompleted: true,
    });
  });

  it("performs one update on the current user's allowed fields", async () => {
    await expect(updateProfile(valid)).resolves.toEqual({ ok: true, username: "runner_new" });
    expect(update).toHaveBeenCalledOnce();
    expect(update).toHaveBeenCalledWith({
      username: "runner_new",
      full_name: "Runner New",
      city_id: valid.city_id,
      running_level: "beginner",
      preferred_distance: "up_to_5k",
      bio: null,
      pace_seconds_per_km: 390,
      is_private: true,
    });
    expect(updateEq).toHaveBeenCalledWith("id", "31000000-0000-4000-8000-000000000001");
    expect(revalidatePath).toHaveBeenCalledWith("/u/runner_old");
    expect(revalidatePath).toHaveBeenCalledWith("/u/runner_new");
  });

  it.each([
    [{ kind: "anonymous" }, "unauthenticated"],
    [{ kind: "active", userId: "a", onboardingCompleted: false }, "forbidden"],
    [{ kind: "suspended", userId: "a" }, "forbidden"],
    [{ kind: "unavailable" }, "temporary_error"],
  ])("fails closed for account state %#", async (state, code) => {
    getCurrentAccountState.mockResolvedValue(state);
    await expect(updateProfile(valid)).resolves.toMatchObject({ ok: false, code });
    expect(update).not.toHaveBeenCalled();
  });

  it("rejects actor and authorization fields instead of forwarding them", async () => {
    await expect(
      updateProfile({ ...valid, id: "user-b", role: "platform_admin", account_status: "active" }),
    ).resolves.toMatchObject({ ok: false, code: "validation_error" });
    expect(update).not.toHaveBeenCalled();
  });

  it("maps duplicate and reserved usernames without SQL details", async () => {
    updatedMaybeSingle.mockResolvedValueOnce({ data: null, error: { code: "23505", message: "SQL" } });
    await expect(updateProfile(valid)).resolves.toMatchObject({
      ok: false,
      code: "conflict",
      fieldErrors: { username: expect.stringMatching(/uso/) },
    });
    updatedMaybeSingle.mockResolvedValueOnce({
      data: null,
      error: { code: "23514", message: "username is reserved" },
    });
    const reserved = await updateProfile(valid);
    expect(reserved).toMatchObject({ fieldErrors: { username: expect.stringMatching(/reservado/) } });
    expect(JSON.stringify(reserved)).not.toContain("23514");
  });
});
