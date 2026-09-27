import { beforeEach, describe, expect, it, vi } from "vitest";

const { createServerSupabaseClient, getCurrentAccountState } = vi.hoisted(() => ({
  createServerSupabaseClient: vi.fn(),
  getCurrentAccountState: vi.fn(),
}));

vi.mock("server-only", () => ({}));
vi.mock("@/lib/supabase/server", () => ({ createServerSupabaseClient }));
vi.mock("@/lib/auth/current-account", () => ({ getCurrentAccountState }));

import { encodeProfileCursor } from "./cursor";
import {
  ProfileQueryError,
  discoverProfiles,
  getOwnProfile,
  getProfileByUsername,
  listProfileConnections,
} from "./queries";

const row = {
  id: "31000000-0000-4000-8000-000000000001",
  username: "runner_one",
  full_name: "Runner One",
  avatar_url: "https://images.example/runner.png",
  bio: "Treino cedo.",
  city_id: "10000000-0000-4000-8000-000000000001",
  city_name: "São Lourenço da Mata",
  city_slug: "sao-lourenco-da-mata",
  country_code: "BR",
  state_code: "PE",
  running_level: "beginner",
  preferred_distance: "up_to_5k",
  pace_seconds_per_km: 390,
  visibility: "public",
  created_at: "2026-09-26T00:00:00.000Z",
};

describe("profile queries", () => {
  const rpc = vi.fn();

  beforeEach(() => {
    rpc.mockReset();
    createServerSupabaseClient.mockReset().mockResolvedValue({ rpc });
    getCurrentAccountState.mockReset();
  });

  it("maps the safe public profile contract", async () => {
    rpc.mockResolvedValue({ data: [row], error: null });

    await expect(getProfileByUsername(" RUNNER_ONE ")).resolves.toEqual({
      id: row.id,
      username: "runner_one",
      fullName: "Runner One",
      avatarUrl: row.avatar_url,
      bio: row.bio,
      city: {
        id: row.city_id,
        name: row.city_name,
        slug: row.city_slug,
        countryCode: "BR",
        stateCode: "PE",
      },
      runningLevel: "beginner",
      preferredDistance: "up_to_5k",
      paceSecondsPerKm: 390,
      visibility: "public",
      createdAt: row.created_at,
    });
    expect(rpc).toHaveBeenCalledWith("get_profile_by_username", {
      target_username: "runner_one",
    });
  });

  it("never manufactures hidden fields for a private projection", async () => {
    rpc.mockResolvedValue({
      data: [
        {
          ...row,
          avatar_url: null,
          bio: null,
          city_id: null,
          city_name: null,
          city_slug: null,
          country_code: null,
          state_code: null,
          running_level: null,
          preferred_distance: null,
          pace_seconds_per_km: null,
          visibility: "private",
        },
      ],
      error: null,
    });

    const profile = await getProfileByUsername("runner_one");
    expect(profile).toMatchObject({
      avatarUrl: null,
      bio: null,
      city: null,
      runningLevel: null,
      preferredDistance: null,
      paceSecondsPerKm: null,
      visibility: "private",
    });
  });

  it("maps database failures to a stable error without SQL details", async () => {
    rpc.mockResolvedValue({ data: null, error: { message: "secret SQL", code: "XX000" } });

    await expect(getProfileByUsername("runner_one")).rejects.toMatchObject({
      code: "temporary_error",
      message: "Não foi possível carregar os perfis agora.",
    });
  });

  it("fetches 21 discovery rows and returns a cursor after 20", async () => {
    const rows = Array.from({ length: 21 }, (_, index) => ({
      ...row,
      id: `31000000-0000-4000-8000-${String(index + 1).padStart(12, "0")}`,
      username: `runner_${String(index + 1).padStart(2, "0")}`,
    }));
    rpc.mockResolvedValue({ data: rows, error: null });

    const result = await discoverProfiles({ query: "  runner ", cityId: row.city_id });
    expect(result.items).toHaveLength(20);
    expect(result.nextCursor).toBe(
      encodeProfileCursor({ username: "runner_20", id: rows[19].id }),
    );
    expect(rpc).toHaveBeenCalledWith("discover_profiles", {
      search_query: "runner",
      filter_city_id: row.city_id,
      after_username: undefined,
      after_id: undefined,
      page_size: 21,
    });
  });

  it("passes a validated compound cursor and rejects manipulated cursors", async () => {
    rpc.mockResolvedValue({ data: [], error: null });
    const cursor = encodeProfileCursor({ username: row.username, id: row.id });

    await discoverProfiles({ cursor });
    expect(rpc).toHaveBeenLastCalledWith("discover_profiles", expect.objectContaining({
      after_username: row.username,
      after_id: row.id,
    }));

    await expect(discoverProfiles({ cursor: "//evil" })).rejects.toBeInstanceOf(
      ProfileQueryError,
    );
  });

  it("reads the own username under RLS and resolves the self projection", async () => {
    const maybeSingle = vi.fn().mockResolvedValue({ data: { username: row.username }, error: null });
    const eq = vi.fn(() => ({ maybeSingle }));
    const select = vi.fn(() => ({ eq }));
    const from = vi.fn(() => ({ select }));
    const client = { from, rpc };
    createServerSupabaseClient.mockResolvedValue(client);
    getCurrentAccountState.mockResolvedValue({
      kind: "active",
      userId: row.id,
      onboardingCompleted: true,
    });
    rpc.mockResolvedValue({ data: [{ ...row, visibility: "self" }], error: null });

    await expect(getOwnProfile()).resolves.toMatchObject({ visibility: "self" });
    expect(from).toHaveBeenCalledWith("profiles");
    expect(eq).toHaveBeenCalledWith("id", row.id);
  });

  it("uses the authenticated connection RPC and sanitizes private rows", async () => {
    rpc.mockResolvedValue({
      data: [{ ...row, visibility: "private", avatar_url: null, bio: null, city_id: null }],
      error: null,
    });

    const result = await listProfileConnections({
      username: "runner_one",
      direction: "followers",
    });
    expect(result.items[0]).toMatchObject({ visibility: "private", bio: null, city: null });
    expect(rpc).toHaveBeenCalledWith("list_profile_connections", {
      target_username: "runner_one",
      connection_direction: "followers",
      after_username: undefined,
      after_id: undefined,
      page_size: 20,
    });
  });
});
