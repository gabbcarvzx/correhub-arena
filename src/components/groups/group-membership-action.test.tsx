import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const { joinGroup, leaveGroup, refresh } = vi.hoisted(() => ({
  joinGroup: vi.fn(), leaveGroup: vi.fn(), refresh: vi.fn(),
}));
vi.mock("@/lib/groups/actions", () => ({ joinGroup, leaveGroup }));
vi.mock("next/navigation", () => ({ useRouter: () => ({ refresh }) }));

import { GroupMembershipAction } from "./group-membership-action";

const group = { groupId: "51000000-0000-4000-8000-000000000001", slug: "corre-recife" };

describe("GroupMembershipAction", () => {
  beforeEach(() => { joinGroup.mockReset(); leaveGroup.mockReset(); refresh.mockReset(); });

  it("shows the join policy outcome and persists an open join", async () => {
    joinGroup.mockResolvedValue({ ok: true });
    render(<GroupMembershipAction {...group} joinPolicy="open" relation={null} />);
    fireEvent.click(screen.getByRole("button", { name: "Entrar no grupo" }));
    expect(await screen.findByText("Você entrou no grupo.")).toBeVisible();
    expect(joinGroup).toHaveBeenCalledWith({ groupId: group.groupId }, group.slug);
    expect(refresh).toHaveBeenCalled();
  });

  it("explains pending and blocked states without offering another join", () => {
    const { rerender } = render(<GroupMembershipAction {...group} joinPolicy="approval_required" relation={{ role: "member", status: "pending", joinedAt: null }} />);
    expect(screen.getByText("Pedido em análise")).toBeVisible();
    expect(screen.queryByRole("button", { name: /entrar/i })).not.toBeInTheDocument();
    rerender(<GroupMembershipAction {...group} joinPolicy="open" relation={{ role: "member", status: "blocked", joinedAt: null }} />);
    expect(screen.getByText("Entrada indisponível")).toBeVisible();
  });

  it("leaves an active membership and reports a concurrent state change", async () => {
    leaveGroup.mockResolvedValue({ ok: false, code: "state_changed", message: "O estado mudou. Atualize a página e tente novamente." });
    render(<GroupMembershipAction {...group} joinPolicy="open" relation={{ role: "member", status: "active", joinedAt: "2026-09-27" }} />);
    fireEvent.click(screen.getByRole("button", { name: "Sair do grupo" }));
    await waitFor(() => expect(screen.getByRole("alert")).toHaveTextContent("O estado mudou"));
  });
});
