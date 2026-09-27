import Link from "next/link";
import { notFound, redirect } from "next/navigation";

import { GroupReviewQueue } from "@/components/groups/group-review";
import { getCurrentAccountState } from "@/lib/auth/current-account";
import { canReviewGroups, listGroupReviewQueue } from "@/lib/groups/queries";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
export default async function GroupReviewQueuePage() {
  const supabase = await createServerSupabaseClient(); const state = await getCurrentAccountState(supabase);
  if (state.kind === "anonymous") redirect("/login?returnTo=%2Fadmin%2Fgrupos");
  if (state.kind !== "active" || !state.onboardingCompleted) redirect("/account-unavailable");
  if (!(await canReviewGroups(supabase))) notFound();
  const queue = await listGroupReviewQueue({}, supabase);
  return <main className="min-h-svh bg-background px-4 py-8 sm:px-6 lg:py-12"><section className="mx-auto max-w-5xl" aria-labelledby="review-queue-title"><Link className="inline-flex min-h-11 items-center font-bold text-muted hover:text-foreground" href="/">← Início</Link><p className="foundation-kicker mt-8">Administração da plataforma</p><h1 className="mt-2 text-4xl font-black tracking-tight sm:text-5xl" id="review-queue-title">Solicitações de grupos</h1><p className="mb-8 mt-3 max-w-2xl text-lg text-muted">Analise cada pedido com contexto suficiente e registre uma decisão clara.</p><GroupReviewQueue items={queue.items} /></section></main>;
}
