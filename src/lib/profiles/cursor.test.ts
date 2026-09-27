import { describe, expect, it } from "vitest";

import { decodeProfileCursor, encodeProfileCursor } from "./cursor";

const cursor = {
  username: "runner_one",
  id: "31000000-0000-4000-8000-000000000001",
};

describe("profile cursor", () => {
  it("round trips a stable username/id cursor", () => {
    expect(decodeProfileCursor(encodeProfileCursor(cursor))).toEqual(cursor);
  });

  it.each([
    "not-base64!",
    Buffer.from(JSON.stringify({ username: "corredor_á", id: cursor.id })).toString("base64url"),
    Buffer.from(JSON.stringify({ username: cursor.username, id: "not-a-uuid" })).toString(
      "base64url",
    ),
    Buffer.from(JSON.stringify({ ...cursor, role: "admin" })).toString("base64url"),
    Buffer.from(Buffer.from(JSON.stringify(cursor)).toString("base64url")).toString("base64url"),
    "a".repeat(513),
  ])("rejects an invalid or manipulated cursor %#", (value) => {
    expect(decodeProfileCursor(value)).toBeNull();
  });
});
