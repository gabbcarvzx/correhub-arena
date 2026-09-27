import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const { approveGroup, rejectGroup, refresh } = vi.hoisted(() => ({
  approveGroup: vi.fn(), rejectGroup: vi.fn(), refresh: vi.fn(),
}));
vi.mock("@/lib/groups/actions", () => ({ approveGroup, rejectGroup }));
vi.mock("next/navigation", () => ({ useRouter: () => ({ refresh }) }));

import { GroupReviewDecision, GroupReviewQueue } from "./group-review";

const review = {
  id: "51000000-0000-4000-8000-000000000001", slug: "corre-recife", name: "Corre Recife",
  description: "Treinos em comunidade.", city: { id: "10000000-0000-4000-8000-000000000001", name: "Recife" },
  type: "community" as const, joinPolicy: "open" as const, status: "pending" as const,
  ownerUserId: "31000000-0000-4000-8000-000000000001", createdBy: "31000000-0000-4000-8000-000000000001",
  avatarUrl: null, coverUrl: null, createdAt: "2026-09-27T10:00:00.000Z", updatedAt: "2026-09-27T10:00:00.000Z",
};

describe("group review workspace", () => {
  beforeEach(() => { approveGroup.mockReset(); rejectGroup.mockReset(); refresh.mockReset(); });

  it("shows a compact queue without private requester data", () => {
    render(<GroupReviewQueue items={[review]} />);
    expect(screen.getByRole("link", { name: /revisar corre recife/i })).toHaveAttribute("href", `/admin/grupos/${review.id}`);
    expect(screen.getByText(/Recife · Comunidade/)).toBeInTheDocument();
    expect(screen.queryByText(/email|bio|pace/i)).not.toBeInTheDocument();
  });

  it("renders a useful empty queue", () => {
    render(<GroupReviewQueue items={[]} />);
    expect(screen.getByText(/nenhuma solicitação aguardando análise/i)).toBeInTheDocument();
  });

  it("prevents self review in the interface", () => {
    render(<GroupReviewDecision group={review} canDecide={false} />);
    expect(screen.getByText(/outra pessoa administradora/i)).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /aprovar/i })).not.toBeInTheDocument();
  });

  it("validates rejection reason and prevents duplicate decisions", async () => {
    rejectGroup.mockResolvedValue({ ok: true });
    render(<GroupReviewDecision group={review} canDecide />);
    fireEvent.click(screen.getByRole("button", { name: /rejeitar solicitação/i }));
    fireEvent.change(screen.getByLabelText(/motivo da rejeição/i), { target: { value: "x" } });
    fireEvent.click(screen.getByRole("button", { name: /confirmar rejeição/i }));
    expect(await screen.findByRole("alert")).toHaveTextContent(/pelo menos 3/i);
    expect(rejectGroup).not.toHaveBeenCalled();
    fireEvent.change(screen.getByLabelText(/motivo da rejeição/i), { target: { value: "Dados insuficientes" } });
    fireEvent.click(screen.getByRole("button", { name: /confirmar rejeição/i }));
    const processing = screen.getByRole("button", { name: /processando/i });
    expect(processing).toBeDisabled();
    fireEvent.click(processing);
    await waitFor(() => expect(rejectGroup).toHaveBeenCalledTimes(1));
  });

  it("explains concurrent state changes without leaking internals", async () => {
    approveGroup.mockResolvedValue({ ok: false, code: "state_changed", message: "O estado mudou. Atualize a página e tente novamente." });
    render(<GroupReviewDecision group={review} canDecide />);
    fireEvent.click(screen.getByRole("button", { name: /aprovar grupo/i }));
    expect(await screen.findByRole("alert")).toHaveTextContent(/estado mudou/i);
    expect(screen.queryByText(/P0001|SQL/i)).not.toBeInTheDocument();
  });
});
