import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import type { PublicGroup } from "@/lib/groups/types";
import { GroupDetail } from "./group-detail";

const base: PublicGroup = {
  id: "51000000-0000-4000-8000-000000000001", slug: "corre-recife", name: "Corre Recife",
  description: "Treinos em comunidade.", city: { id: "10000000-0000-4000-8000-000000000001", name: "Recife" },
  type: "community", joinPolicy: "open", status: "approved", ownerUserId: "u", avatarUrl: null,
  coverUrl: null, approvedAt: "2026-09-27", createdAt: "2026-09-27", updatedAt: "2026-09-27", isOwner: false,
};

describe("GroupDetail", () => {
  it("shows an approved group and visitor actions with a safe returnTo", () => {
    render(<GroupDetail group={base} relation={null} viewer="visitor" />);
    expect(screen.getByRole("heading", { name: "Corre Recife" })).toBeVisible();
    expect(screen.getByRole("link", { name: "Entrar para participar" })).toHaveAttribute("href", "/login?returnTo=%2Fgrupos%2Fcorre-recife");
  });

  it.each([
    ["pending", "Solicitação em análise"], ["rejected", "Solicitação devolvida"], ["suspended", "Grupo indisponível"],
  ] as const)("renders the %s state without public participation controls", (status, copy) => {
    render(<GroupDetail group={{ ...base, status, isOwner: true }} relation={{ role: "owner", status: "pending", joinedAt: null }} viewer="authenticated" />);
    expect(screen.getByRole("heading", { name: copy })).toBeVisible();
    expect(screen.queryByRole("button", { name: /entrar|seguir/i })).not.toBeInTheDocument();
  });
});
