import { notFound, redirect } from "next/navigation";

import { GroupManagementNav } from "@/components/groups/group-management-nav";
import { GroupMemberList } from "@/components/groups/group-member-list";
import { getCurrentAccountState } from "@/lib/auth/current-account";
import { getCurrentGroupRelation, getGroupBySlug, listGroupMembers } from "@/lib/groups/queries";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
export default async function GroupMembersPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params; const supabase = await createServerSupabaseClient(); const state = await getCurrentAccountState(supabase);
  if (state.kind === "anonymous") redirect(`/login?returnTo=${encodeURIComponent(`/grupos/${slug}/membros`)}`);
  if (state.kind !== "active" || !state.onboardingCompleted) redirect("/account-unavailable");
  const group = await getGroupBySlug(slug, supabase); if (!group) notFound(); const relation = await getCurrentGroupRelation(group.id, supabase);
  if (!relation || relation.status !== "active") notFound(); const manager = relation.role === "admin" || relation.role === "owner";
  const [active, pending, blocked] = await Promise.all([listGroupMembers(group.id, "active", supabase), manager ? listGroupMembers(group.id, "pending", supabase) : [], manager ? listGroupMembers(group.id, "blocked", supabase) : []]);
  return <main className="min-h-svh bg-background px-4 py-8 sm:px-6"><section className="mx-auto max-w-5xl"><GroupManagementNav showOwnership={relation.role === "owner"} slug={slug} /><p className="foundation-kicker">Comunidade</p><h1 className="text-4xl font-black tracking-tight">Membros de {group.name}</h1><div className="mt-8 space-y-10"><section><h2 className="mb-4 text-2xl font-black">Ativos</h2><GroupMemberList groupId={group.id} members={active} slug={slug} status="active" viewerRole={relation.role} /></section>{manager ? <><section><h2 className="mb-4 text-2xl font-black">Pedidos</h2><GroupMemberList groupId={group.id} members={pending} slug={slug} status="pending" viewerRole={relation.role} /></section><section><h2 className="mb-4 text-2xl font-black">Bloqueados</h2><GroupMemberList groupId={group.id} members={blocked} slug={slug} status="blocked" viewerRole={relation.role} /></section></> : null}</div></section></main>;
}
