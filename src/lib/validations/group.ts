import { z } from "zod";

export const GROUP_TYPES = ["community", "professional"] as const;
export const GROUP_JOIN_POLICIES = ["open", "approval_required"] as const;
export const GROUP_STATUSES = ["pending", "approved", "rejected", "suspended"] as const;
export const GROUP_MEMBER_ROLES = ["member", "admin", "owner"] as const;
export const GROUP_MEMBER_STATUSES = ["pending", "active", "blocked"] as const;

export const groupSlugSchema = z
  .string()
  .trim()
  .toLowerCase()
  .min(3, "Use de 3 a 100 caracteres")
  .max(100, "Use de 3 a 100 caracteres")
  .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, "Use letras minúsculas, números e hífens");

export const groupRequestSchema = z
  .object({
    name: z.string().trim().min(3, "Informe um nome com pelo menos 3 caracteres").max(100),
    slug: groupSlugSchema,
    description: z.string().trim().min(1, "Conte um pouco sobre o grupo").max(2000),
    city_id: z.uuid("Selecione uma cidade válida"),
    group_type: z.enum(GROUP_TYPES, { error: "Selecione um tipo de grupo" }),
    join_policy: z.enum(GROUP_JOIN_POLICIES, { error: "Selecione como as pessoas entram" }),
  })
  .strict();

export const groupReasonSchema = z.string().trim().min(3, "Explique o motivo").max(1000);
export const groupActionSchema = z.object({ groupId: z.uuid() }).strict();
export const groupMemberActionSchema = z
  .object({ groupId: z.uuid(), userId: z.uuid() })
  .strict();
export const groupTransferActionSchema = z
  .object({ transferId: z.uuid() })
  .strict();
export const groupFollowActionSchema = z
  .object({ groupId: z.uuid(), slug: groupSlugSchema })
  .strict();

export type GroupRequestInput = z.input<typeof groupRequestSchema>;
export type GroupRequestData = z.output<typeof groupRequestSchema>;
