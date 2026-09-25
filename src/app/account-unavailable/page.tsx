import Link from "next/link";
import { redirect } from "next/navigation";

import { getCurrentAccountState } from "@/lib/auth/current-account";
import { resolveAuthRouteState } from "@/lib/auth/route-state";

export const dynamic = "force-dynamic";

export default async function AccountUnavailablePage() {
  const state = await getCurrentAccountState();
  const decision = resolveAuthRouteState(state, "account-unavailable");

  if (decision.action === "redirect") {
    redirect(decision.destination);
  }

  return (
    <main className="foundation-shell">
      <section className="foundation-card" aria-labelledby="account-unavailable-title">
        <p className="foundation-kicker">CorreHub</p>
        <h1 className="foundation-title" id="account-unavailable-title">
          Conta indisponível
        </h1>
        <p className="foundation-note">
          Não foi possível liberar o acesso a esta conta. Você pode sair e tentar novamente mais tarde.
        </p>
        <Link
          className="mt-6 inline-flex min-h-11 items-center rounded-full bg-primary px-5 py-3 font-bold text-on-primary"
          href="/logout"
        >
          Sair da conta
        </Link>
      </section>
    </main>
  );
}
