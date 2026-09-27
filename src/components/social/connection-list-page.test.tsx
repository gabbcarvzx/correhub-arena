import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const { getCurrentAccountState, getProfileByUsername, listProfileConnections, notFound, redirect } = vi.hoisted(() => ({
  getCurrentAccountState: vi.fn(),
  getProfileByUsername: vi.fn(),
  listProfileConnections: vi.fn(),
  notFound: vi.fn(() => { throw new Error("NEXT_NOT_FOUND"); }),
  redirect: vi.fn(() => { throw new Error("NEXT_REDIRECT"); }),
}));
vi.mock("@/lib/auth/current-account", () => ({ getCurrentAccountState }));
vi.mock("@/lib/profiles/queries", () => ({ getProfileByUsername, listProfileConnections }));
vi.mock("next/navigation", () => ({ notFound, redirect }));

import { ConnectionListPage } from "./connection-list-page";

const target = {
  id: "31000000-0000-4000-8000-000000000001",
  username: "runner_one",
  fullName: "Runner One",
  avatarUrl: null,
  bio: null,
  city: null,
  runningLevel: null,
  preferredDistance: null,
  paceSecondsPerKm: null,
  visibility: "public",
  createdAt: "2026-09-26T00:00:00.000Z",
};

describe("ConnectionListPage", () => {
  beforeEach(() => {
    getCurrentAccountState.mockReset().mockResolvedValue({ kind: "active", userId: "viewer", onboardingCompleted: true });
    getProfileByUsername.mockReset().mockResolvedValue(target);
    listProfileConnections.mockReset().mockResolvedValue({ items: [], nextCursor: null });
  });

  it("redirects visitors with the exact internal return path", async () => {
    getCurrentAccountState.mockResolvedValue({ kind: "anonymous" });
    await expect(ConnectionListPage({ username: "runner_one", direction: "followers", cursor: undefined })).rejects.toThrow("NEXT_REDIRECT");
    expect(redirect).toHaveBeenCalledWith("/login?returnTo=%2Fu%2Frunner_one%2Ffollowers");
  });

  it("renders an authorized public list without counts", async () => {
    render(await ConnectionListPage({ username: "runner_one", direction: "followers", cursor: undefined }));
    expect(screen.getByRole("heading", { name: "Seguidores de Runner One" })).toBeInTheDocument();
    expect(screen.queryByText(/\d+ seguidor/i)).not.toBeInTheDocument();
  });

  it("hides a private target graph from a third party, including followers", async () => {
    getProfileByUsername.mockResolvedValue({ ...target, visibility: "private" });
    await expect(ConnectionListPage({ username: "runner_one", direction: "following", cursor: undefined })).rejects.toThrow("NEXT_NOT_FOUND");
    expect(listProfileConnections).not.toHaveBeenCalled();
  });

  it("allows an owner to see a sanitized private graph", async () => {
    getProfileByUsername.mockResolvedValue({ ...target, visibility: "self" });
    render(await ConnectionListPage({ username: "runner_one", direction: "following", cursor: undefined }));
    expect(listProfileConnections).toHaveBeenCalledWith({ username: "runner_one", direction: "following", cursor: undefined });
  });
});
