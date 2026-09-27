import { beforeEach, describe, expect, it, vi } from "vitest";

const { createServerSupabaseClient } = vi.hoisted(() => ({
  createServerSupabaseClient: vi.fn(),
}));
vi.mock("server-only", () => ({}));
vi.mock("@/lib/supabase/server", () => ({ createServerSupabaseClient }));

import { getGroupBySlug, listGroupReviewQueue, listMyGroups } from "./queries";

const publicRow = {
  id: "51000000-0000-4000-8000-000000000001",
  slug: "corre-recife",
  name: "Corre Recife",
  description: "Treinos em comunidade.",
  city_id: "10000000-0000-4000-8000-000000000001",
  city_name: "Recife",
  group_type: "community",
  join_policy: "open",
  status: "approved",
  owner_user_id: "31000000-0000-4000-8000-000000000001",
  avatar_url: null,
  cover_url: null,
  approved_at: "2026-09-27T12:00:00.000Z",
  created_at: "2026-09-27T10:00:00.000Z",
  updated_at: "2026-09-27T12:00:00.000Z",
  is_owner: false,
};

describe("group queries", () => {
  const rpc = vi.fn();

  beforeEach(() => {
    rpc.mockReset();
    createServerSupabaseClient.mockReset().mockResolvedValue({ rpc });
  });

  it("maps the public group projection without private review fields", async () => {
    rpc.mockResolvedValue({ data: [{ ...publicRow, rejection_reason: "must not leak" }], error: null });
    const group = await getGroupBySlug("corre-recife");
    expect(group).toMatchObject({ slug: "corre-recife", status: "approved", city: { name: "Recife" } });
    expect(group).not.toHaveProperty("rejectionReason");
  });

  it("keeps rejection reason only in the requester list", async () => {
    rpc.mockResolvedValue({
      data: [{
        id: publicRow.id, slug: publicRow.slug, name: publicRow.name,
        group_type: "community", join_policy: "open", status: "rejected",
        rejection_reason: "Informe os horários.", avatar_url: null,
        updated_at: publicRow.updated_at, relation_role: "owner", relation_status: "pending",
      }],
      error: null,
    });
    await expect(listMyGroups({})).resolves.toMatchObject({
      items: [{ rejectionReason: "Informe os horários.", relation: { role: "owner", status: "pending" } }],
    });
  });

  it("maps a reviewer queue without manufacturing rejection data", async () => {
    rpc.mockResolvedValue({ data: [{ ...publicRow, created_by: publicRow.owner_user_id }], error: null });
    const result = await listGroupReviewQueue({});
    expect(result.items[0]).toMatchObject({ id: publicRow.id, status: "approved" });
    expect(result.items[0]).not.toHaveProperty("rejectionReason");
  });

  it("maps SQL failures to a stable temporary error", async () => {
    rpc.mockResolvedValue({ data: null, error: { code: "XX000", message: "private sql" } });
    await expect(getGroupBySlug("corre-recife")).rejects.toMatchObject({ code: "temporary_error" });
  });
});
