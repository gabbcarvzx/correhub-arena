import { describe, expect, it } from "vitest";

import { sanitizeInternalReturnTo } from "./return-to";

describe("sanitizeInternalReturnTo", () => {
  it.each([
    ["/", "/"],
    ["/corridas/id", "/corridas/id"],
    ["/corridas/id?dia=1", "/corridas/id?dia=1"],
    ["/algum/caminho?x=um%20valor", "/algum/caminho?x=um%20valor"],
  ])("accepts the internal destination %s", (input, expected) => {
    expect(sanitizeInternalReturnTo(input)).toBe(expected);
  });

  it.each([
    "https://evil.example",
    "http://evil.example",
    "//evil.example",
    "\\\\evil.example",
    "/\\evil.example",
    "javascript:alert(1)",
    "data:text/html,evil",
    "evil.example/path",
    "/%2fevil.example",
    "/%2Fevil.example",
    "/%5cevil.example",
    "/%5Cevil.example",
    "/%252fevil.example",
    "/%25252fevil.example",
    "/bad%encoding",
    "/line\nbreak",
    "/path#fragment",
    "/login",
    "/lo%67in",
    "/login/again",
    "/auth/callback",
    "/auth/%63allback",
    "/auth/callback/replay",
    "/auth/auth-code-error",
    "/logout",
    "/onboarding",
    "/account-unavailable",
  ])("rejects unsafe or looping destination %s", (input) => {
    expect(sanitizeInternalReturnTo(input)).toBe("/");
  });

  it("uses only a valid internal fallback", () => {
    expect(sanitizeInternalReturnTo("https://evil.example", "/safe")).toBe("/safe");
    expect(sanitizeInternalReturnTo("https://evil.example", "//also-evil.example")).toBe("/");
  });
});
