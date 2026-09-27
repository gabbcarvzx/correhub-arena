import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const { updateProfile } = vi.hoisted(() => ({ updateProfile: vi.fn() }));
vi.mock("./actions", () => ({ updateProfile }));

import { ProfileForm } from "./profile-form";

const props = {
  cities: [{ id: "10000000-0000-4000-8000-000000000001", name: "Recife", state_code: "PE" }],
  initialValues: {
    username: "runner_one",
    full_name: "Runner One",
    city_id: "10000000-0000-4000-8000-000000000001",
    running_level: "beginner" as const,
    preferred_distance: "up_to_5k" as const,
    bio: "Bio atual",
    pace: "6:30",
    is_private: false,
  },
};

describe("ProfileForm", () => {
  beforeEach(() => updateProfile.mockReset().mockResolvedValue({ ok: true, username: "runner_one" }));

  it("renders current values with accessible labels and no avatar upload", () => {
    render(<ProfileForm {...props} />);
    expect(screen.getByLabelText("Nome de usuário")).toHaveValue("runner_one");
    expect(screen.getByLabelText("Bio (opcional)")).toHaveValue("Bio atual");
    expect(screen.getByLabelText("Perfil privado")).not.toBeChecked();
    expect(screen.queryByLabelText(/avatar|foto/i)).not.toBeInTheDocument();
  });

  it("prevents duplicate submission and preserves values after a conflict", async () => {
    let resolveAction: ((value: unknown) => void) | undefined;
    updateProfile.mockReturnValue(new Promise((resolve) => (resolveAction = resolve)));
    render(<ProfileForm {...props} />);
    const input = screen.getByLabelText("Nome de usuário");
    fireEvent.change(input, { target: { value: "runner_new" } });
    const button = screen.getByRole("button", { name: "Salvar perfil" });
    fireEvent.click(button);
    await waitFor(() => expect(button).toBeDisabled());
    fireEvent.click(button);
    expect(updateProfile).toHaveBeenCalledOnce();
    resolveAction?.({
      ok: false,
      code: "conflict",
      message: "Revise os campos indicados.",
      fieldErrors: { username: "Este nome de usuário já está em uso" },
    });
    expect(await screen.findByText("Este nome de usuário já está em uso")).toBeInTheDocument();
    expect(input).toHaveValue("runner_new");
  });
});
