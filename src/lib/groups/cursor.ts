import { z } from "zod";

import type { GroupCursor } from "./types";

const encodedSchema = z.string().min(1).max(512).regex(/^[A-Za-z0-9_-]+$/);
const cursorSchema = z
  .object({ sort: z.iso.datetime({ offset: true }), id: z.uuid() })
  .strict();

export function encodeGroupCursor(cursor: GroupCursor): string {
  return Buffer.from(JSON.stringify(cursorSchema.parse(cursor)), "utf8").toString("base64url");
}

export function decodeGroupCursor(value: string | null | undefined): GroupCursor | null {
  const encoded = encodedSchema.safeParse(value);
  if (!encoded.success) return null;
  try {
    const decoded = Buffer.from(encoded.data, "base64url").toString("utf8");
    if (Buffer.from(decoded, "utf8").toString("base64url") !== encoded.data) return null;
    const parsed = cursorSchema.safeParse(JSON.parse(decoded));
    return parsed.success ? parsed.data : null;
  } catch {
    return null;
  }
}
