import Link from "next/link";

import { getCurrentAccountState } from "@/lib/auth/current-account";

export const dynamic = "force-dynamic";

export default async function Home() {
  const state = await getCurrentAccountState();

  return (
    <main className="foundation-shell">
      <section className="foundation-card" aria-labelledby="foundation-title">
        <p className="foundation-kicker">Fundação</p>
        <h1 className="foundation-title" id="foundation-title">CorreHub</h1>
        <p className="foundation-status" role="status">Em desenvolvimento</p>
        <p className="foundation-note">
          Uma base simples para construir encontros de corrida locais com cuidado.
        </p>
        <nav className="mt-6 flex flex-wrap gap-3" aria-label="Acesso">
          <Link
            className="inline-flex min-h-11 items-center rounded-full border border-border px-5 py-3 font-semibold text-foreground"
            href="/people"
          >
            Descobrir
          </Link>
          {state.kind === "anonymous" ? (
            <Link
              className="inline-flex min-h-11 items-center rounded-full bg-primary px-5 py-3 font-bold text-on-primary transition-colors hover:bg-primary-hover"
              href="/login"
            >
              Entrar com Google
            </Link>
          ) : null}
          {state.kind === "active" && !state.onboardingCompleted ? (
            <Link
              className="inline-flex min-h-11 items-center rounded-full bg-primary px-5 py-3 font-bold text-on-primary transition-colors hover:bg-primary-hover"
              href="/onboarding"
            >
              Continuar cadastro
            </Link>
          ) : null}
          {state.kind === "active" && state.onboardingCompleted ? (
            <Link
              className="inline-flex min-h-11 items-center rounded-full bg-primary px-5 py-3 font-bold text-on-primary transition-colors hover:bg-primary-hover"
              href="/me"
            >
              Perfil
            </Link>
          ) : null}
          {state.kind === "active" || state.kind === "suspended" || state.kind === "deleted" ? (
            <Link
              className="inline-flex min-h-11 items-center rounded-full border border-border px-5 py-3 font-semibold text-foreground"
              href="/logout"
            >
              Sair
            </Link>
          ) : null}
          {state.kind === "unavailable" ? (
            <Link
              className="inline-flex min-h-11 items-center rounded-full border border-border px-5 py-3 font-semibold text-foreground"
              href="/account-unavailable"
            >
              Verificar acesso
            </Link>
          ) : null}
        </nav>
      </section>
    </main>
  );
}
