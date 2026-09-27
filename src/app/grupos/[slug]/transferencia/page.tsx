import { notFound, redirect } from "next/navigation";

import { GroupManagementNav } from "@/components/groups/group-management-nav";
import { OwnerTransferPanel } from "@/components/groups/owner-transfer-panel";
import { getCurrentAccountState } from "@/lib/auth/current-account";
import { getCurrentGroupRelation, getGroupBySlug, getGroupOwnerTransfer, listGroupMembers } from "@/lib/groups/queries";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
export default async function GroupTransferPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params; const supabase = await createServerSupabaseClient(); const state = await getCurrentAccountState(supabase);
  if (state.kind === "anonymous") redirect(`/login?returnTo=${encodeURIComponent(`/grupos/${slug}/transferencia`)}`);
  if (state.kind !== "active" || !state.onboardingCompleted) redirect("/account-unavailable");
  const group = await getGroupBySlug(slug, supabase); if (!group || group.status !== "approved") notFound(); const relation = await getCurrentGroupRelation(group.id, supabase);
  if (!relation || relation.status !== "active") notFound(); const transfer = await getGroupOwnerTransfer(group.id, supabase);
  if (relation.role !== "owner" && transfer?.toUserId !== state.userId) notFound();
  const candidates = relation.role === "owner" ? (await listGroupMembers(group.id, "active", supabase)).filter(member => member.role !== "owner") : [];
  return <main className="min-h-svh bg-background px-4 py-8 sm:px-6"><section className="mx-auto max-w-4xl"><GroupManagementNav showOwnership slug={slug} /><p className="foundation-kicker">Responsabilidade</p><h1 className="text-4xl font-black tracking-tight">Responsabilidade por {group.name}</h1><p className="mt-3 max-w-2xl text-muted">O grupo deve manter exatamente uma pessoa responsável. A troca só termina depois do aceite.</p><div className="mt-8"><OwnerTransferPanel candidates={candidates} currentUserId={state.userId} groupId={group.id} transfer={transfer} /></div></section></main>;
}
