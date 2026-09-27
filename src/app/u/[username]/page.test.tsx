import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const { getCurrentAccountState, getProfileByUsername, notFound } = vi.hoisted(() => ({
  getCurrentAccountState: vi.fn(),
  getProfileByUsername: vi.fn(),
  notFound: vi.fn(() => {
    throw new Error("NEXT_NOT_FOUND");
  }),
}));

vi.mock("@/lib/auth/current-account", () => ({ getCurrentAccountState }));
vi.mock("@/lib/profiles/queries", () => ({ getProfileByUsername }));
vi.mock("next/navigation", () => ({ notFound }));

import ProfilePage, { generateMetadata } from "./page";

const publicProfile = {
  id: "31000000-0000-4000-8000-000000000001",
  username: "runner_one",
  fullName: "Runner One",
  avatarUrl: null,
  bio: "Bio pública",
  city: null,
  runningLevel: "beginner",
  preferredDistance: "up_to_5k",
  paceSecondsPerKm: 390,
  visibility: "public",
  createdAt: "2026-09-26T00:00:00.000Z",
};

describe("public profile page", () => {
  beforeEach(() => {
    getCurrentAccountState.mockReset().mockResolvedValue({ kind: "anonymous" });
    getProfileByUsername.mockReset().mockResolvedValue(publicProfile);
    notFound.mockClear();
  });

  it("normalizes the username and renders a public profile", async () => {
    render(await ProfilePage({ params: Promise.resolve({ username: "RUNNER_ONE" }) }));
    expect(getProfileByUsername).toHaveBeenCalledWith("runner_one");
    expect(screen.getByRole("heading", { name: "Runner One" })).toBeInTheDocument();
  });

  it("returns not found for an invalid, unavailable or incomplete profile", async () => {
    getProfileByUsername.mockResolvedValue(null);
    await expect(
      ProfilePage({ params: Promise.resolve({ username: "missing" }) }),
    ).rejects.toThrow("NEXT_NOT_FOUND");
  });

  it("uses safe private metadata without hidden fields", async () => {
    getProfileByUsername.mockResolvedValue({
      ...publicProfile,
      bio: null,
      city: null,
      runningLevel: null,
      preferredDistance: null,
      paceSecondsPerKm: null,
      visibility: "private",
    });
    const metadata = await generateMetadata({
      params: Promise.resolve({ username: "runner_one" }),
    });

    expect(metadata).toMatchObject({
      title: "Runner One (@runner_one) | CorreHub",
      description: "Perfil privado no CorreHub.",
      robots: { index: false, follow: false },
    });
    expect(JSON.stringify(metadata)).not.toContain("Bio pública");
  });
});
