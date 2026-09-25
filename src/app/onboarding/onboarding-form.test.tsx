import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const { completeOnboarding } = vi.hoisted(() => ({ completeOnboarding: vi.fn() }));
vi.mock("./actions", () => ({ completeOnboarding }));

import { OnboardingForm } from "./onboarding-form";

const props = {
  cities: [
    { id: "10000000-0000-4000-8000-000000000001", name: "São Lourenço da Mata", state_code: "PE" },
    { id: "10000000-0000-4000-8000-000000000002", name: "Recife", state_code: "PE" },
  ],
  launchCityId: "10000000-0000-4000-8000-000000000001",
  initialFullName: "Runner Google",
  returnTo: "/area",
};

function fillRequiredFields() {
  fireEvent.change(screen.getByLabelText("Nome de usuário"), { target: { value: "runner_one" } });
  fireEvent.change(screen.getByLabelText("Nível de corrida"), { target: { value: "beginner" } });
  fireEvent.change(screen.getByLabelText("Distância preferida"), { target: { value: "up_to_5k" } });
}

describe("OnboardingForm", () => {
  beforeEach(() => {
    completeOnboarding.mockReset().mockResolvedValue({ ok: true });
  });

  it("renders accessible fields, provider name suggestion and launch city from props", () => {
    render(<OnboardingForm {...props} />);

    expect(screen.getByLabelText("Nome de usuário")).toBeInTheDocument();
    expect(screen.getByLabelText("Nome")).toHaveValue("Runner Google");
    expect(screen.getByLabelText("Cidade")).toHaveValue(props.launchCityId);
    expect(screen.getByLabelText("Nível de corrida")).toBeInTheDocument();
    expect(screen.getByLabelText("Distância preferida")).toBeInTheDocument();
    expect(screen.getByLabelText("Bio (opcional)")).toBeInTheDocument();
    expect(screen.getByLabelText("Pace aproximado (opcional)")).toBeInTheDocument();
    expect(screen.getByLabelText("Perfil privado")).not.toBeChecked();
    expect(screen.getByText(/perfil é público por padrão/i)).toBeInTheDocument();
    expect(screen.getByLabelText("Pace aproximado (opcional)")).toHaveAttribute(
      "aria-describedby",
      "pace-help",
    );
    expect(screen.getByLabelText("Perfil privado")).toHaveAttribute(
      "aria-describedby",
      "privacy-help",
    );
  });

  it("places validation errors next to invalid fields", async () => {
    render(<OnboardingForm {...props} />);
    fireEvent.change(screen.getByLabelText("Nome de usuário"), { target: { value: "ab" } });
    fireEvent.click(screen.getByRole("button", { name: "Concluir cadastro" }));

    const username = screen.getByLabelText("Nome de usuário");
    expect(await screen.findByText("Use de 3 a 30 caracteres")).toBeInTheDocument();
    expect(username).toHaveAttribute("aria-invalid", "true");
    expect(username).toHaveAttribute("aria-describedby", "username-error");
    expect(completeOnboarding).not.toHaveBeenCalled();
  });

  it("submits once and disables duplicate submission", async () => {
    let resolveAction: ((value: { ok: true }) => void) | undefined;
    completeOnboarding.mockReturnValue(
      new Promise((resolve) => {
        resolveAction = resolve;
      }),
    );
    render(<OnboardingForm {...props} />);
    fillRequiredFields();
    const button = screen.getByRole("button", { name: "Concluir cadastro" });

    fireEvent.click(button);
    await waitFor(() => expect(button).toBeDisabled());
    fireEvent.click(button);
    expect(completeOnboarding).toHaveBeenCalledOnce();
    expect(completeOnboarding).toHaveBeenCalledWith(
      expect.objectContaining({
        username: "runner_one",
        full_name: "Runner Google",
        city_id: props.launchCityId,
        running_level: "beginner",
        preferred_distance: "up_to_5k",
        is_private: false,
      }),
      "/area",
    );
    resolveAction?.({ ok: true });
  });

  it("preserves values and presents a concurrent username conflict", async () => {
    completeOnboarding.mockResolvedValue({
      ok: false,
      message: "Revise os campos indicados.",
      fieldErrors: { username: "Este nome de usuário já está em uso" },
    });
    render(<OnboardingForm {...props} />);
    fillRequiredFields();

    fireEvent.click(screen.getByRole("button", { name: "Concluir cadastro" }));

    expect(await screen.findByText("Este nome de usuário já está em uso")).toBeInTheDocument();
    expect(screen.getByLabelText("Nome de usuário")).toHaveValue("runner_one");
  });
});
