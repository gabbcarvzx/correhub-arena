import { describe, expect, it } from "vitest";

import { decodeGroupCursor, encodeGroupCursor } from "./cursor";

describe("group cursor", () => {
  it("round trips a stable timestamp and id cursor", () => {
    const cursor = { sort: "2026-09-27T12:00:00.000Z", id: crypto.randomUUID() };
    expect(decodeGroupCursor(encodeGroupCursor(cursor))).toEqual(cursor);
  });

  it.each(["", "//evil", "bm90LWpzb24", "e30", "a".repeat(513)])(
    "rejects a non-canonical cursor: %s",
    (value) => expect(decodeGroupCursor(value)).toBeNull(),
  );
});
