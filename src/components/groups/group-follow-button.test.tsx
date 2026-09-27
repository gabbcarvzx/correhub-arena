import { fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const { followGroup, unfollowGroup, refresh } = vi.hoisted(() => ({ followGroup: vi.fn(), unfollowGroup: vi.fn(), refresh: vi.fn() }));
vi.mock("@/lib/groups/actions", () => ({ followGroup, unfollowGroup }));
vi.mock("next/navigation", () => ({ useRouter: () => ({ refresh }) }));

import { GroupFollowButton } from "./group-follow-button";

describe("GroupFollowButton", () => {
  beforeEach(() => { followGroup.mockReset(); unfollowGroup.mockReset(); refresh.mockReset(); });

  it("follows independently and never promises member access", async () => {
    followGroup.mockResolvedValue({ ok: true, following: true });
    render(<GroupFollowButton groupId="51000000-0000-4000-8000-000000000001" initialFollowing={false} slug="corre-recife" />);
    expect(screen.getByText("Acompanhe as novidades públicas. Seguir não torna você membro.")).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: "Seguir grupo" }));
    expect(await screen.findByRole("button", { name: "Seguindo grupo" })).toBeVisible();
  });

  it("unfollows without changing membership", async () => {
    unfollowGroup.mockResolvedValue({ ok: true, following: false });
    render(<GroupFollowButton groupId="51000000-0000-4000-8000-000000000001" initialFollowing slug="corre-recife" />);
    fireEvent.click(screen.getByRole("button", { name: "Seguindo grupo" }));
    expect(await screen.findByRole("button", { name: "Seguir grupo" })).toBeVisible();
    expect(screen.getByText(/não altera sua participação/i)).toBeVisible();
  });
});
