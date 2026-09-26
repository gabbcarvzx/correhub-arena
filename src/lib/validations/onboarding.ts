import { z } from "zod";

export const RUNNING_LEVELS = ["beginner", "intermediate", "advanced"] as const;
export const PREFERRED_DISTANCES = [
  "up_to_5k",
  "5k_to_10k",
  "10k_to_21k",
  "over_21k",
  "flexible",
] as const;

export const RUNNING_LEVEL_LABELS: Record<(typeof RUNNING_LEVELS)[number], string> = {
  beginner: "Iniciante",
  intermediate: "Intermediário",
  advanced: "Avançado",
};

export const DISTANCE_LABELS: Record<(typeof PREFERRED_DISTANCES)[number], string> = {
  up_to_5k: "Até 5 km",
  "5k_to_10k": "De 5 a 10 km",
  "10k_to_21k": "De 10 a 21 km",
  over_21k: "Mais de 21 km",
  flexible: "Flexível",
};

const paceSchema = z
  .string()
  .transform((value) => value.trim())
  .superRefine((value, context) => {
    if (!value) {
      return;
    }

    const match = /^(\d{1,2}):(\d{2})$/.exec(value);
    const seconds = match ? Number(match[1]) * 60 + Number(match[2]) : 0;
    if (!match || Number(match[2]) > 59 || seconds < 120 || seconds > 1800) {
      context.addIssue({
        code: "custom",
        message: "Pace deve estar entre 2:00 e 30:00 min/km",
      });
    }
  });

export const onboardingSchema = z
  .object({
    username: z
      .string()
      .trim()
      .toLowerCase()
      .min(3, "Use de 3 a 30 caracteres")
      .max(30, "Use de 3 a 30 caracteres")
      .regex(/^[a-z0-9_]+$/, "Use apenas letras minúsculas, números e _"),
    full_name: z
      .string()
      .trim()
      .min(2, "Informe um nome com pelo menos 2 caracteres")
      .max(80, "Use no máximo 80 caracteres"),
    city_id: z.uuid("Selecione uma cidade válida"),
    running_level: z.enum(RUNNING_LEVELS, { error: "Selecione seu nível de corrida" }),
    preferred_distance: z.enum(PREFERRED_DISTANCES, {
      error: "Selecione sua distância preferida",
    }),
    bio: z
      .string()
      .transform((value) => value.trim())
      .refine((value) => value.length <= 300, "Use no máximo 300 caracteres"),
    pace: paceSchema,
    is_private: z.boolean(),
  })
  .transform(({ pace, bio, ...values }) => {
    const paceMatch = /^(\d{1,2}):(\d{2})$/.exec(pace);
    return {
      ...values,
      bio: bio || null,
      pace_seconds_per_km: paceMatch
        ? Number(paceMatch[1]) * 60 + Number(paceMatch[2])
        : null,
    };
  });

export type OnboardingFormInput = z.input<typeof onboardingSchema>;
export type OnboardingData = z.output<typeof onboardingSchema>;
