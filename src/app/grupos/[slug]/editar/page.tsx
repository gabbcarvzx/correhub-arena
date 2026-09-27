import { notFound, redirect } from "next/navigation";

import { GroupRequestForm } from "@/components/groups/group-request-form";
import { getCurrentAccountState } from "@/lib/auth/current-account";
import { getGroupBySlug } from "@/lib/groups/queries";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function EditRequestedGroupPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const supabase = await createServerSupabaseClient();
  const state = await getCurrentAccountState(supabase);
  if (state.kind === "anonymous") redirect(`/login?returnTo=${encodeURIComponent(`/grupos/${slug}/editar`)}`);
  if (state.kind !== "active" || !state.onboardingCompleted) redirect("/account-unavailable");
  const [group, cities] = await Promise.all([
    getGroupBySlug(slug, supabase),
    supabase.from("cities").select("id,name,state_code").eq("is_active", true).order("name"),
  ]);
  if (!group || !group.isOwner || !["pending", "rejected"].includes(group.status)) notFound();
  if (cities.error || !cities.data?.length) return <main className="min-h-svh p-6"><p role="alert">Não foi possível carregar as cidades agora.</p></main>;
  return <main className="min-h-svh bg-background px-4 py-8 sm:px-6 lg:py-12"><section className="mx-auto max-w-3xl" aria-labelledby="edit-request-title"><a className="inline-flex min-h-11 items-center font-bold text-muted" href="/grupos/meus">← Meus grupos</a><p className="foundation-kicker mt-8">Organizar</p><h1 className="text-4xl font-black tracking-tight sm:text-5xl" id="edit-request-title">Ajustar solicitação</h1><p className="mt-3 text-muted">As alterações ficam no mesmo grupo e preservam o histórico da análise.</p><GroupRequestForm cities={cities.data} edit={{ groupId: group.id, wasRejected: group.status === "rejected" }} initialValues={{ name: group.name, slug: group.slug, description: group.description, city_id: group.city.id, group_type: group.type, join_policy: group.joinPolicy }} /></section></main>;
}
