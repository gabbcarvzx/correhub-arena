import Link from "next/link";

import { logoutAction } from "./actions";

export default function LogoutPage() {
  return (
    <main className="foundation-shell">
      <section className="foundation-card" aria-labelledby="logout-title">
        <p className="foundation-kicker">CorreHub</p>
        <h1 className="foundation-title" id="logout-title">
          Sair do CorreHub
        </h1>
        <p className="foundation-note">
          Confirme para encerrar sua sessão neste dispositivo.
        </p>
        <div className="mt-6 flex flex-wrap gap-3">
          <form action={logoutAction}>
            <button
              className="min-h-11 rounded-full bg-primary px-5 py-3 font-bold text-on-primary transition-colors hover:bg-primary-hover"
              type="submit"
            >
              Sair da conta
            </button>
          </form>
          <Link
            className="inline-flex min-h-11 items-center rounded-full border border-border px-5 py-3 font-semibold text-foreground"
            href="/"
          >
            Cancelar
          </Link>
        </div>
      </section>
    </main>
  );
}
