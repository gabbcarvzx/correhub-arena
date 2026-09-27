import { describe, expect, it } from "vitest";

import {
  DISTANCE_LABELS,
  RUNNING_LEVEL_LABELS,
  discoveryQuerySchema,
  profileEditSchema,
} from "./profile";

const valid = {
  username: " Runner_One ",
  full_name: " Runner One ",
  city_id: "10000000-0000-4000-8000-000000000001",
  running_level: "beginner",
  preferred_distance: "up_to_5k",
  bio: " ",
  pace: "6:30",
  is_private: false,
};

describe("profileEditSchema", () => {
  it("normalizes the actual form payload into the database contract", () => {
    expect(profileEditSchema.parse(valid)).toEqual({
      username: "runner_one",
      full_name: "Runner One",
      city_id: valid.city_id,
      running_level: "beginner",
      preferred_distance: "up_to_5k",
      bio: null,
      pace_seconds_per_km: 390,
      is_private: false,
    });
  });

  it("keeps optional pace absent instead of converting it to zero", () => {
    expect(profileEditSchema.parse({ ...valid, pace: "" }).pace_seconds_per_km).toBeNull();
  });

  it.each([
    ["username", { username: "ab" }],
    ["username", { username: "runner-name" }],
    ["full_name", { full_name: "A" }],
    ["city_id", { city_id: "invalid" }],
    ["running_level", { running_level: "elite" }],
    ["preferred_distance", { preferred_distance: "42k" }],
    ["bio", { bio: "x".repeat(301) }],
    ["pace", { pace: "1:59" }],
    ["pace", { pace: "6:99" }],
  ])("rejects invalid %s input", (_field, override) => {
    expect(profileEditSchema.safeParse({ ...valid, ...override }).success).toBe(false);
  });

  it("keeps the approved Portuguese labels", () => {
    expect(RUNNING_LEVEL_LABELS.beginner).toBe("Iniciante");
    expect(DISTANCE_LABELS.flexible).toBe("Flexível");
  });
});

describe("discoveryQuerySchema", () => {
  it("trims a valid query and accepts a city/cursor", () => {
    expect(
      discoveryQuerySchema.parse({
        q: "  runner  ",
        city: valid.city_id,
        cursor: "abc_123",
      }),
    ).toEqual({ q: "runner", city: valid.city_id, cursor: "abc_123" });
  });

  it("rejects oversized queries and invalid city IDs", () => {
    expect(discoveryQuerySchema.safeParse({ q: "x".repeat(81) }).success).toBe(false);
    expect(discoveryQuerySchema.safeParse({ city: "São Lourenço" }).success).toBe(false);
  });
});
