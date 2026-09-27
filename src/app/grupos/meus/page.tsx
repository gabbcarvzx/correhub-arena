import Link from "next/link";
import { redirect } from "next/navigation";

import { OrganizerGroupList } from "@/components/groups/organizer-group-list";
import { getCurrentAccountState } from "@/lib/auth/current-account";
import { listMyGroups } from "@/lib/groups/queries";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
export default async function MyGroupsPage(){
  const supabase=await createServerSupabaseClient(); const state=await getCurrentAccountState(supabase);
  if(state.kind==="anonymous") redirect("/login?returnTo=%2Fgrupos%2Fmeus");
  if(state.kind==="active"&&!state.onboardingCompleted) redirect("/onboarding?returnTo=%2Fgrupos%2Fmeus");
  if(state.kind!=="active") redirect("/account-unavailable");
  const page=await listMyGroups({},supabase);
  return <main className="min-h-svh bg-background px-4 py-8 sm:px-6 lg:py-12"><section className="mx-auto max-w-4xl" aria-labelledby="my-groups-title"><div className="flex flex-col gap-5 border-b border-border pb-8 sm:flex-row sm:items-end sm:justify-between"><div><p className="foundation-kicker">Organizar</p><h1 className="text-4xl font-black tracking-tight sm:text-5xl" id="my-groups-title">Meus grupos</h1><p className="mt-3 text-muted">Acompanhe solicitações e cuide das comunidades que você organiza.</p></div><Link className="inline-flex min-h-12 items-center justify-center rounded-full bg-primary px-6 font-black text-on-primary hover:bg-primary-hover" href="/grupos/solicitar">Solicitar grupo</Link></div><div className="mt-8"><OrganizerGroupList groups={page.items}/></div></section></main>;
}
