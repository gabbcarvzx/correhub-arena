import { fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const actions = vi.hoisted(() => ({ initiateOwnerTransfer: vi.fn(), cancelOwnerTransfer: vi.fn(), acceptOwnerTransfer: vi.fn(), refresh: vi.fn() }));
vi.mock("@/lib/groups/actions", () => actions);
vi.mock("next/navigation", () => ({ useRouter: () => ({ refresh: actions.refresh }) }));

import type { GroupMemberPresentation, GroupOwnerTransfer } from "@/lib/groups/types";
import { OwnerTransferPanel } from "./owner-transfer-panel";

const candidate: GroupMemberPresentation = { userId: "31000000-0000-4000-8000-000000000002", username: "destino", fullName: "Destino", avatarUrl: null, visibility: "public", role: "member", status: "active", joinedAt: "2026-09-27" };
const transfer: GroupOwnerTransfer = { transferId: "61000000-0000-4000-8000-000000000001", groupId: "51000000-0000-4000-8000-000000000001", fromUserId: "31000000-0000-4000-8000-000000000001", toUserId: candidate.userId, status: "pending", expiresAt: "2026-10-04T12:00:00Z", createdAt: "2026-09-27T12:00:00Z" };

describe("OwnerTransferPanel", () => {
  beforeEach(() => Object.values(actions).forEach(fn => fn.mockReset?.().mockResolvedValue?.({ ok: true })));

  it("explains the seven-day explicit acceptance before owner initiates", async () => {
    render(<OwnerTransferPanel candidates={[candidate]} currentUserId="31000000-0000-4000-8000-000000000001" groupId={transfer.groupId} transfer={null} />);
    expect(screen.getByText(/7 dias/i)).toBeVisible();
    fireEvent.change(screen.getByLabelText("Nova pessoa responsável"), { target: { value: candidate.userId } });
    fireEvent.click(screen.getByRole("button", { name: "Iniciar transferência" }));
    expect(await screen.findByRole("alertdialog", { name: "Transferir responsabilidade?" })).toBeVisible();
  });

  it("requires recipient acceptance and presents expiration", () => {
    render(<OwnerTransferPanel candidates={[]} currentUserId={candidate.userId} groupId={transfer.groupId} transfer={transfer} />);
    expect(screen.getByText(/aceite explícito/i)).toBeVisible();
    expect(screen.getByRole("button", { name: "Aceitar responsabilidade" })).toBeVisible();
  });

  it("does not offer acceptance for an expired transfer", () => {
    render(<OwnerTransferPanel candidates={[]} currentUserId={candidate.userId} groupId={transfer.groupId} transfer={{ ...transfer, status: "expired" }} />);
    expect(screen.getByText("Transferência expirada")).toBeVisible();
    expect(screen.queryByRole("button", { name: "Aceitar responsabilidade" })).not.toBeInTheDocument();
  });
});
