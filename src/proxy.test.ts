// @vitest-environment node

import { describe, expect, it } from "vitest";

import { config } from "./proxy";

describe("proxy matcher", () => {
  it("excludes Next internals, favicon and files with extensions", () => {
    expect(config.matcher).toEqual([
      "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)",
    ]);
  });
});
