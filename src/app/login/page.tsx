import { redirect } from "next/navigation";

import { getCurrentAccountState } from "@/lib/auth/current-account";
import { resolveAuthRouteState } from "@/lib/auth/route-state";
import { sanitizeInternalReturnTo } from "@/lib/auth/return-to";

import { LoginButton } from "./login-button";

export const dynamic = "force-dynamic";

type LoginPageProps = {
  searchParams: Promise<{ returnTo?: string | string[] }>;
};

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const params = await searchParams;
  const rawReturnTo = typeof params.returnTo === "string" ? params.returnTo : "/";
  const returnTo = sanitizeInternalReturnTo(rawReturnTo);
  const state = await getCurrentAccountState();
  const decision = resolveAuthRouteState(state, "login", returnTo);

  if (decision.action === "redirect") {
    redirect(decision.destination);
  }

  return (
    <main className="foundation-shell">
      <section className="foundation-card" aria-labelledby="login-title">
        <p className="foundation-kicker">CorreHub</p>
        <h1 className="foundation-title" id="login-title">
          Entre no CorreHub
        </h1>
        <p className="foundation-note">
          Use sua conta Google para começar com segurança.
        </p>
        {state.kind === "unavailable" ? (
          <p className="mt-6 text-sm text-destructive" role="alert">
            O acesso está temporariamente indisponível. Tente novamente mais tarde.
          </p>
        ) : (
          <LoginButton returnTo={returnTo} />
        )}
      </section>
    </main>
  );
}
