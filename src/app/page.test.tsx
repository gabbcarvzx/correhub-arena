import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const { getCurrentAccountState } = vi.hoisted(() => ({ getCurrentAccountState: vi.fn() }));
vi.mock("@/lib/auth/current-account", () => ({ getCurrentAccountState }));

import Page from "./page";

describe("Home", () => {
  beforeEach(() => {
    getCurrentAccountState.mockReset().mockResolvedValue({ kind: "anonymous" });
  });

  it("preserves the foundation and offers login to a visitor", async () => {
    render(await Page());
    expect(screen.getByRole("heading", { level: 1, name: "CorreHub" })).toBeInTheDocument();
    expect(screen.getByRole("status")).toHaveTextContent("Em desenvolvimento");
    expect(screen.getByRole("link", { name: "Entrar com Google" })).toHaveAttribute("href", "/login");
  });

  it("offers onboarding and logout without creating a dashboard", async () => {
    getCurrentAccountState.mockResolvedValue({
      kind: "active",
      userId: "user-a",
      onboardingCompleted: false,
    });

    render(await Page());
    expect(screen.getByRole("link", { name: "Continuar cadastro" })).toHaveAttribute(
      "href",
      "/onboarding",
    );
    expect(screen.getByRole("link", { name: "Sair" })).toHaveAttribute("href", "/logout");
    expect(screen.queryByText(/dashboard|feed|seguidores/i)).not.toBeInTheDocument();
  });
});
