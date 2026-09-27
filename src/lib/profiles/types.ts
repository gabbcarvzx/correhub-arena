import type {
  PREFERRED_DISTANCES,
  RUNNING_LEVELS,
} from "@/lib/validations/profile";

export type ProfileVisibility = "self" | "public" | "private";
export type RunningLevel = (typeof RUNNING_LEVELS)[number];
export type PreferredDistance = (typeof PREFERRED_DISTANCES)[number];

export type ProfileCity = {
  id: string;
  name: string;
  slug: string;
  countryCode: string;
  stateCode: string;
};

export type ProfilePresentation = {
  id: string;
  username: string;
  fullName: string;
  avatarUrl: string | null;
  bio: string | null;
  city: ProfileCity | null;
  runningLevel: RunningLevel | null;
  preferredDistance: PreferredDistance | null;
  paceSecondsPerKm: number | null;
  visibility: ProfileVisibility;
  createdAt: string;
};

export type ProfileCursor = { username: string; id: string };
export type ConnectionDirection = "followers" | "following";

export type CursorPage<T> = {
  items: T[];
  nextCursor: string | null;
};

export type DiscoveryInput = {
  query?: string | null;
  cityId?: string | null;
  cursor?: string | null;
};

export type ConnectionInput = {
  username: string;
  direction: ConnectionDirection;
  cursor?: string | null;
};
