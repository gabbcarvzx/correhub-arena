import { z } from "zod";

import { profileUsernameSchema } from "@/lib/validations/profile";

import type { ProfileCursor } from "./types";

const MAX_CURSOR_LENGTH = 512;
const encodedCursorSchema = z
  .string()
  .min(1)
  .max(MAX_CURSOR_LENGTH)
  .regex(/^[A-Za-z0-9_-]+$/);
const cursorSchema = z
  .object({
    username: profileUsernameSchema,
    id: z.uuid(),
  })
  .strict();

export function encodeProfileCursor(cursor: ProfileCursor): string {
  const parsed = cursorSchema.parse(cursor);
  return Buffer.from(JSON.stringify(parsed), "utf8").toString("base64url");
}

export function decodeProfileCursor(value: string | null | undefined): ProfileCursor | null {
  const encoded = encodedCursorSchema.safeParse(value);
  if (!encoded.success) {
    return null;
  }

  try {
    const decoded = Buffer.from(encoded.data, "base64url").toString("utf8");
    const canonical = Buffer.from(decoded, "utf8").toString("base64url");
    if (canonical !== encoded.data) {
      return null;
    }

    const parsed = cursorSchema.safeParse(JSON.parse(decoded));
    return parsed.success ? parsed.data : null;
  } catch {
    return null;
  }
}
