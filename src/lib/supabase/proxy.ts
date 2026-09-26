import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

import { readPublicEnv } from "@/lib/env/public";
import type { Database } from "@/types/database";

function requestHasAuthCookie(request: NextRequest): boolean {
  return request.cookies.getAll().some(({ name }) => name.startsWith("sb-") && name.includes("auth-token"));
}

export async function updateSession(request: NextRequest): Promise<NextResponse> {
  const env = readPublicEnv();
  let response = NextResponse.next({ request });
  let wroteCookies = false;

  const supabase = createServerClient<Database>(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          wroteCookies = cookiesToSet.length > 0;
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) => {
            response.cookies.set(name, value, options);
          });
        },
      },
    },
  );

  try {
    await supabase.auth.getClaims();
  } catch {
    // Invalid or expired refresh state is treated as anonymous by point-of-use checks.
  }

  if (wroteCookies || requestHasAuthCookie(request)) {
    response.headers.set("Cache-Control", "private, no-store");
  }

  return response;
}
