import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { ProfileList } from "./profile-list";

describe("ProfileList", () => {
  it("renders an accessible empty state", () => {
    render(<ProfileList profiles={[]} />);
    expect(screen.getByRole("status")).toHaveTextContent("Nenhum corredor encontrado");
  });

  it("renders only supplied safe cards", () => {
    render(
      <ProfileList
        profiles={[{
          id: "31000000-0000-4000-8000-000000000001",
          username: "runner_one",
          fullName: "Runner One",
          avatarUrl: null,
          bio: "Bio pública",
          city: null,
          runningLevel: "beginner",
          preferredDistance: "up_to_5k",
          paceSecondsPerKm: null,
          visibility: "public",
          createdAt: "2026-09-26T00:00:00.000Z",
        }]}
      />,
    );
    expect(screen.getByRole("link", { name: /Runner One/ })).toHaveAttribute("href", "/u/runner_one");
  });
});
