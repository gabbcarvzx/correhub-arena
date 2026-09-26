import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const { createServerSupabaseClient, getCurrentAccountState, getCurrentAuthUser, redirect } = vi.hoisted(
  () => ({
    createServerSupabaseClient: vi.fn(),
    getCurrentAccountState: vi.fn(),
    getCurrentAuthUser: vi.fn(),
    redirect: vi.fn(),
  }),
);

vi.mock("@/lib/supabase/server", () => ({ createServerSupabaseClient }));
vi.mock("@/lib/auth/current-account", () => ({ getCurrentAccountState, getCurrentAuthUser }));
vi.mock("next/navigation", () => ({ redirect }));

import OnboardingPage from "./page";

describe("OnboardingPage", () => {
  beforeEach(() => {
    const citiesQuery = {
      eq: vi.fn().mockReturnThis(),
      order: vi.fn().mockResolvedValue({
        data: [{ id: "10000000-0000-4000-8000-000000000001", name: "Cidade ativa", state_code: "PE" }],
        error: null,
      }),
    };
    const settingsQuery = {
      eq: vi.fn().mockReturnThis(),
      single: vi.fn().mockResolvedValue({
        data: { launch_city_id: "10000000-0000-4000-8000-000000000001" },
        error: null,
      }),
    };
    const profileQuery = {
      eq: vi.fn().mockReturnThis(),
      maybeSingle: vi.fn().mockResolvedValue({ data: { full_name: null }, error: null }),
    };
    const from = vi.fn((table: string) => ({
      select: vi.fn(() =>
        table === "cities" ? citiesQuery : table === "app_settings" ? settingsQuery : profileQuery,
      ),
    }));
    createServerSupabaseClient.mockReset().mockResolvedValue({ from });
    getCurrentAccountState.mockReset().mockResolvedValue({
      kind: "active",
      userId: "user-a",
      onboardingCompleted: false,
    });
    getCurrentAuthUser.mockReset().mockResolvedValue({
      id: "user-a",
      user_metadata: { full_name: "Nome sugerido" },
    });
    redirect.mockReset();
  });

  it("loads active cities and uses Google metadata only as an initial name", async () => {
    render(await OnboardingPage({ searchParams: Promise.resolve({ returnTo: "/area" }) }));

    expect(screen.getByRole("heading", { name: "Complete seu perfil" })).toBeInTheDocument();
    expect(screen.getByLabelText("Nome")).toHaveValue("Nome sugerido");
    expect(screen.getByRole("option", { name: "Cidade ativa — PE" })).toBeInTheDocument();
    expect(screen.queryByLabelText(/avatar/i)).not.toBeInTheDocument();
  });
});
