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

if (localUrl !== "http://127.0.0.1:54321") {
  throw new Error("Local Auth fixtures require the isolated Supabase test environment");
}

const admin = createClient(localUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

type StoredCookie = { name: string; value: string; options: CookieOptions };

export type LocalIdentity = {
  id: string;
  email: string;
  cookies: StoredCookie[];
  accessToken: string;
  refreshToken: string;
};

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
