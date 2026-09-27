import { beforeEach, describe, expect, it, vi } from "vitest";

const { createServerSupabaseClient, getCurrentAccountState, revalidatePath } = vi.hoisted(() => ({
  createServerSupabaseClient: vi.fn(),
  getCurrentAccountState: vi.fn(),
  revalidatePath: vi.fn(),
}));
vi.mock("@/lib/supabase/server", () => ({ createServerSupabaseClient }));
vi.mock("@/lib/auth/current-account", () => ({ getCurrentAccountState }));
vi.mock("next/cache", () => ({ revalidatePath }));

import { approveGroup, cancelOwnerTransfer, followGroup, initiateOwnerTransfer, requestGroup } from "./actions";

const actor = "31000000-0000-4000-8000-000000000001";
const groupId = "51000000-0000-4000-8000-000000000001";
const request = {
  name: "Corre Recife", slug: "corre-recife", description: "Treinos em comunidade.",
  city_id: "10000000-0000-4000-8000-000000000001",
  group_type: "community", join_policy: "open",
};

describe("group actions", () => {
  const rpc = vi.fn();
  const insert = vi.fn();
  const from = vi.fn(() => ({ insert }));

  beforeEach(() => {
    rpc.mockReset().mockResolvedValue({ data: groupId, error: null });
    insert.mockReset().mockResolvedValue({ error: null });
    createServerSupabaseClient.mockReset().mockResolvedValue({ rpc, from });
    getCurrentAccountState.mockReset().mockResolvedValue({ kind: "active", userId: actor, onboardingCompleted: true });
    revalidatePath.mockReset();
  });

  it("validates raw input and sends no actor or authority field", async () => {
    await expect(requestGroup(request)).resolves.toEqual({ ok: true, groupId, slug: request.slug });
    expect(rpc).toHaveBeenCalledWith("request_group", {
      requested_name: request.name, requested_slug: request.slug,
      requested_description: request.description, requested_city_id: request.city_id,
      requested_type: request.group_type, requested_join_policy: request.join_policy,
    });
  });

  it("blocks anonymous and suspended accounts before mutation", async () => {
    getCurrentAccountState.mockResolvedValue({ kind: "anonymous" });
    await expect(requestGroup(request)).resolves.toMatchObject({ ok: false, code: "unauthenticated" });
    getCurrentAccountState.mockResolvedValue({ kind: "suspended", userId: actor });
    await expect(approveGroup({ groupId })).resolves.toMatchObject({ ok: false, code: "forbidden" });
    expect(rpc).not.toHaveBeenCalled();
  });

  it("maps state changes and known denials without leaking SQL", async () => {
    rpc.mockResolvedValue({ data: null, error: { code: "P0001", message: "state_changed" } });
    const changed = await approveGroup({ groupId });
    expect(changed).toMatchObject({ ok: false, code: "state_changed" });
    expect(JSON.stringify(changed)).not.toMatch(/P0001|sql/i);
  });

  it("derives group follow actor from the current account and revalidates on success", async () => {
    await expect(followGroup({ groupId, slug: "corre-recife" })).resolves.toEqual({ ok: true, following: true });
    expect(insert).toHaveBeenCalledWith({ user_id: actor, group_id: groupId });
    expect(revalidatePath).toHaveBeenCalledWith("/grupos/corre-recife");
  });

  it("rejects mass-assignment fields", async () => {
    await expect(requestGroup({ ...request, status: "approved" })).resolves.toMatchObject({ ok: false, code: "validation_error" });
    await expect(approveGroup({ groupId, actorId: actor })).resolves.toMatchObject({ ok: false, code: "validation_error" });
    expect(rpc).not.toHaveBeenCalled();
  });

  it("uses only group and target identifiers for ownership transfer", async () => {
    rpc.mockResolvedValue({ data: "61000000-0000-4000-8000-000000000001", error: null });
    await expect(initiateOwnerTransfer({ groupId, userId: "31000000-0000-4000-8000-000000000002" })).resolves.toMatchObject({ ok: true, transferId: expect.any(String) });
    expect(rpc).toHaveBeenCalledWith("initiate_group_owner_transfer", { target_group_id: groupId, target_user_id: "31000000-0000-4000-8000-000000000002" });
    await cancelOwnerTransfer({ transferId: "61000000-0000-4000-8000-000000000001" });
    expect(rpc).toHaveBeenLastCalledWith("cancel_group_owner_transfer", { target_transfer_id: "61000000-0000-4000-8000-000000000001" });
  });
});
