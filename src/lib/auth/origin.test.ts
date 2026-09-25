import { describe, expect, it } from "vitest";

import { buildAuthCallbackUrl, getConfiguredAppOrigin } from "./origin";

describe("getConfiguredAppOrigin", () => {
  it.each([
    ["https://correhub.vercel.app", "https://correhub.vercel.app"],
    ["https://feature-gate-2.example.vercel.app/", "https://feature-gate-2.example.vercel.app"],
    ["http://localhost:3000", "http://localhost:3000"],
    ["http://localhost:3000/", "http://localhost:3000"],
  ])("accepts configured application origin %s", (value, expected) => {
    expect(getConfiguredAppOrigin(value)).toBe(expected);
  });

  it.each([
    "http://correhub.vercel.app",
    "http://localhost:3001",
    "http://127.0.0.1:3000",
    "https://user:password@correhub.vercel.app",
    "https://correhub.vercel.app/path",
    "https://correhub.vercel.app?query=1",
    "https://correhub.vercel.app#fragment",
    "not-a-url",
  ])("rejects untrusted configured origin without echoing %s", (value) => {
    expect(() => getConfiguredAppOrigin(value)).toThrow("NEXT_PUBLIC_SITE_URL");
    expect(() => getConfiguredAppOrigin(value)).not.toThrow(value);
  });
});

describe("buildAuthCallbackUrl", () => {
  it("encodes a sanitized internal destination exactly once", () => {
    const callback = buildAuthCallbackUrl(
      "/corridas/id?dia=um%20valor",
      "https://correhub.vercel.app",
    );
    const parsed = new URL(callback);

    expect(parsed.origin).toBe("https://correhub.vercel.app");
    expect(parsed.pathname).toBe("/auth/callback");
    expect(parsed.searchParams.get("returnTo")).toBe("/corridas/id?dia=um%20valor");
  });

  it("falls back without turning encoded input into an external origin", () => {
    const callback = buildAuthCallbackUrl(
      "/%252fevil.example",
      "https://correhub.vercel.app",
    );
    const parsed = new URL(callback);

    expect(parsed.origin).toBe("https://correhub.vercel.app");
    expect(parsed.searchParams.get("returnTo")).toBe("/");
  });
});
