import { beforeEach, describe, expect, it, vi } from "vitest";

const { createServerSupabaseClient, getCurrentAccountState, redirect, maybeSingle } = vi.hoisted(
  () => ({
    createServerSupabaseClient: vi.fn(),
    getCurrentAccountState: vi.fn(),
    redirect: vi.fn(),
    maybeSingle: vi.fn(),
  }),
);

vi.mock("@/lib/supabase/server", () => ({ createServerSupabaseClient }));
vi.mock("@/lib/auth/current-account", () => ({ getCurrentAccountState }));
vi.mock("next/navigation", () => ({ redirect }));

import { completeOnboarding } from "./actions";

const valid = {
  username: "runner_one",
  full_name: "Runner One",
  city_id: "10000000-0000-4000-8000-000000000001",
  running_level: "beginner" as const,
  preferred_distance: "up_to_5k" as const,
  bio: "",
  pace: "6:30",
  is_private: false,
};

describe("completeOnboarding", () => {
  const select = vi.fn(() => ({ maybeSingle }));
  const eq = vi.fn(() => ({ select }));
  const update = vi.fn(() => ({ eq }));
  const from = vi.fn(() => ({ update }));

  beforeEach(() => {
    maybeSingle.mockReset().mockResolvedValue({ data: { id: "user-a" }, error: null });
    select.mockClear();
    eq.mockClear();
    update.mockClear();
    from.mockClear();
    createServerSupabaseClient.mockReset().mockResolvedValue({ from });
    getCurrentAccountState.mockReset().mockResolvedValue({
      kind: "active",
      userId: "user-a",
      onboardingCompleted: false,
    });
    redirect.mockReset();
  });

  it("updates only the current profile and completes onboarding atomically", async () => {
    await expect(completeOnboarding(valid, "/area")).resolves.toEqual({ ok: true });

    expect(from).toHaveBeenCalledWith("profiles");
    expect(update).toHaveBeenCalledWith({
      username: "runner_one",
      full_name: "Runner One",
      city_id: valid.city_id,
      running_level: "beginner",
      preferred_distance: "up_to_5k",
      bio: null,
      pace_seconds_per_km: 390,
      is_private: false,
      onboarding_completed: true,
    });
    expect(eq).toHaveBeenCalledWith("id", "user-a");
    expect(redirect).toHaveBeenCalledWith("/area");
  });

  it.each([
    [{ kind: "anonymous" }, "Sua sessão expirou. Entre novamente."],
    [{ kind: "suspended", userId: "user-a" }, "Esta conta não pode concluir o cadastro."],
    [{ kind: "deleted", userId: "user-a" }, "Esta conta não pode concluir o cadastro."],
    [{ kind: "unavailable" }, "Não foi possível validar sua conta agora."],
  ])("fails closed for account state %#", async (state, message) => {
    getCurrentAccountState.mockResolvedValue(state);

    await expect(completeOnboarding(valid, "/area")).resolves.toEqual({
      ok: false,
      message,
    });
    expect(update).not.toHaveBeenCalled();
  });

  it("validates identity before parsing an untrusted payload", async () => {
    getCurrentAccountState.mockResolvedValue({ kind: "anonymous" });

    await expect(completeOnboarding({ username: "x" }, "/area")).resolves.toEqual({
      ok: false,
      message: "Sua sessão expirou. Entre novamente.",
    });
    expect(update).not.toHaveBeenCalled();
  });

  it("maps username concurrency without exposing SQL", async () => {
    maybeSingle.mockResolvedValue({
      data: null,
      error: { code: "23505", message: "duplicate key value violates profiles_username_key" },
    });

    const result = await completeOnboarding(valid, "/area");
    expect(result).toEqual({
      ok: false,
      message: "Revise os campos indicados.",
      fieldErrors: { username: "Este nome de usuário já está em uso" },
    });
    expect(JSON.stringify(result)).not.toMatch(/duplicate|profiles_username_key|23505/i);
  });

  it("maps reserved usernames and inactive cities to their fields", async () => {
    maybeSingle.mockResolvedValueOnce({
      data: null,
      error: { code: "23514", message: "username is reserved" },
    });
    await expect(completeOnboarding(valid, "/area")).resolves.toMatchObject({
      fieldErrors: { username: "Este nome de usuário é reservado" },
    });

    maybeSingle.mockResolvedValueOnce({
      data: null,
      error: { code: "23514", message: "city must be active" },
    });
    await expect(completeOnboarding(valid, "/area")).resolves.toMatchObject({
      fieldErrors: { city_id: "Selecione uma cidade ativa" },
    });
  });
});
