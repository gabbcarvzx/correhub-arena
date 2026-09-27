import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const { createServerSupabaseClient, getCurrentAccountState, getOwnProfile, redirect } = vi.hoisted(
  () => ({
    createServerSupabaseClient: vi.fn(),
    getCurrentAccountState: vi.fn(),
    getOwnProfile: vi.fn(),
    redirect: vi.fn(() => {
      throw new Error("NEXT_REDIRECT");
    }),
  }),
);
vi.mock("@/lib/supabase/server", () => ({ createServerSupabaseClient }));
vi.mock("@/lib/auth/current-account", () => ({ getCurrentAccountState }));
vi.mock("@/lib/profiles/queries", () => ({ getOwnProfile }));
vi.mock("next/navigation", () => ({ redirect }));

import SettingsProfilePage from "./page";

describe("SettingsProfilePage", () => {
  beforeEach(() => {
    const order = vi.fn().mockResolvedValue({
      data: [{ id: "10000000-0000-4000-8000-000000000001", name: "Recife", state_code: "PE" }],
      error: null,
    });
    const cityEq = vi.fn(() => ({ order }));
    const profileMaybeSingle = vi.fn().mockResolvedValue({ data: { is_private: true }, error: null });
    const profileEq = vi.fn(() => ({ maybeSingle: profileMaybeSingle }));
    createServerSupabaseClient.mockReset().mockResolvedValue({
      from: vi.fn((table: string) => ({
        select: vi.fn(() => ({ eq: table === "cities" ? cityEq : profileEq })),
      })),
    });
    getCurrentAccountState.mockReset().mockResolvedValue({ kind: "active", userId: "a", onboardingCompleted: true });
    getOwnProfile.mockReset().mockResolvedValue({
      id: "a",
      username: "runner_one",
      fullName: "Runner One",
      avatarUrl: null,
      bio: null,
      city: { id: "10000000-0000-4000-8000-000000000001", name: "Recife", slug: "recife", countryCode: "BR", stateCode: "PE" },
      runningLevel: "beginner",
      preferredDistance: "up_to_5k",
      paceSecondsPerKm: 390,
      visibility: "self",
      createdAt: "2026-09-26T00:00:00.000Z",
    });
  });

  it("loads active cities and current profile values", async () => {
    render(await SettingsProfilePage());
    expect(screen.getByRole("heading", { name: "Editar perfil" })).toBeInTheDocument();
    expect(screen.getByLabelText("Cidade")).toHaveValue("10000000-0000-4000-8000-000000000001");
    expect(screen.getByLabelText("Perfil privado")).toBeChecked();
  });
});
