const SYNTHETIC_ORIGIN = "https://correhub.internal";
const LOOP_PATHS = [
  "/login",
  "/auth/callback",
  "/auth/auth-code-error",
  "/logout",
  "/onboarding",
  "/account-unavailable",
] as const;

function isLoopPath(pathname: string): boolean {
  return LOOP_PATHS.some((path) => pathname === path || pathname.startsWith(`${path}/`));
}

function normalizeInternalPath(input: unknown): string | null {
  if (typeof input !== "string" || !input.startsWith("/") || input.startsWith("//")) {
    return null;
  }

  if (
    input.includes("\\") ||
    /[\u0000-\u001f\u007f]/.test(input) ||
    /%(?![0-9a-f]{2})/i.test(input) ||
    /%(?:2f|5c|25)/i.test(input)
  ) {
    return null;
  }

  let decoded: string;
  try {
    decoded = decodeURIComponent(input);
  } catch {
    return null;
  }

  if (
    decoded.startsWith("//") ||
    decoded.includes("\\") ||
    /[\u0000-\u001f\u007f]/.test(decoded) ||
    /%(?:2f|5c|25)/i.test(decoded)
  ) {
    return null;
  }

  try {
    const url = new URL(input, SYNTHETIC_ORIGIN);
    const decodedUrl = new URL(decoded, SYNTHETIC_ORIGIN);

    if (
      url.origin !== SYNTHETIC_ORIGIN ||
      decodedUrl.origin !== SYNTHETIC_ORIGIN ||
      url.username ||
      url.password ||
      url.hash ||
      decodedUrl.hash ||
      !url.pathname.startsWith("/") ||
      url.pathname.startsWith("//") ||
      isLoopPath(url.pathname) ||
      isLoopPath(decodedUrl.pathname)
    ) {
      return null;
    }

    return `${url.pathname}${url.search}`;
  } catch {
    return null;
  }
}

export function sanitizeInternalReturnTo(input: unknown, fallback = "/"): string {
  return normalizeInternalPath(input) ?? normalizeInternalPath(fallback) ?? "/";
}
