import sharp from "sharp";
import { describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

import { GroupMediaError, normalizeGroupImage } from "./group-media";

describe("group media normalization", () => {
  it.each(["jpeg", "png", "webp"] as const)("decodes and normalizes %s bytes to metadata-free webp", async (format) => {
    const source = sharp({ create: { width: 64, height: 48, channels: 3, background: "#b7f34a" } });
    const bytes = await (format === "jpeg" ? source.jpeg() : format === "png" ? source.png() : source.webp()).toBuffer();
    const result = await normalizeGroupImage(bytes, "avatar");
    const metadata = await sharp(result.bytes).metadata();
    expect(result).toMatchObject({ contentType: "image/webp", width: 64, height: 48 });
    expect(metadata.format).toBe("webp");
    expect(result.bytes.byteLength).toBeLessThanOrEqual(250_000);
  });

  it.each([
    ["svg", Buffer.from('<svg xmlns="http://www.w3.org/2000/svg"></svg>')],
    ["gif", Buffer.from("R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==", "base64")],
    ["fake", Buffer.from("not an image")],
  ])("rejects %s content regardless of declared type", async (_name, bytes) => {
    await expect(normalizeGroupImage(bytes, "avatar")).rejects.toBeInstanceOf(GroupMediaError);
  });

  it("rejects request bodies over one MiB and decoded images over 24 megapixels", async () => {
    await expect(normalizeGroupImage(Buffer.alloc(1_000_001), "cover")).rejects.toMatchObject({ code: "too_large" });
    const hugeHeader = await sharp({ create: { width: 5000, height: 5000, channels: 3, background: "black" } }).png().toBuffer();
    await expect(normalizeGroupImage(hugeHeader, "cover")).rejects.toMatchObject({ code: "dimensions" });
  });
});
