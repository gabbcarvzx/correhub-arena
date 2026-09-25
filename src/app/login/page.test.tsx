import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const { getCurrentAccountState, redirect } = vi.hoisted(() => ({
  getCurrentAccountState: vi.fn(),
  redirect: vi.fn(),
}));

vi.mock("@/lib/auth/current-account", () => ({ getCurrentAccountState }));
vi.mock("next/navigation", () => ({ redirect }));

import LoginPage from "./page";

describe("LoginPage", () => {
  beforeEach(() => {
    getCurrentAccountState.mockReset().mockResolvedValue({ kind: "anonymous" });
    redirect.mockReset();
  });

  it("renders only the Google login action for a visitor", async () => {
    render(await LoginPage({ searchParams: Promise.resolve({ returnTo: "/area" }) }));

    expect(screen.getByRole("heading", { name: "Entre no CorreHub" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Continuar com Google" })).toBeInTheDocument();
    expect(screen.queryByLabelText(/senha|e-mail/i)).not.toBeInTheDocument();
  });
});
