import { readPublicEnv } from "@/lib/env/public";

import { sanitizeInternalReturnTo } from "./return-to";

function invalidOrigin(): never {
  throw new Error("Invalid or missing environment variable: NEXT_PUBLIC_SITE_URL");
}

export function getConfiguredAppOrigin(value?: string): string {
  const configured = value ?? readPublicEnv().NEXT_PUBLIC_SITE_URL;

  try {
    const url = new URL(configured);
    const isLocal = url.origin === "http://localhost:3000";

    if (
      (url.protocol !== "https:" && !isLocal) ||
      url.username ||
      url.password ||
      url.pathname !== "/" ||
      url.search ||
      url.hash
    ) {
      return invalidOrigin();
    }

    return url.origin;
  } catch {
    return invalidOrigin();
  }
}

export function buildAuthCallbackUrl(returnTo: unknown, configuredOrigin?: string): string {
  const callback = new URL("/auth/callback", getConfiguredAppOrigin(configuredOrigin));
  callback.searchParams.set("returnTo", sanitizeInternalReturnTo(returnTo));
  return callback.toString();
}
