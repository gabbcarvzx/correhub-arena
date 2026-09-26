import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const { createBrowserSupabaseClient, signInWithOAuth } = vi.hoisted(() => ({
  createBrowserSupabaseClient: vi.fn(),
  signInWithOAuth: vi.fn(),
}));

vi.mock("@/lib/supabase/client", () => ({ createBrowserSupabaseClient }));

import { LoginButton } from "./login-button";

describe("LoginButton", () => {
  beforeEach(() => {
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "http://127.0.0.1:54321");
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "sb_publishable_login-test");
    vi.stubEnv("NEXT_PUBLIC_SITE_URL", "http://localhost:3000");
    signInWithOAuth.mockReset();
    createBrowserSupabaseClient.mockReset().mockReturnValue({
      auth: { signInWithOAuth },
    });
  });

  it("starts Google OAuth with minimal scopes and a safe configured callback", async () => {
    signInWithOAuth.mockResolvedValue({ data: { url: "https://accounts.google.com" }, error: null });
    render(<LoginButton returnTo="/corridas/uma?dia=1" />);

    fireEvent.click(screen.getByRole("button", { name: "Continuar com Google" }));

    await waitFor(() => expect(signInWithOAuth).toHaveBeenCalledOnce());
    expect(signInWithOAuth).toHaveBeenCalledWith({
      provider: "google",
      options: {
        redirectTo:
          "http://localhost:3000/auth/callback?returnTo=%2Fcorridas%2Fuma%3Fdia%3D1",
        scopes: "openid email profile",
      },
    });
  });

  it("disables duplicate submission while the provider redirect is pending", async () => {
    signInWithOAuth.mockReturnValue(new Promise(() => undefined));
    render(<LoginButton returnTo="/" />);
    const button = screen.getByRole("button", { name: "Continuar com Google" });

    fireEvent.click(button);

    await waitFor(() => expect(button).toBeDisabled());
    expect(screen.getByText("Abrindo o Google…")).toBeInTheDocument();
    fireEvent.click(button);
    expect(signInWithOAuth).toHaveBeenCalledOnce();
  });

  it("shows a recoverable public error without provider details", async () => {
    signInWithOAuth.mockResolvedValue({
      data: { url: null },
      error: new Error("provider-secret-detail"),
    });
    render(<LoginButton returnTo="/" />);

    fireEvent.click(screen.getByRole("button", { name: "Continuar com Google" }));

    expect(await screen.findByRole("alert")).toHaveTextContent(
      "Não foi possível iniciar o acesso. Tente novamente.",
    );
    expect(screen.queryByText(/provider-secret-detail/)).not.toBeInTheDocument();
  });
});
