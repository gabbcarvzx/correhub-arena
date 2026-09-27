import "server-only";

import { createHash } from "node:crypto";
import sharp from "sharp";

export type GroupMediaKind = "avatar" | "cover";
export type GroupMediaErrorCode = "invalid_format" | "too_large" | "dimensions" | "processing_failed";

export class GroupMediaError extends Error {
  constructor(public readonly code: GroupMediaErrorCode) {
    super(code === "too_large" ? "A imagem é maior que o permitido." : code === "dimensions" ? "A imagem tem dimensões inválidas." : "Use uma imagem JPEG, PNG ou WebP válida.");
    this.name = "GroupMediaError";
  }
}

const INPUT_BYTES = 1_000_000;
const INPUT_PIXELS = 24_000_000;
const limits = {
  avatar: { side: 512, bytes: 250_000 },
  cover: { side: 1600, bytes: 600_000 },
} as const;

export async function normalizeGroupImage(input: Uint8Array, kind: GroupMediaKind) {
  if (input.byteLength < 1 || input.byteLength > INPUT_BYTES) throw new GroupMediaError("too_large");
  try {
    const metadata = await sharp(input, { limitInputPixels: false, animated: false, failOn: "error" }).metadata();
    if (!metadata.width || !metadata.height || metadata.width * metadata.height > INPUT_PIXELS) throw new GroupMediaError("dimensions");
    if (!metadata.format || !["jpeg", "png", "webp"].includes(metadata.format)) throw new GroupMediaError("invalid_format");
    const image = sharp(input, { limitInputPixels: INPUT_PIXELS, animated: false, failOn: "error" });
    const limit = limits[kind];
    let bytes = Buffer.alloc(0);
    for (const quality of [82, 72, 60]) {
      bytes = await image.clone().rotate().resize({ width: limit.side, height: limit.side, fit: "inside", withoutEnlargement: true }).webp({ quality, effort: 4 }).toBuffer();
      if (bytes.byteLength <= limit.bytes) break;
    }
    if (bytes.byteLength > limit.bytes) throw new GroupMediaError("too_large");
    const output = await sharp(bytes).metadata();
    return {
      bytes,
      contentType: "image/webp" as const,
      width: output.width!,
      height: output.height!,
      hash: createHash("sha256").update(bytes).digest("hex"),
    };
  } catch (error) {
    if (error instanceof GroupMediaError) throw error;
    throw new GroupMediaError("processing_failed");
  }
}
