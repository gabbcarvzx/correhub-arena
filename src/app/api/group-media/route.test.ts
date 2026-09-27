import { beforeEach, describe, expect, it, vi } from "vitest";

const { createServerSupabaseClient, createAdminSupabaseClient, getCurrentAccountState, normalizeGroupImage } = vi.hoisted(() => ({
  createServerSupabaseClient: vi.fn(), createAdminSupabaseClient: vi.fn(),
  getCurrentAccountState: vi.fn(), normalizeGroupImage: vi.fn(),
}));
vi.mock("server-only", () => ({}));
vi.mock("@/lib/supabase/server", () => ({ createServerSupabaseClient }));
vi.mock("@/lib/supabase/admin", () => ({ createAdminSupabaseClient }));
vi.mock("@/lib/auth/current-account", () => ({ getCurrentAccountState }));
vi.mock("@/lib/media/group-media", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@/lib/media/group-media")>()),
  normalizeGroupImage,
}));

import { GET, POST } from "./route";

const groupId = "51000000-0000-4000-8000-000000000001";
const uploadId = "61000000-0000-4000-8000-000000000001";
const path = `${groupId}/avatar.webp`;

describe("group media route", () => {
  const rpc = vi.fn();
  const upload = vi.fn(); const remove = vi.fn(); const createSignedUrl = vi.fn();
  const fromStorage = vi.fn(() => ({ upload, remove, createSignedUrl }));

  beforeEach(() => {
    rpc.mockReset(); upload.mockReset().mockResolvedValue({ error: null });
    remove.mockReset().mockResolvedValue({ error: null });
    createSignedUrl.mockReset().mockResolvedValue({ data: { signedUrl: "https://signed.example/object" }, error: null });
    createServerSupabaseClient.mockReset().mockResolvedValue({ rpc });
    createAdminSupabaseClient.mockReset().mockReturnValue({ storage: { from: fromStorage } });
    getCurrentAccountState.mockReset().mockResolvedValue({ kind: "active", userId: crypto.randomUUID(), onboardingCompleted: true });
    normalizeGroupImage.mockReset().mockResolvedValue({ bytes: Buffer.from("webp"), contentType: "image/webp", width: 10, height: 10, hash: "a".repeat(64) });
  });

  it("fails closed when the privileged key is unavailable", async () => {
    createAdminSupabaseClient.mockImplementation(() => { throw new Error("missing"); });
    const response = await POST(uploadRequest());
    expect(response.status).toBe(503);
    expect(upload).not.toHaveBeenCalled();
  });

  it("uploads only to the server-authorized path and finalizes", async () => {
    rpc.mockResolvedValueOnce({ data: [{ upload_id: uploadId, object_path: path }], error: null }).mockResolvedValueOnce({ data: null, error: null });
    const response = await POST(uploadRequest("../../evil.webp"));
    expect(response.status).toBe(200);
    expect(upload).toHaveBeenCalledWith(path, expect.any(Buffer), expect.objectContaining({ contentType: "image/webp", upsert: true }));
    expect(rpc).toHaveBeenLastCalledWith("finalize_group_media_upload", { target_upload_id: uploadId });
  });

  it("removes the object when final authorization is revoked", async () => {
    rpc.mockResolvedValueOnce({ data: [{ upload_id: uploadId, object_path: path }], error: null }).mockResolvedValueOnce({ data: null, error: { code: "42501" } }).mockResolvedValueOnce({ data: null, error: null });
    const response = await POST(uploadRequest());
    expect(response.status).toBe(409);
    expect(remove).toHaveBeenCalledWith([path]);
    expect(rpc).toHaveBeenLastCalledWith("fail_group_media_upload", { target_upload_id: uploadId });
  });

  it("returns a 60-second signed URL with private no-store caching", async () => {
    rpc.mockResolvedValue({ data: path, error: null });
    const response = await GET(new Request(`http://localhost/api/group-media?groupId=${groupId}&kind=avatar`));
    expect(createSignedUrl).toHaveBeenCalledWith(path, 60);
    expect(response.headers.get("cache-control")).toBe("private, no-store");
  });
});

function uploadRequest(clientPath = "ignored.webp") {
  const form = new FormData(); form.set("groupId", groupId); form.set("kind", "avatar"); form.set("path", clientPath);
  form.set("file", new File(["bytes"], "avatar.png", { type: "image/png" }));
  return { formData: async () => form, url: "http://localhost/api/group-media" } as unknown as Request;
}
