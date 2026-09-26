import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import AuthCodeErrorPage from "./page";

describe("AuthCodeErrorPage", () => {
  it("offers a safe retry without provider details", () => {
    render(<AuthCodeErrorPage />);

    expect(screen.getByRole("heading", { name: "Não foi possível entrar" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Tentar novamente" })).toHaveAttribute("href", "/login");
    expect(screen.queryByText(/token|código|sql|google/i)).not.toBeInTheDocument();
  });
});
