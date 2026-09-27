import type { z } from "zod";

import { profileEditSchema } from "./profile";

export {
  DISTANCE_LABELS,
  PREFERRED_DISTANCES,
  RUNNING_LEVEL_LABELS,
  RUNNING_LEVELS,
} from "./profile";

export const onboardingSchema = profileEditSchema;

export type OnboardingFormInput = z.input<typeof onboardingSchema>;
export type OnboardingData = z.output<typeof onboardingSchema>;
