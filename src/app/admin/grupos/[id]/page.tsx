import Link from "next/link";
import { notFound, redirect } from "next/navigation";

import { GroupReviewDecision } from "@/components/groups/group-review";
import { getCurrentAccountState } from "@/lib/auth/current-account";
import { canReviewGroups, getGroupReview } from "@/lib/groups/queries";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
const typeLabel = { community: "Comunidade", professional: "Profissional" } as const;
const policyLabel = { open: "Entrada aberta", approval_required: "Entrada sob aprovação" } as const;
export default async function GroupReviewPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params; const supabase = await createServerSupabaseClient(); const state = await getCurrentAccountState(supabase);
  if (state.kind === "anonymous") redirect(`/login?returnTo=${encodeURIComponent(`/admin/grupos/${id}`)}`);
  if (state.kind !== "active" || !state.onboardingCompleted) redirect("/account-unavailable");
  if (!(await canReviewGroups(supabase))) notFound();
  const group = await getGroupReview(id, supabase); if (!group) notFound();
  const canDecide = state.userId !== group.createdBy && state.userId !== group.ownerUserId && group.status === "pending";
  return <main className="min-h-svh bg-background px-4 py-8 sm:px-6 lg:py-12"><article className="mx-auto max-w-4xl"><Link className="inline-flex min-h-11 items-center font-bold text-muted hover:text-foreground" href="/admin/grupos">← Solicitações</Link><p className="foundation-kicker mt-8">Análise de grupo</p><h1 className="mt-2 text-4xl font-black tracking-tight sm:text-5xl">{group.name}</h1><p className="mt-3 max-w-3xl text-lg leading-8 text-muted">{group.description}</p><dl className="my-8 grid gap-x-8 gap-y-5 border-y border-border py-6 sm:grid-cols-2"><Fact label="Cidade" value={group.city.name} /><Fact label="Tipo" value={typeLabel[group.type]} /><Fact label="Entrada" value={policyLabel[group.joinPolicy]} /><Fact label="Enviado em" value={new Intl.DateTimeFormat("pt-BR", { dateStyle: "long" }).format(new Date(group.createdAt))} /></dl>{group.status === "pending" ? <GroupReviewDecision group={group} canDecide={canDecide} /> : <p className="border-l-4 border-primary bg-surface p-5 font-bold">Esta solicitação já foi decidida.</p>}</article></main>;
}
function Fact({ label, value }: { label: string; value: string }) { return <div><dt className="text-sm font-bold uppercase tracking-wide text-muted">{label}</dt><dd className="mt-1 text-lg font-black">{value}</dd></div>; }
