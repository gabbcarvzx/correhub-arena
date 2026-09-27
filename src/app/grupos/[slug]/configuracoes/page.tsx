import { notFound, redirect } from "next/navigation";

import { GroupManagementNav } from "@/components/groups/group-management-nav";
import { GroupMediaForm } from "@/components/groups/group-media-form";
import { GroupRequestForm } from "@/components/groups/group-request-form";
import { getCurrentAccountState } from "@/lib/auth/current-account";
import { getCurrentGroupRelation, getGroupBySlug } from "@/lib/groups/queries";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
export default async function GroupSettingsPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params; const supabase = await createServerSupabaseClient(); const state = await getCurrentAccountState(supabase);
  if (state.kind === "anonymous") redirect(`/login?returnTo=${encodeURIComponent(`/grupos/${slug}/configuracoes`)}`);
  if (state.kind !== "active" || !state.onboardingCompleted) redirect("/account-unavailable");
  const group = await getGroupBySlug(slug, supabase); if (!group) notFound();
  const relation = await getCurrentGroupRelation(group.id, supabase);
  if (!relation || !["admin", "owner"].includes(relation.role) || !["active", "pending"].includes(relation.status)) notFound();
  if (group.status === "suspended") return <main className="min-h-svh bg-background px-4 py-8 sm:px-6"><section className="mx-auto max-w-4xl"><GroupManagementNav showOwnership={relation.role === "owner"} slug={slug} /><p className="foundation-kicker">Histórico</p><h1 className="text-4xl font-black">Grupo suspenso</h1><p className="mt-3 max-w-2xl text-muted">Os dados permanecem disponíveis para consulta, mas nenhuma alteração operacional está liberada.</p></section></main>;
  const cities = await supabase.from("cities").select("id,name,state_code").eq("is_active", true).order("name"); if (cities.error || !cities.data?.length) throw new Error("cities_unavailable");
  return <main className="min-h-svh bg-background px-4 py-8 sm:px-6"><section className="mx-auto max-w-4xl"><GroupManagementNav showOwnership={relation.role === "owner"} slug={slug} /><p className="foundation-kicker">Gestão</p><h1 className="text-4xl font-black tracking-tight">Configurações de {group.name}</h1><GroupRequestForm cancelHref={`/grupos/${slug}`} cities={cities.data} edit={{ groupId: group.id, wasRejected: group.status === "rejected", slugLocked: group.status === "approved" }} initialValues={{ name: group.name, slug: group.slug, description: group.description, city_id: group.city.id, group_type: group.type, join_policy: group.joinPolicy }} />{group.status === "approved" || group.status === "pending" || group.status === "rejected" ? <div className="mt-10"><GroupMediaForm groupId={group.id} /></div> : null}</section></main>;
}
