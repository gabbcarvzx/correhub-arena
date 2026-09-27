import { redirect } from "next/navigation";

import { GroupRequestForm } from "@/components/groups/group-request-form";
import { getCurrentAccountState } from "@/lib/auth/current-account";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
export default async function RequestGroupPage() {
  const supabase = await createServerSupabaseClient(); const state = await getCurrentAccountState(supabase);
  if (state.kind === "anonymous") redirect("/login?returnTo=%2Fgrupos%2Fsolicitar");
  if (state.kind === "active" && !state.onboardingCompleted) redirect("/onboarding?returnTo=%2Fgrupos%2Fsolicitar");
  if (state.kind !== "active") redirect("/account-unavailable");
  const { data: cities, error } = await supabase.from("cities").select("id,name,state_code").eq("is_active",true).order("name");
  if (error || !cities?.length) return <main className="min-h-svh p-6"><p role="alert">Não foi possível carregar as cidades agora.</p></main>;
  return <main className="min-h-svh bg-background px-4 py-8 sm:px-6 lg:py-12"><section className="mx-auto max-w-3xl" aria-labelledby="request-group-title"><LinkBack /><p className="foundation-kicker mt-8">Organizar</p><h1 className="text-4xl font-black tracking-tight sm:text-5xl" id="request-group-title">Solicitar um grupo</h1><p className="mt-3 max-w-2xl text-lg text-muted">Conte como sua comunidade corre. A análise protege os participantes e mantém os grupos confiáveis.</p><GroupRequestForm cities={cities} /></section></main>;
}
function LinkBack(){ return <a className="inline-flex min-h-11 items-center font-bold text-muted hover:text-foreground" href="/grupos/meus">← Meus grupos</a>; }
