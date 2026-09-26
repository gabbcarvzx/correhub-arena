import { describe, expect, it } from "vitest";

import { readPublicEnv } from "./public";

const validEnv = {
  NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54321",
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_test-value",
  NEXT_PUBLIC_SITE_URL: "http://localhost:3000",
};

describe("readPublicEnv", () => {
  it.each(Object.keys(validEnv))("rejects a missing %s without exposing other values", (name) => {
    const source = { ...validEnv, [name]: undefined };

    expect(() => readPublicEnv(source)).toThrow(name);
    expect(() => readPublicEnv(source)).not.toThrow("test-value");
  });

  it.each([
    ["NEXT_PUBLIC_SUPABASE_URL", "not-a-url"],
    ["NEXT_PUBLIC_SUPABASE_URL", "ftp://supabase.example"],
    ["NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "secret-value"],
    ["NEXT_PUBLIC_SITE_URL", "javascript:alert(1)"],
  ])("rejects malformed %s without echoing its value", (name, value) => {
    const source = { ...validEnv, [name]: value };

    expect(() => readPublicEnv(source)).toThrow(name);
    expect(() => readPublicEnv(source)).not.toThrow(value);
  });

  it("returns the three validated public values", () => {
    expect(readPublicEnv(validEnv)).toEqual(validEnv);
  });
});
