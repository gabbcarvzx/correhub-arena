// @vitest-environment node

import { describe, expect, it } from "vitest";

import {
  LOCAL_SUPABASE_URL,
  buildNextEnvironment,
  validateLocalSupabaseStatus,
} from "./auth-e2e-env.mjs";

const localStatus = {
  API_URL: "http://127.0.0.1:54321",
  ANON_KEY: "publishable-local-test",
  SERVICE_ROLE_KEY: "service-role-local-test",
  SECRET_KEY: "secret-local-test",
};

describe("Auth E2E environment boundary", () => {
  it("accepts only the exact local Supabase API", () => {
    expect(validateLocalSupabaseStatus(localStatus).url).toBe(LOCAL_SUPABASE_URL);

    for (const url of [
      "https://project.supabase.co",
      "http://localhost:54321",
      "http://127.0.0.1:54322",
    ]) {
      expect(() => validateLocalSupabaseStatus({ ...localStatus, API_URL: url })).toThrow(
        /local Supabase/i,
      );
    }
  });

  it("passes public values to Next without service or management secrets", () => {
    const inherited = Object.fromEntries([
      ["PATH", "safe-path"],
      ["SUPABASE_ACCESS_TOKEN", "management-fixture"],
      ["SUPABASE_SERVICE_ROLE_KEY", "service-fixture"],
      ["GOOGLE_CLIENT_SECRET", "google-fixture"],
    ]);
    const nextEnvironment = buildNextEnvironment(localStatus, inherited);

    expect(nextEnvironment).toMatchObject({
      PATH: "safe-path",
      NEXT_PUBLIC_SUPABASE_URL: LOCAL_SUPABASE_URL,
      NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: localStatus.ANON_KEY,
      NEXT_PUBLIC_SITE_URL: "http://localhost:3000",
      SUPABASE_SECRET_KEY: localStatus.SECRET_KEY,
    });
    expect(Object.keys(nextEnvironment)).not.toEqual(
      expect.arrayContaining([
        "SERVICE_ROLE_KEY",
        "SUPABASE_SERVICE_ROLE_KEY",
        "SUPABASE_ACCESS_TOKEN",
        "GOOGLE_CLIENT_SECRET",
      ]),
    );
    expect(Object.values(nextEnvironment)).not.toContain(localStatus.SERVICE_ROLE_KEY);
    expect(Object.keys(nextEnvironment).filter((name) => name.startsWith("NEXT_PUBLIC_"))).not.toContain("SUPABASE_SECRET_KEY");
  });
});
