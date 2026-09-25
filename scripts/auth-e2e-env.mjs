export const LOCAL_SUPABASE_URL = "http://127.0.0.1:54321";

const SECRET_NAME = /(SECRET|TOKEN|PASSWORD|SERVICE_ROLE|PRIVATE_KEY|DATABASE_URL|SUPABASE_DB)/i;

export function validateLocalSupabaseStatus(status) {
  const url = status.API_URL ?? status.SUPABASE_URL;
  const publishableKey = status.PUBLISHABLE_KEY ?? status.ANON_KEY;
  const serviceRoleKey = status.SERVICE_ROLE_KEY;

  if (url !== LOCAL_SUPABASE_URL) {
    throw new Error(`Auth E2E requires local Supabase at ${LOCAL_SUPABASE_URL}`);
  }
  if (!publishableKey || !serviceRoleKey) {
    throw new Error("Auth E2E could not resolve the local Supabase keys");
  }

  return { url, publishableKey, serviceRoleKey };
}

export function buildNextEnvironment(status, inheritedEnvironment = process.env) {
  const { url, publishableKey, serviceRoleKey } = validateLocalSupabaseStatus(status);
  const environment = Object.fromEntries(
    Object.entries(inheritedEnvironment).filter(([name, value]) => value !== undefined && !SECRET_NAME.test(name)),
  );

  environment.NEXT_PUBLIC_SUPABASE_URL = url;
  environment.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY = publishableKey;
  environment.NEXT_PUBLIC_SITE_URL = "http://localhost:3000";

  if (Object.values(environment).includes(serviceRoleKey)) {
    throw new Error("Local service role key reached the Next environment");
  }

  return environment;
}
