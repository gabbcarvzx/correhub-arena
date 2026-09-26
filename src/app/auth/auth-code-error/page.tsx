import Link from "next/link";

export default function AuthCodeErrorPage() {
  return (
    <main className="foundation-shell">
      <section className="foundation-card" aria-labelledby="auth-error-title">
        <p className="foundation-kicker">CorreHub</p>
        <h1 className="foundation-title" id="auth-error-title">
          Não foi possível entrar
        </h1>
        <p className="foundation-note">
          O acesso não foi concluído. Inicie novamente quando estiver pronto.
        </p>
        <Link
          className="mt-6 inline-flex min-h-11 items-center rounded-full bg-primary px-5 py-3 font-bold text-on-primary"
          href="/login"
        >
          Tentar novamente
        </Link>
      </section>
    </main>
  );
}
