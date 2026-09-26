import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const { getCurrentAccountState, redirect } = vi.hoisted(() => ({
  getCurrentAccountState: vi.fn(),
  redirect: vi.fn(),
}));

vi.mock("@/lib/auth/current-account", () => ({ getCurrentAccountState }));
vi.mock("next/navigation", () => ({ redirect }));

import AccountUnavailablePage from "./page";

describe("AccountUnavailablePage", () => {
  beforeEach(() => {
    getCurrentAccountState.mockReset();
    redirect.mockReset();
  });

  it("shows a neutral message and safe logout action without operational details", async () => {
    getCurrentAccountState.mockResolvedValue({ kind: "suspended", userId: "user-a" });

    render(await AccountUnavailablePage());

    expect(screen.getByRole("heading", { name: "Conta indisponível" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Sair da conta" })).toHaveAttribute("href", "/logout");
    expect(screen.queryByText(/suspended|role|reason|user-a/i)).not.toBeInTheDocument();
    expect(redirect).not.toHaveBeenCalled();
  });
});
