import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const { getCurrentAccountState, getOwnProfile, redirect } = vi.hoisted(() => ({
  getCurrentAccountState: vi.fn(),
  getOwnProfile: vi.fn(),
  redirect: vi.fn(() => {
    throw new Error("NEXT_REDIRECT");
  }),
}));

vi.mock("@/lib/auth/current-account", () => ({ getCurrentAccountState }));
vi.mock("@/lib/profiles/queries", () => ({ getOwnProfile }));
vi.mock("next/navigation", () => ({ redirect }));

import MyProfilePage from "./page";

describe("MyProfilePage", () => {
  beforeEach(() => {
    getCurrentAccountState.mockReset().mockResolvedValue({
      kind: "active",
      userId: "31000000-0000-4000-8000-000000000001",
      onboardingCompleted: true,
    });
    getOwnProfile.mockReset().mockResolvedValue({
      id: "31000000-0000-4000-8000-000000000001",
      username: "runner_one",
      fullName: "Runner One",
      avatarUrl: null,
      bio: null,
      city: null,
      runningLevel: null,
      preferredDistance: null,
      paceSecondsPerKm: null,
      visibility: "self",
      createdAt: "2026-09-26T00:00:00.000Z",
    });
    redirect.mockClear();
  });

  it("renders the complete own-profile surface", async () => {
    render(await MyProfilePage());
    expect(screen.getByRole("heading", { name: "Runner One" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Editar perfil" })).toBeInTheDocument();
  });

  it("redirects an incomplete account to onboarding", async () => {
    getCurrentAccountState.mockResolvedValue({
      kind: "active",
      userId: "31000000-0000-4000-8000-000000000001",
      onboardingCompleted: false,
    });
    await expect(MyProfilePage()).rejects.toThrow("NEXT_REDIRECT");
    expect(redirect).toHaveBeenCalledWith("/onboarding?returnTo=%2Fme");
  });
});
