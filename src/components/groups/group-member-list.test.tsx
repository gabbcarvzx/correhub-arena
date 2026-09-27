import { fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const actions = vi.hoisted(() => ({
  approveGroupMember: vi.fn(), rejectGroupMember: vi.fn(), blockGroupMember: vi.fn(),
  promoteGroupAdmin: vi.fn(), demoteGroupAdmin: vi.fn(), refresh: vi.fn(),
}));
vi.mock("@/lib/groups/actions", () => actions);
vi.mock("next/navigation", () => ({ useRouter: () => ({ refresh: actions.refresh }) }));

import type { GroupMemberPresentation } from "@/lib/groups/types";
import { GroupMemberList } from "./group-member-list";

const member: GroupMemberPresentation = { userId: "31000000-0000-4000-8000-000000000001", username: "corredora", fullName: "Corredora Privada", avatarUrl: null, visibility: "private", role: "member", status: "active", joinedAt: "2026-09-27" };

describe("GroupMemberList", () => {
  beforeEach(() => Object.values(actions).forEach(fn => fn.mockReset?.().mockResolvedValue?.({ ok: true })));

  it("shows only minimal identity for a private member", () => {
    render(<GroupMemberList groupId="51000000-0000-4000-8000-000000000001" members={[member]} slug="corre-recife" status="active" viewerRole="member" />);
    expect(screen.getByText("Corredora Privada")).toBeVisible();
    expect(screen.getByText("Perfil privado")).toBeVisible();
    expect(screen.queryByRole("button")).not.toBeInTheDocument();
  });

  it("lets an admin manage only common pending members", () => {
    render(<GroupMemberList groupId="51000000-0000-4000-8000-000000000001" members={[{ ...member, status: "pending" }]} slug="corre-recife" status="pending" viewerRole="admin" />);
    expect(screen.getByRole("button", { name: "Aprovar Corredora Privada" })).toBeVisible();
    expect(screen.getByRole("button", { name: "Rejeitar Corredora Privada" })).toBeVisible();
    expect(screen.queryByRole("button", { name: /promover/i })).not.toBeInTheDocument();
  });

  it("gives owner role controls through a confirmation dialog", async () => {
    render(<GroupMemberList groupId="51000000-0000-4000-8000-000000000001" members={[member]} slug="corre-recife" status="active" viewerRole="owner" />);
    fireEvent.click(screen.getByRole("button", { name: "Promover Corredora Privada" }));
    expect(await screen.findByRole("alertdialog", { name: "Tornar esta pessoa gestora?" })).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: "Confirmar promoção" }));
    expect(actions.promoteGroupAdmin).toHaveBeenCalledWith({ groupId: expect.any(String), userId: member.userId }, "corre-recife");
  });
});
