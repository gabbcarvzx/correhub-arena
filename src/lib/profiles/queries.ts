import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";

import { getCurrentAccountState } from "@/lib/auth/current-account";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import {
  PREFERRED_DISTANCES,
  RUNNING_LEVELS,
  connectionDirectionSchema,
  discoveryQuerySchema,
  profileUsernameSchema,
} from "@/lib/validations/profile";
import type { Database } from "@/types/database";

import { decodeProfileCursor, encodeProfileCursor } from "./cursor";
import type {
  ConnectionInput,
  CursorPage,
  DiscoveryInput,
  PreferredDistance,
  ProfilePresentation,
  ProfileVisibility,
  RunningLevel,
} from "./types";

type AppSupabaseClient = SupabaseClient<Database>;
type RawProfileRow = Record<string, unknown>;

export type ProfileQueryErrorCode = "validation_error" | "temporary_error";

export class ProfileQueryError extends Error {
  constructor(public readonly code: ProfileQueryErrorCode) {
    super(
      code === "validation_error"
        ? "Os filtros informados são inválidos."
        : "Não foi possível carregar os perfis agora.",
    );
    this.name = "ProfileQueryError";
  }
}

async function resolveClient(client?: AppSupabaseClient): Promise<AppSupabaseClient> {
  return client ?? createServerSupabaseClient();
}

function nullableString(value: unknown): string | null {
  return typeof value === "string" ? value : null;
}

function isRunningLevel(value: unknown): value is RunningLevel {
  return typeof value === "string" && RUNNING_LEVELS.includes(value as RunningLevel);
}

function isPreferredDistance(value: unknown): value is PreferredDistance {
  return (
    typeof value === "string" &&
    PREFERRED_DISTANCES.includes(value as PreferredDistance)
  );
}

function isVisibility(value: unknown): value is ProfileVisibility {
  return value === "self" || value === "public" || value === "private";
}

export function mapProfileRow(input: unknown): ProfilePresentation {
  const row = input as RawProfileRow;
  if (
    !row ||
    typeof row.id !== "string" ||
    typeof row.username !== "string" ||
    typeof row.full_name !== "string" ||
    typeof row.created_at !== "string" ||
    !isVisibility(row.visibility)
  ) {
    throw new ProfileQueryError("temporary_error");
  }

  const city =
    typeof row.city_id === "string" &&
    typeof row.city_name === "string" &&
    typeof row.city_slug === "string" &&
    typeof row.country_code === "string" &&
    typeof row.state_code === "string"
      ? {
          id: row.city_id,
          name: row.city_name,
          slug: row.city_slug,
          countryCode: row.country_code,
          stateCode: row.state_code,
        }
      : null;

  return {
    id: row.id,
    username: row.username,
    fullName: row.full_name,
    avatarUrl: nullableString(row.avatar_url),
    bio: nullableString(row.bio),
    city,
    runningLevel: isRunningLevel(row.running_level) ? row.running_level : null,
    preferredDistance: isPreferredDistance(row.preferred_distance)
      ? row.preferred_distance
      : null,
    paceSecondsPerKm:
      typeof row.pace_seconds_per_km === "number" ? row.pace_seconds_per_km : null,
    visibility: row.visibility,
    createdAt: row.created_at,
  };
}

function mapRows(rows: unknown[] | null): ProfilePresentation[] {
  try {
    return (rows ?? []).map(mapProfileRow);
  } catch (error) {
    if (error instanceof ProfileQueryError) {
      throw error;
    }
    throw new ProfileQueryError("temporary_error");
  }
}

export async function getProfileByUsername(
  username: string,
  client?: AppSupabaseClient,
): Promise<ProfilePresentation | null> {
  const parsed = profileUsernameSchema.safeParse(username);
  if (!parsed.success) {
    return null;
  }

  const supabase = await resolveClient(client);
  const { data, error } = await supabase.rpc("get_profile_by_username", {
    target_username: parsed.data,
  });
  if (error) {
    throw new ProfileQueryError("temporary_error");
  }

  const profiles = mapRows(data as unknown[] | null);
  return profiles[0] ?? null;
}

export async function getOwnProfile(
  client?: AppSupabaseClient,
): Promise<ProfilePresentation | null> {
  const supabase = await resolveClient(client);
  const state = await getCurrentAccountState(supabase);
  if (state.kind !== "active" || !state.onboardingCompleted) {
    return null;
  }

  const { data, error } = await supabase
    .from("profiles")
    .select("username")
    .eq("id", state.userId)
    .maybeSingle();
  if (error) {
    throw new ProfileQueryError("temporary_error");
  }
  if (!data?.username) {
    return null;
  }

  return getProfileByUsername(data.username, supabase);
}

export async function discoverProfiles(
  input: DiscoveryInput,
  client?: AppSupabaseClient,
): Promise<CursorPage<ProfilePresentation>> {
  const parsed = discoveryQuerySchema.safeParse({
    q: input.query ?? undefined,
    city: input.cityId ?? undefined,
    cursor: input.cursor ?? undefined,
  });
  if (!parsed.success) {
    throw new ProfileQueryError("validation_error");
  }

  const cursor = parsed.data.cursor ? decodeProfileCursor(parsed.data.cursor) : null;
  if (parsed.data.cursor && !cursor) {
    throw new ProfileQueryError("validation_error");
  }

  const supabase = await resolveClient(client);
  const { data, error } = await supabase.rpc("discover_profiles", {
    search_query: parsed.data.q,
    filter_city_id: parsed.data.city,
    after_username: cursor?.username,
    after_id: cursor?.id,
    page_size: 21,
  });
  if (error) {
    throw new ProfileQueryError("temporary_error");
  }

  const rows = mapRows(data as unknown[] | null);
  const items = rows.slice(0, 20);
  const last = rows.length > 20 ? items.at(-1) : null;
  return {
    items,
    nextCursor: last ? encodeProfileCursor({ username: last.username, id: last.id }) : null,
  };
}

export async function listProfileConnections(
  input: ConnectionInput,
  client?: AppSupabaseClient,
): Promise<CursorPage<ProfilePresentation>> {
  const username = profileUsernameSchema.safeParse(input.username);
  const direction = connectionDirectionSchema.safeParse(input.direction);
  const cursor = input.cursor ? decodeProfileCursor(input.cursor) : null;
  if (!username.success || !direction.success || (input.cursor && !cursor)) {
    throw new ProfileQueryError("validation_error");
  }

  const supabase = await resolveClient(client);
  const { data, error } = await supabase.rpc("list_profile_connections", {
    target_username: username.data,
    connection_direction: direction.data,
    after_username: cursor?.username,
    after_id: cursor?.id,
    page_size: 20,
  });
  if (error) {
    throw new ProfileQueryError("temporary_error");
  }

  const items = mapRows(data as unknown[] | null);
  const last = items.length === 20 ? items.at(-1) : null;
  return {
    items,
    nextCursor: last ? encodeProfileCursor({ username: last.username, id: last.id }) : null,
  };
}
