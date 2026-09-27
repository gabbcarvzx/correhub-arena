import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import type { ProfilePresentation } from "@/lib/profiles/types";

import { ProfileDetail } from "./profile-detail";

const profile: ProfilePresentation = {
  id: "31000000-0000-4000-8000-000000000001",
  username: "runner_one",
  fullName: "Runner One",
  avatarUrl: "https://images.example/runner.png",
  bio: "Treino cedo.",
  city: {
    id: "10000000-0000-4000-8000-000000000001",
    name: "São Lourenço da Mata",
    slug: "sao-lourenco-da-mata",
    countryCode: "BR",
    stateCode: "PE",
  },
  runningLevel: "beginner",
  preferredDistance: "up_to_5k",
  paceSecondsPerKm: 390,
  visibility: "public",
  createdAt: "2026-09-26T00:00:00.000Z",
};

describe("ProfileDetail", () => {
  it("renders the approved public fields", () => {
    render(<ProfileDetail profile={profile} viewer="visitor" />);

    expect(screen.getByRole("heading", { name: "Runner One" })).toBeInTheDocument();
    expect(screen.getByText("Treino cedo.")).toBeInTheDocument();
    expect(screen.getByText("São Lourenço da Mata, PE")).toBeInTheDocument();
    expect(screen.getByText("6:30 min/km")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Entrar para seguir" })).toHaveAttribute(
      "href",
      "/login?returnTo=%2Fu%2Frunner_one",
    );
  });

  it("renders only minimal identity for a private third-party profile", () => {
    render(
      <ProfileDetail
        profile={{
          ...profile,
          avatarUrl: null,
          bio: null,
          city: null,
          runningLevel: null,
          preferredDistance: null,
          paceSecondsPerKm: null,
          visibility: "private",
        }}
        viewer="authenticated"
      />,
    );

    expect(screen.getByText("Perfil privado")).toBeInTheDocument();
    expect(screen.getByLabelText("Avatar padrão de Runner One")).toBeInTheDocument();
    expect(screen.queryByText("Treino cedo.")).not.toBeInTheDocument();
    expect(screen.queryByText(/São Lourenço/)).not.toBeInTheDocument();
    expect(screen.queryByText(/min\/km/)).not.toBeInTheDocument();
    expect(screen.queryByRole("link", { name: /seguidores|seguindo/i })).not.toBeInTheDocument();
  });

  it("renders own profile controls without a follow action", () => {
    render(<ProfileDetail profile={{ ...profile, visibility: "self" }} viewer="self" />);

    expect(screen.getByRole("link", { name: "Editar perfil" })).toHaveAttribute(
      "href",
      "/settings/profile",
    );
    expect(screen.getByRole("link", { name: "Seguidores" })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /seguir/i })).not.toBeInTheDocument();
  });
});
