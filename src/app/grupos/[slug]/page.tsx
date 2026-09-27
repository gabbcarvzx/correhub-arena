import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { GroupDetail } from "@/components/groups/group-detail";
import { getCurrentAccountState } from "@/lib/auth/current-account";
import { getCurrentGroupRelation, getGroupBySlug } from "@/lib/groups/queries";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
type Props = { params: Promise<{ slug: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const group = await getGroupBySlug(slug);
  if (!group || group.status !== "approved") return { title: "Grupo indisponível | CorreHub", robots: { index: false, follow: false } };
  return { title: `${group.name} | CorreHub`, description: group.description };
}

export default async function GroupPage({ params }: Props) {
  const { slug } = await params;
  const supabase = await createServerSupabaseClient();
  const group = await getGroupBySlug(slug, supabase);
  if (!group) notFound();
  const state = await getCurrentAccountState(supabase);
  const viewer = state.kind === "active" && state.onboardingCompleted ? "authenticated" : "visitor";
  let relation = null; let isFollowing = false;
  if (viewer === "authenticated") {
    relation = await getCurrentGroupRelation(group.id, supabase);
    const follow = await supabase.from("group_follows").select("group_id").eq("group_id", group.id).eq("user_id", state.kind === "active" ? state.userId : "").maybeSingle();
    isFollowing = Boolean(follow.data && !follow.error);
  }
  return <main className="min-h-svh bg-background px-4 py-8 sm:px-6 lg:py-12"><GroupDetail group={group} isFollowing={isFollowing} relation={relation} viewer={viewer} /></main>;
}
