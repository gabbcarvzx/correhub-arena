import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

const { logoutAction } = vi.hoisted(() => ({ logoutAction: vi.fn() }));
vi.mock("./actions", () => ({ logoutAction }));

import LogoutPage from "./page";

describe("LogoutPage", () => {
  it("uses a confirmation POST action and does not sign out on GET render", () => {
    render(<LogoutPage />);

    expect(screen.getByRole("heading", { name: "Sair do CorreHub" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Sair da conta" })).toBeInTheDocument();
    expect(logoutAction).not.toHaveBeenCalled();
  });
});
