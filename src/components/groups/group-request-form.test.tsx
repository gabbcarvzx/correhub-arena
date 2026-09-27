import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const { requestGroup, push } = vi.hoisted(() => ({ requestGroup: vi.fn(), push: vi.fn() }));
vi.mock("@/lib/groups/actions", () => ({ requestGroup }));
vi.mock("next/navigation", () => ({ useRouter: () => ({ push }) }));

import { GroupRequestForm } from "./group-request-form";

const cities = [{ id: "10000000-0000-4000-8000-000000000001", name: "Recife", state_code: "PE" }];

describe("GroupRequestForm", () => {
  beforeEach(() => { requestGroup.mockReset().mockResolvedValue({ ok: true, groupId: crypto.randomUUID(), slug: "corre-recife" }); push.mockReset(); });

  it("offers the complete accessible request contract and assists the slug", () => {
    render(<GroupRequestForm cities={cities} />);
    for (const name of ["Nome do grupo", "Endereço do grupo", "Descrição", "Cidade", "Tipo de grupo"]) {
      expect(screen.getByRole(name === "Descrição" ? "textbox" : name === "Cidade" || name === "Tipo de grupo" ? "combobox" : "textbox", { name })).toBeInTheDocument();
    }
    expect(screen.getByRole("group", { name: "Como as pessoas entram" })).toBeInTheDocument();
    expect(screen.getByRole("radio", { name: "Entrada livre" })).toBeInTheDocument();
    expect(screen.getByRole("radio", { name: "Com aprovação" })).toBeInTheDocument();
    fireEvent.change(screen.getByRole("textbox", { name: "Nome do grupo" }), { target: { value: "Corre Recife" } });
    expect(screen.getByRole("textbox", { name: "Endereço do grupo" })).toHaveValue("corre-recife");
  });

  it("submits once, preserves values on failure and exposes a linked status", async () => {
    requestGroup.mockResolvedValue({ ok: false, code: "conflict", message: "Este endereço já está em uso." });
    render(<GroupRequestForm cities={cities} />);
    fireEvent.change(screen.getByRole("textbox", { name: "Nome do grupo" }), { target: { value: "Corre Recife" } });
    fireEvent.change(screen.getByRole("textbox", { name: "Descrição" }), { target: { value: "Treinos em comunidade." } });
    fireEvent.click(screen.getByRole("button", { name: "Enviar para análise" }));
    await waitFor(() => expect(requestGroup).toHaveBeenCalledTimes(1));
    expect(await screen.findByRole("alert")).toHaveTextContent("Este endereço já está em uso.");
    expect(screen.getByRole("textbox", { name: "Nome do grupo" })).toHaveValue("Corre Recife");
  });
});
