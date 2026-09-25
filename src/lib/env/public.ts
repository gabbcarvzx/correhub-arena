export type PublicEnv = {
  NEXT_PUBLIC_SUPABASE_URL: string;
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: string;
  NEXT_PUBLIC_SITE_URL: string;
};

type EnvSource = Record<string, string | undefined>;

function invalid(name: keyof PublicEnv): never {
  throw new Error(`Invalid or missing environment variable: ${name}`);
}

function readUrl(
  source: EnvSource,
  name: "NEXT_PUBLIC_SUPABASE_URL" | "NEXT_PUBLIC_SITE_URL",
): string {
  const value = source[name];

  if (!value) {
    return invalid(name);
  }

  try {
    const url = new URL(value);
    const localHost = url.hostname === "localhost" || url.hostname === "127.0.0.1";
    const secureProtocol = url.protocol === "https:" || (url.protocol === "http:" && localHost);

    if (
      !secureProtocol ||
      url.username ||
      url.password ||
      url.search ||
      url.hash ||
      url.pathname !== "/"
    ) {
      return invalid(name);
    }

    return value;
  } catch {
    return invalid(name);
  }
}

export function readPublicEnv(source: EnvSource = process.env): PublicEnv {
  const publishableKey = source.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

  if (!publishableKey || !/^sb_publishable_[A-Za-z0-9_-]+$/.test(publishableKey)) {
    return invalid("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY");
  }

  return {
    NEXT_PUBLIC_SUPABASE_URL: readUrl(source, "NEXT_PUBLIC_SUPABASE_URL"),
    NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: publishableKey,
    NEXT_PUBLIC_SITE_URL: readUrl(source, "NEXT_PUBLIC_SITE_URL"),
  };
}
