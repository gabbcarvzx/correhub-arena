import type { Browser, Cookie } from "@playwright/test";
import { createServerClient, type CookieOptions } from "@supabase/ssr";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { randomBytes } from "node:crypto";
import { spawnSync } from "node:child_process";

function requiredEnvironment(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing local Auth fixture environment: ${name}`);
  }
  return value;
}

const localUrl = requiredEnvironment("NEXT_PUBLIC_SUPABASE_URL");
const publishableKey = requiredEnvironment("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY");
const serviceRoleKey = requiredEnvironment("LOCAL_SUPABASE_SERVICE_ROLE_KEY");
const secretKey = requiredEnvironment("SUPABASE_SECRET_KEY");

if (localUrl !== "http://127.0.0.1:54321") {
  throw new Error("Local Auth fixtures require the isolated Supabase test environment");
}

const admin = createClient(localUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});
const storageAdmin = createClient(localUrl, secretKey, { auth: { autoRefreshToken: false, persistSession: false } });

type StoredCookie = { name: string; value: string; options: CookieOptions };

export type LocalIdentity = {
  id: string;
  email: string;
  cookies: StoredCookie[];
  accessToken: string;
  refreshToken: string;
};

export const launchCityId = "10000000-0000-4000-8000-000000000001";

export async function completeLocalProfile(
  identity: LocalIdentity,
  input: {
    username: string;
    fullName: string;
    isPrivate?: boolean;
    bio?: string;
  },
) {
  const client = createClient(localUrl, publishableKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { error: sessionError } = await client.auth.setSession({
    access_token: identity.accessToken,
    refresh_token: identity.refreshToken,
  });
  if (sessionError) {
    throw new Error("Could not prepare local profile fixture session");
  }
  const { error } = await client
    .from("profiles")
    .update({
      username: input.username,
      full_name: input.fullName,
      city_id: launchCityId,
      running_level: "beginner",
      preferred_distance: "up_to_5k",
      bio: input.bio ?? null,
      pace_seconds_per_km: 390,
      is_private: input.isPrivate ?? false,
      onboarding_completed: true,
    })
    .eq("id", identity.id);
  if (error) {
    throw new Error(`Could not complete local profile fixture: ${error.code ?? "unknown"}`);
  }
}

export async function attemptCrossUserProfileUpdate(
  actor: LocalIdentity,
  targetUserId: string,
) {
  const client = createClient(localUrl, publishableKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { error: sessionError } = await client.auth.setSession({
    access_token: actor.accessToken,
    refresh_token: actor.refreshToken,
  });
  if (sessionError) throw new Error("Could not prepare local cross-user fixture session");
  return client.from("profiles").update({ full_name: "Cross-user mutation" }).eq("id", targetUserId).select("id");
}

export async function createLocalIdentity(label: string): Promise<LocalIdentity> {
  const suffix = `${Date.now()}-${randomBytes(5).toString("hex")}`;
  const email = `correhub-${label}-${suffix}@example.test`;
  const { data, error } = await admin.auth.admin.createUser({
    email,
    email_confirm: true,
    user_metadata: { full_name: `Corredor ${label}` },
  });
  if (error || !data.user) {
    throw new Error(`Could not create local Auth identity: ${error?.code ?? "unknown"}`);
  }

  const jar = new Map<string, StoredCookie>();
  const client = createServerClient(localUrl, publishableKey, {
    cookies: {
      getAll: () => [...jar.values()],
      setAll: (cookies: StoredCookie[]) => {
        for (const cookie of cookies) {
          jar.set(cookie.name, cookie);
        }
      },
    },
  });
  const { data: linkData, error: linkError } = await admin.auth.admin.generateLink({
    type: "magiclink",
    email,
  });
  if (linkError || !linkData.properties.hashed_token) {
    await admin.auth.admin.deleteUser(data.user.id);
    throw new Error(`Could not create local test verification: ${linkError?.code ?? "unknown"}`);
  }
  const { data: signInData, error: signInError } = await client.auth.verifyOtp({
    type: "magiclink",
    token_hash: linkData.properties.hashed_token,
  });
  if (signInError || !signInData.session) {
    await admin.auth.admin.deleteUser(data.user.id);
    throw new Error(`Could not create local SSR session: ${signInError?.code ?? "unknown"}`);
  }

  return {
    id: data.user.id,
    email,
    cookies: [...jar.values()],
    accessToken: signInData.session.access_token,
    refreshToken: signInData.session.refresh_token,
  };
}

export async function attemptPublicEmailSignup() {
  const client = createClient(localUrl, publishableKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const result = await client.auth.signUp({
    email: `correhub-public-signup-${Date.now()}-${randomBytes(4).toString("hex")}@example.test`,
    password: randomBytes(24).toString("base64url"),
  });
  if (result.data.user) {
    await admin.auth.admin.deleteUser(result.data.user.id);
  }
  return result;
}

function sameSite(value: CookieOptions["sameSite"]): Cookie["sameSite"] {
  if (value === true || value === "strict") return "Strict";
  if (value === "none") return "None";
  return "Lax";
}

export async function authenticatedContext(browser: Browser, identity: LocalIdentity) {
  const context = await browser.newContext();
  await addStoredCookies(context, identity.cookies);
  return context;
}

async function addStoredCookies(
  context: Awaited<ReturnType<Browser["newContext"]>>,
  cookies: StoredCookie[],
) {
  const activeCookies = cookies.filter(
    ({ value, options }) => value && !(typeof options.maxAge === "number" && options.maxAge <= 0),
  );
  if (activeCookies.length === 0) {
    return;
  }
  await context.addCookies(
    activeCookies.map(({ name, value, options }) => ({
      name,
      value,
      url: "http://localhost:3000",
      httpOnly: options.httpOnly ?? false,
      secure: options.secure ?? false,
      sameSite: sameSite(options.sameSite),
      expires:
        typeof options.maxAge === "number"
          ? Math.floor(Date.now() / 1000) + options.maxAge
          : undefined,
    })),
  );
}

export async function removeLocalIdentity(identity: LocalIdentity) {
  const { error } = await admin.auth.admin.deleteUser(identity.id);
  if (error && error.status !== 404) {
    throw new Error(`Could not remove local Auth identity: ${error.code ?? "unknown"}`);
  }
}

export function setLocalAccountStatus(identity: LocalIdentity, status: "active" | "suspended") {
  if (!/^[0-9a-f-]{36}$/i.test(identity.id)) {
    throw new Error("Fixture identity is not a UUID");
  }
  const sql = `update private.account_controls set status='${status}' where user_id='${identity.id}'::uuid;`;
  const result = spawnSync(
    "docker",
    ["exec", "supabase_db_correhub", "psql", "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1", "-c", sql],
    { encoding: "utf8", windowsHide: true },
  );
  if (result.status !== 0) {
    throw new Error("Could not set the local account fixture status");
  }
}

function fixtureSql(sql: string, errorMessage: string) {
  const result = spawnSync(
    "docker",
    ["exec", "supabase_db_correhub", "psql", "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1", "-c", sql],
    { encoding: "utf8", windowsHide: true },
  );
  if (result.status !== 0) throw new Error(errorMessage);
}

function fixtureSqlValue(sql: string, errorMessage: string) {
  const result = spawnSync(
    "docker",
    ["exec", "supabase_db_correhub", "psql", "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1", "-tA", "-F", "|", "-c", sql],
    { encoding: "utf8", windowsHide: true },
  );
  if (result.status !== 0) throw new Error(errorMessage);
  return result.stdout.trim();
}

export function setLocalPlatformRole(identity: LocalIdentity, role: "platform_admin" | "moderator") {
  if (!/^[0-9a-f-]{36}$/i.test(identity.id)) throw new Error("Fixture identity is not a UUID");
  fixtureSql(`insert into private.platform_roles(user_id,role) values ('${identity.id}'::uuid,'${role}') on conflict(user_id,role) do nothing;`, "Could not set the local platform role");
}

function identityClient(identity: LocalIdentity) {
  const client = createClient(localUrl, publishableKey, { auth: { autoRefreshToken: false, persistSession: false } });
  return client.auth.setSession({ access_token: identity.accessToken, refresh_token: identity.refreshToken }).then(({ error }) => {
    if (error) throw new Error("Could not prepare local group fixture session");
    return client;
  });
}

export async function localGroupRpc(identity: LocalIdentity, name: string, args: Record<string, unknown>, options: { allowError?: boolean } = {}) {
  const client = await identityClient(identity);
  const result = await client.rpc(name as never, args as never);
  if (result.error && !options.allowError) throw new Error(`Local group RPC failed: ${result.error.code ?? "unknown"}`);
  return result as { data: unknown; error: { code?: string; message?: string } | null };
}

export async function createLocalGroup(identity: LocalIdentity, input: { slug: string; joinPolicy: "open" | "approval_required" }) {
  const result = await localGroupRpc(identity, "request_group", {
    requested_name: `Grupo ${input.slug.slice(0, 24)}`, requested_slug: input.slug,
    requested_description: "Comunidade local de corrida criada para teste determinístico.", requested_city_id: launchCityId,
    requested_type: "community", requested_join_policy: input.joinPolicy,
  });
  return { id: result.data as string, slug: input.slug };
}

export async function getLocalGroupBySlug(slug: string) {
  if (!/^[a-z0-9-]{3,100}$/.test(slug)) throw new Error("Fixture slug is invalid");
  const output = fixtureSqlValue(`select id::text||'|'||slug||'|'||status from public.groups where slug='${slug}';`, "Could not read local group fixture");
  const [id, storedSlug, status] = output.split("|");
  if (!id || !storedSlug || !status) throw new Error("Could not read local group fixture");
  return { id, slug: storedSlug, status };
}

export async function getLocalGroupRelation(groupId: string, userId: string) {
  if (![groupId,userId].every((id)=>/^[0-9a-f-]{36}$/i.test(id))) throw new Error("Fixture relation IDs are invalid");
  const output = fixtureSqlValue(`select role||'|'||status from public.group_members where group_id='${groupId}'::uuid and user_id='${userId}'::uuid;`, "Could not read local group relation");
  if (!output) return null;
  const [role,status]=output.split("|"); return {role,status};
}

export async function removeLocalGroups(identities: LocalIdentity[]) {
  const ids = identities.map(({ id }) => id);
  if (!ids.length) return;
  if (ids.some((id) => !/^[0-9a-f-]{36}$/i.test(id))) throw new Error("Fixture identity is not a UUID");
  const actors=ids.map((id) => `'${id}'::uuid`).join(",");
  const groups=`select id from public.groups where created_by in (${actors})`;
  const objectPaths=fixtureSqlValue(`select object_path from private.media_uploads where target_type in ('group_avatar','group_cover') and target_id in (${groups}) and object_path is not null;`,"Could not read local media fixtures").split(/\r?\n/).filter(Boolean);
  if(objectPaths.length){const {error}=await storageAdmin.storage.from("group-media").remove(objectPaths);if(error)throw new Error("Could not remove local media objects");}
  fixtureSql(`delete from private.media_uploads where target_type in ('group_avatar','group_cover') and target_id in (${groups}); delete from public.activity_events where group_id in (${groups}) or (entity_type='group' and entity_id in (${groups})); delete from public.notifications where target_type='group' and target_id in (${groups}); delete from private.analytics_events where entity_type='group' and entity_id in (${groups}); delete from private.admin_audit_logs where target_type='group' and target_id in (${groups}); delete from private.domain_event_receipts where entity_type='group' and entity_id in (${groups}); delete from public.groups where created_by in (${actors});`, "Could not remove local group fixtures");
}

export async function tryDirectGroupMediaUpload(identity: LocalIdentity, groupId: string) {
  const client = await identityClient(identity);
  return client.storage.from("group-media").upload(`${groupId}/avatar/direct.webp`, new Uint8Array([1, 2, 3]), { contentType: "image/webp", upsert: false });
}

export function expireLocalOwnerTransfer(groupId: string) {
  if (!/^[0-9a-f-]{36}$/i.test(groupId)) throw new Error("Fixture group is not a UUID");
  fixtureSql(`update private.group_owner_transfers set created_at=pg_catalog.now()-interval '9 days' where group_id='${groupId}'::uuid and status='accepted'; update private.group_owner_transfers set created_at=pg_catalog.now()-interval '8 days',expires_at=pg_catalog.now()-interval '1 day' where group_id='${groupId}'::uuid and status='pending';`, "Could not expire local ownership transfer");
}

export async function applyRevokedRefreshState(
  context: Awaited<ReturnType<Browser["newContext"]>>,
  identity: LocalIdentity,
) {
  const { error: revokeError } = await admin.auth.admin.signOut(identity.accessToken, "global");
  if (revokeError) {
    throw new Error(`Could not revoke the local session: ${revokeError.code ?? "unknown"}`);
  }

  const jar = new Map(identity.cookies.map((cookie) => [cookie.name, cookie]));
  const sessionClient: SupabaseClient = createServerClient(localUrl, publishableKey, {
    cookies: {
      getAll: () => [...jar.values()],
      setAll: (cookies: StoredCookie[]) => {
        for (const cookie of cookies) {
          jar.set(cookie.name, cookie);
        }
      },
    },
  });
  const { error } = await sessionClient.auth.refreshSession({ refresh_token: identity.refreshToken });
  if (!error) {
    throw new Error("Revoked local refresh unexpectedly succeeded");
  }

  await sessionClient.auth.signOut({ scope: "local" });

  await context.clearCookies();
  await addStoredCookies(context, [...jar.values()]);
}
