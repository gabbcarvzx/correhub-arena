import { describe, expect, it } from "vitest";

import {
  DISTANCE_LABELS,
  RUNNING_LEVEL_LABELS,
  onboardingSchema,
} from "./onboarding";

const valid = {
  username: "runner_01",
  full_name: "Runner One",
  city_id: "10000000-0000-4000-8000-000000000001",
  running_level: "beginner",
  preferred_distance: "up_to_5k",
  bio: "",
  pace: "6:30",
  is_private: false,
};

describe("onboardingSchema", () => {
  it("normalizes text and converts optional values", () => {
    expect(
      onboardingSchema.parse({
        ...valid,
        username: "  Runner_01  ",
        full_name: "  Runner One  ",
        bio: "  Correndo com calma.  ",
      }),
    ).toEqual({
      username: "runner_01",
      full_name: "Runner One",
      city_id: valid.city_id,
      running_level: valid.running_level,
      preferred_distance: valid.preferred_distance,
      bio: "Correndo com calma.",
      pace_seconds_per_km: 390,
      is_private: false,
    });
  });

  it.each([
    ["ab", "Use de 3 a 30 caracteres"],
    ["a".repeat(31), "Use de 3 a 30 caracteres"],
    ["runner-name", "Use apenas letras minúsculas, números e _"],
    ["corredor!", "Use apenas letras minúsculas, números e _"],
  ])("rejects invalid username %s", (username, message) => {
    const result = onboardingSchema.safeParse({ ...valid, username });
    expect(result.success).toBe(false);
    expect(result.error?.issues[0].message).toBe(message);
  });

  it("accepts the three-character username boundary", () => {
    expect(onboardingSchema.parse({ ...valid, username: "abc" }).username).toBe("abc");
  });

  it.each(["A", "", "A".repeat(81)])("rejects invalid full name", (full_name) => {
    expect(onboardingSchema.safeParse({ ...valid, full_name }).success).toBe(false);
  });

  it("requires a UUID city", () => {
    const result = onboardingSchema.safeParse({ ...valid, city_id: "sao-lourenco" });
    expect(result.success).toBe(false);
    expect(result.error?.issues[0].message).toBe("Selecione uma cidade válida");
  });

  it.each(["casual", "elite", ""])("rejects unknown running level %s", (running_level) => {
    expect(onboardingSchema.safeParse({ ...valid, running_level }).success).toBe(false);
  });

  it.each(["5 km", "marathon", ""])("rejects unknown preferred distance %s", (preferred_distance) => {
    expect(onboardingSchema.safeParse({ ...valid, preferred_distance }).success).toBe(false);
  });

  it("turns empty optional values into null", () => {
    const parsed = onboardingSchema.parse({ ...valid, bio: "  ", pace: "  " });
    expect(parsed.bio).toBeNull();
    expect(parsed.pace_seconds_per_km).toBeNull();
  });

  it.each(["1:59", "30:01", "6:60", "seis", "6"])("rejects invalid pace %s", (pace) => {
    const result = onboardingSchema.safeParse({ ...valid, pace });
    expect(result.success).toBe(false);
    expect(result.error?.issues.some((issue) => issue.message.includes("Pace"))).toBe(true);
  });

  it.each([
    ["2:00", 120],
    ["6:05", 365],
    ["30:00", 1800],
  ])("converts valid pace %s", (pace, seconds) => {
    expect(onboardingSchema.parse({ ...valid, pace }).pace_seconds_per_km).toBe(seconds);
  });

  it("enforces the bio limit", () => {
    expect(onboardingSchema.safeParse({ ...valid, bio: "a".repeat(301) }).success).toBe(false);
  });
});

describe("onboarding labels", () => {
  it("maps persisted values to Portuguese labels", () => {
    expect(RUNNING_LEVEL_LABELS).toEqual({
      beginner: "Iniciante",
      intermediate: "Intermediário",
      advanced: "Avançado",
    });
    expect(DISTANCE_LABELS).toEqual({
      up_to_5k: "Até 5 km",
      "5k_to_10k": "De 5 a 10 km",
      "10k_to_21k": "De 10 a 21 km",
      over_21k: "Mais de 21 km",
      flexible: "Flexível",
    });
  });
});
