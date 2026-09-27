import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const { followProfile, refresh, unfollowProfile } = vi.hoisted(() => ({
  followProfile: vi.fn(),
  unfollowProfile: vi.fn(),
  refresh: vi.fn(),
}));
vi.mock("@/lib/social/actions", () => ({ followProfile, unfollowProfile }));
vi.mock("next/navigation", () => ({ useRouter: () => ({ refresh }) }));

import { FollowButton } from "./follow-button";

describe("FollowButton", () => {
  beforeEach(() => {
    followProfile.mockReset().mockResolvedValue({ ok: true, following: true });
    unfollowProfile.mockReset().mockResolvedValue({ ok: true, following: false });
    refresh.mockReset();
  });

  it("changes state only after the server confirms follow", async () => {
    let resolveAction: ((value: unknown) => void) | undefined;
    followProfile.mockReturnValue(new Promise((resolve) => (resolveAction = resolve)));
    render(<FollowButton initialFollowing={false} targetUserId="31000000-0000-4000-8000-000000000002" username="runner_two" />);
    const button = screen.getByRole("button", { name: "Seguir" });
    fireEvent.click(button);
    await waitFor(() => expect(button).toBeDisabled());
    expect(screen.getByRole("button", { name: "Seguindo…" })).toBeInTheDocument();
    resolveAction?.({ ok: true, following: true });
    expect(await screen.findByRole("button", { name: "Seguindo" })).toBeInTheDocument();
    expect(refresh).toHaveBeenCalledOnce();
  });

  it("shows a safe error and preserves state on failure", async () => {
    followProfile.mockResolvedValue({ ok: false, code: "not_found", message: "Perfil indisponível." });
    render(<FollowButton initialFollowing={false} targetUserId="31000000-0000-4000-8000-000000000002" username="runner_two" />);
    fireEvent.click(screen.getByRole("button", { name: "Seguir" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("Perfil indisponível.");
    expect(screen.getByRole("button", { name: "Seguir" })).toBeInTheDocument();
  });

  it("unfollows after confirmation", async () => {
    render(<FollowButton initialFollowing targetUserId="31000000-0000-4000-8000-000000000002" username="runner_two" />);
    fireEvent.click(screen.getByRole("button", { name: "Seguindo" }));
    expect(await screen.findByRole("button", { name: "Seguir" })).toBeInTheDocument();
    expect(unfollowProfile).toHaveBeenCalledOnce();
  });
});
