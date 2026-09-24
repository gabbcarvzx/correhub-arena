import { render, screen } from "@testing-library/react";
import { expect, it } from "vitest";
import Page from "./page";

it("identifica a fundação do CorreHub", () => {
  render(<Page />);
  expect(screen.getByRole("heading", { level: 1, name: "CorreHub" })).toBeInTheDocument();
  expect(screen.getByRole("status")).toHaveTextContent("Em desenvolvimento");
});
