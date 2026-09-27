import { ProfileList } from "@/components/profile/profile-list";
import { getCurrentAccountState } from "@/lib/auth/current-account";
import { discoverProfiles, ProfileQueryError } from "@/lib/profiles/queries";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { discoveryQuerySchema } from "@/lib/validations/profile";

export const dynamic = "force-dynamic";

type PeoplePageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

function scalar(value: string | string[] | undefined): string | undefined {
  return typeof value === "string" ? value : undefined;
}

export default async function PeoplePage({ searchParams }: PeoplePageProps) {
  const raw = await searchParams;
  const parsed = discoveryQuerySchema.safeParse({
    q: scalar(raw.q),
    city: scalar(raw.city),
    cursor: scalar(raw.cursor),
  });
  const filters: { q?: string; city?: string; cursor?: string } = parsed.success ? parsed.data : {};
  const supabase = await createServerSupabaseClient();
  const state = await getCurrentAccountState(supabase);
  const [cities, settings] = await Promise.all([
    supabase.from("cities").select("id,name,state_code").eq("is_active", true).order("name"),
    supabase
      .from("app_settings")
      .select("launch_city_id")
      .eq("id", "10000000-0000-4000-8000-000000000002")
      .single(),
  ]);
  if (cities.error || settings.error || !cities.data?.length || !settings.data) {
    return <main className="min-h-svh p-6"><p role="alert">Não foi possível carregar a descoberta agora.</p></main>;
  }

  const activeIds = new Set(cities.data.map((city) => city.id));
  let ownCityId: string | null = null;
  if (state.kind === "active" && state.onboardingCompleted) {
    const own = await supabase.from("profiles").select("city_id").eq("id", state.userId).maybeSingle();
    ownCityId = own.data?.city_id ?? null;
  }
  const cityId =
    (filters.city && activeIds.has(filters.city) ? filters.city : null) ??
    (ownCityId && activeIds.has(ownCityId) ? ownCityId : null) ??
    settings.data.launch_city_id;

  let page;
  try {
    page = await discoverProfiles({ query: filters.q, cityId, cursor: filters.cursor });
  } catch (error) {
    const message = error instanceof ProfileQueryError ? error.message : "Não foi possível carregar os perfis agora.";
    return <main className="min-h-svh p-6"><p role="alert">{message}</p></main>;
  }

  const nextParams = new URLSearchParams();
  if (filters.q) nextParams.set("q", filters.q);
  nextParams.set("city", cityId);
  if (page.nextCursor) nextParams.set("cursor", page.nextCursor);

  return (
    <main className="min-h-svh bg-background px-4 py-8 sm:px-6 lg:py-12">
      <section className="mx-auto w-full max-w-5xl" aria-labelledby="people-title">
        <p className="foundation-kicker">Pessoas</p>
        <h1 className="text-4xl font-black tracking-tight sm:text-5xl" id="people-title">Descobrir corredores</h1>
        <form className="my-8 grid gap-3 rounded-3xl border border-border bg-surface p-5 sm:grid-cols-[1fr_1fr_auto]" method="get">
          <label className="font-semibold" htmlFor="people-query">Buscar
            <input className="mt-2 min-h-12 w-full rounded-xl border border-border px-4" defaultValue={filters.q} id="people-query" maxLength={80} name="q" placeholder="Nome ou @usuário" />
          </label>
          <label className="font-semibold" htmlFor="people-city">Cidade
            <select className="mt-2 min-h-12 w-full rounded-xl border border-border bg-surface px-4" defaultValue={cityId} id="people-city" name="city">
              {cities.data.map((city) => <option key={city.id} value={city.id}>{city.name} — {city.state_code}</option>)}
            </select>
          </label>
          <button className="min-h-12 self-end rounded-full bg-primary px-6 py-3 font-bold text-on-primary hover:bg-primary-hover" type="submit">Buscar</button>
        </form>
        <ProfileList profiles={page.items} nextHref={page.nextCursor ? `/people?${nextParams.toString()}` : null} />
      </section>
    </main>
  );
}
