import { describe, expect, it } from "vitest";

import {
  groupActionSchema,
  groupReasonSchema,
  groupRequestSchema,
} from "./group";

const valid = {
  name: "  Corre Recife  ",
  slug: "CORRE-RECIFE",
  description: "  Treinos em comunidade.  ",
  city_id: "10000000-0000-4000-8000-000000000001",
  group_type: "community",
  join_policy: "approval_required",
};

describe("group validation", () => {
  it("normalizes the form contract without accepting authority fields", () => {
    expect(groupRequestSchema.parse(valid)).toEqual({
      ...valid,
      name: "Corre Recife",
      slug: "corre-recife",
      description: "Treinos em comunidade.",
    });
    expect(groupRequestSchema.safeParse({ ...valid, status: "approved" }).success).toBe(false);
    expect(groupRequestSchema.safeParse({ ...valid, owner_user_id: crypto.randomUUID() }).success).toBe(false);
  });

  it("enforces slug, enums, text and reason boundaries", () => {
    expect(groupRequestSchema.safeParse({ ...valid, slug: "gr" }).success).toBe(false);
    expect(groupRequestSchema.safeParse({ ...valid, slug: "grupo/invalido" }).success).toBe(false);
    expect(groupRequestSchema.safeParse({ ...valid, group_type: "paid" }).success).toBe(false);
    expect(groupRequestSchema.safeParse({ ...valid, join_policy: "invite" }).success).toBe(false);
    expect(groupReasonSchema.safeParse("no").success).toBe(false);
    expect(groupReasonSchema.parse("  Dados insuficientes.  ")).toBe("Dados insuficientes.");
  });

  it("accepts only the target identifiers required by an action", () => {
    const groupId = crypto.randomUUID();
    expect(groupActionSchema.parse({ groupId })).toEqual({ groupId });
    expect(groupActionSchema.safeParse({ groupId, actorId: crypto.randomUUID() }).success).toBe(false);
  });
});
