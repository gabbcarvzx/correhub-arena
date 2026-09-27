import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const { createServerSupabaseClient, discoverProfiles, getCurrentAccountState } = vi.hoisted(() => ({
  createServerSupabaseClient: vi.fn(),
  discoverProfiles: vi.fn(),
  getCurrentAccountState: vi.fn(),
}));
vi.mock("@/lib/supabase/server", () => ({ createServerSupabaseClient }));
vi.mock("@/lib/profiles/queries", () => ({ discoverProfiles }));
vi.mock("@/lib/auth/current-account", () => ({ getCurrentAccountState }));

import PeoplePage from "./page";

describe("PeoplePage", () => {
  beforeEach(() => {
    const cityOrder = vi.fn().mockResolvedValue({
      data: [{ id: "10000000-0000-4000-8000-000000000001", name: "Recife", state_code: "PE" }],
      error: null,
    });
    const cityEq = vi.fn(() => ({ order: cityOrder }));
    const settingSingle = vi.fn().mockResolvedValue({ data: { launch_city_id: "10000000-0000-4000-8000-000000000001" }, error: null });
    const settingEq = vi.fn(() => ({ single: settingSingle }));
    createServerSupabaseClient.mockReset().mockResolvedValue({
      from: vi.fn((table: string) => ({
        select: vi.fn(() => ({ eq: table === "cities" ? cityEq : settingEq })),
      })),
    });
    getCurrentAccountState.mockReset().mockResolvedValue({ kind: "anonymous" });
    discoverProfiles.mockReset().mockResolvedValue({ items: [], nextCursor: null });
  });

  it("uses launch city for visitors and passes validated filters", async () => {
    render(await PeoplePage({ searchParams: Promise.resolve({ q: " runner " }) }));
    expect(discoverProfiles).toHaveBeenCalledWith({
      query: "runner",
      cityId: "10000000-0000-4000-8000-000000000001",
      cursor: undefined,
    });
    expect(screen.getByRole("heading", { name: "Descobrir corredores" })).toBeInTheDocument();
    expect(screen.getByRole("status")).toHaveTextContent("Nenhum corredor encontrado");
  });

  it("does not pass invalid query parameters to the DAL", async () => {
    render(await PeoplePage({ searchParams: Promise.resolve({ city: "invalid", cursor: "//evil" }) }));
    expect(discoverProfiles).toHaveBeenCalledWith(expect.objectContaining({
      cityId: "10000000-0000-4000-8000-000000000001",
      cursor: undefined,
    }));
  });
});
