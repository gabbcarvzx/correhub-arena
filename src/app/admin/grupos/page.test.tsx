import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  createServerSupabaseClient: vi.fn(), getCurrentAccountState: vi.fn(), canReviewGroups: vi.fn(),
  listGroupReviewQueue: vi.fn(), getGroupReview: vi.fn(), redirect: vi.fn(), notFound: vi.fn(),
}));
vi.mock("@/lib/supabase/server", () => ({ createServerSupabaseClient: mocks.createServerSupabaseClient }));
vi.mock("@/lib/auth/current-account", () => ({ getCurrentAccountState: mocks.getCurrentAccountState }));
vi.mock("@/lib/groups/queries", () => ({ canReviewGroups: mocks.canReviewGroups, listGroupReviewQueue: mocks.listGroupReviewQueue, getGroupReview: mocks.getGroupReview }));
vi.mock("@/lib/groups/actions", () => ({ approveGroup: vi.fn(), rejectGroup: vi.fn() }));
vi.mock("next/navigation", () => ({ redirect: mocks.redirect, notFound: mocks.notFound, useRouter: () => ({ refresh: vi.fn() }) }));

import GroupReviewQueuePage from "./page";
import GroupReviewPage from "./[id]/page";

const reviewer = "31000000-0000-4000-8000-000000000001";
const group = { id: "51000000-0000-4000-8000-000000000001", slug: "corre-recife", name: "Corre Recife", description: "Treinos em comunidade.", city: { id: "10000000-0000-4000-8000-000000000001", name: "Recife" }, type: "community" as const, joinPolicy: "open" as const, status: "pending" as const, ownerUserId: reviewer, createdBy: reviewer, avatarUrl: null, coverUrl: null, createdAt: "2026-09-27T10:00:00Z", updatedAt: "2026-09-27T10:00:00Z", rejectionReason: null };

describe("admin group routes", () => {
  beforeEach(() => {
    vi.clearAllMocks(); mocks.createServerSupabaseClient.mockResolvedValue({});
    mocks.getCurrentAccountState.mockResolvedValue({ kind: "active", userId: "different-admin", onboardingCompleted: true });
    mocks.canReviewGroups.mockResolvedValue(true); mocks.listGroupReviewQueue.mockResolvedValue({ items: [group], nextCursor: null }); mocks.getGroupReview.mockResolvedValue(group);
    mocks.redirect.mockImplementation((destination: string) => { throw new Error(`redirect:${destination}`); });
    mocks.notFound.mockImplementation(() => { throw new Error("not_found"); });
  });

  it("renders the queue only after server and database authorization", async () => {
    render(await GroupReviewQueuePage());
    expect(screen.getByRole("heading", { name: /solicitações de grupos/i })).toBeInTheDocument();
    expect(mocks.canReviewGroups).toHaveBeenCalled();
  });

  it.each([
    [{ kind: "anonymous" }, /redirect:\/login/],
    [{ kind: "unavailable" }, /redirect:\/account-unavailable/],
  ])("fails closed for expired or unavailable sessions", async (state, expected) => {
    mocks.getCurrentAccountState.mockResolvedValue(state);
    await expect(GroupReviewQueuePage()).rejects.toThrow(expected);
    expect(mocks.listGroupReviewQueue).not.toHaveBeenCalled();
  });

  it("returns a safe not-found boundary to a runner or moderator", async () => {
    mocks.canReviewGroups.mockResolvedValue(false);
    await expect(GroupReviewQueuePage()).rejects.toThrow("not_found");
    expect(mocks.listGroupReviewQueue).not.toHaveBeenCalled();
  });

  it("does not render decisions for a platform admin reviewing their own request", async () => {
    mocks.getCurrentAccountState.mockResolvedValue({ kind: "active", userId: reviewer, onboardingCompleted: true });
    render(await GroupReviewPage({ params: Promise.resolve({ id: group.id }) }));
    expect(screen.getByText(/outra pessoa administradora/i)).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /aprovar grupo/i })).not.toBeInTheDocument();
  });
});
