import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import type { MyGroup } from "@/lib/groups/types";
import { OrganizerGroupList } from "./organizer-group-list";

const base: MyGroup = { id: crypto.randomUUID(), slug: "corre-recife", name: "Corre Recife", type: "community", joinPolicy: "open", status: "pending", avatarUrl: null, updatedAt: "2026-09-27T12:00:00Z", rejectionReason: null, relation: { role: "owner", status: "pending" } };

describe("OrganizerGroupList", () => {
  it("has a useful empty state", () => {
    render(<OrganizerGroupList groups={[]} />);
    expect(screen.getByText("Você ainda não solicitou um grupo.")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Solicitar primeiro grupo" })).toHaveAttribute("href", "/grupos/solicitar");
  });

  it("translates every lifecycle state into a next action", () => {
    render(<OrganizerGroupList groups={[
      base,
      { ...base, id: crypto.randomUUID(), slug: "ajustar", status: "rejected", rejectionReason: "Informe os horários." },
      { ...base, id: crypto.randomUUID(), slug: "ativo", status: "approved", relation: { role: "owner", status: "active" } },
      { ...base, id: crypto.randomUUID(), slug: "suspenso", status: "suspended", relation: { role: "owner", status: "active" } },
    ]} />);
    expect(screen.getByText("Em análise")).toBeInTheDocument();
    expect(screen.getByText("Ajustes necessários")).toBeInTheDocument();
    expect(screen.getByText("Informe os horários.")).toBeInTheDocument();
    expect(screen.getByText("Ativo")).toBeInTheDocument();
    expect(screen.getByText("Suspenso")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Corrigir e reenviar" })).toHaveAttribute("href", "/grupos/ajustar/editar");
  });
});
