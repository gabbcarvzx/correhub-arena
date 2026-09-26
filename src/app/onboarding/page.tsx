import { redirect } from "next/navigation";

import {
  getCurrentAccountState,
  getCurrentAuthUser,
} from "@/lib/auth/current-account";
import { resolveAuthRouteState } from "@/lib/auth/route-state";
import { sanitizeInternalReturnTo } from "@/lib/auth/return-to";
import { createServerSupabaseClient } from "@/lib/supabase/server";

import { OnboardingForm } from "./onboarding-form";

export const dynamic = "force-dynamic";

type OnboardingPageProps = {
  searchParams: Promise<{ returnTo?: string | string[] }>;
};

export default async function OnboardingPage({ searchParams }: OnboardingPageProps) {
  const params = await searchParams;
  const returnTo = sanitizeInternalReturnTo(
    typeof params.returnTo === "string" ? params.returnTo : "/",
  );
  const supabase = await createServerSupabaseClient();
  const state = await getCurrentAccountState(supabase);
  const decision = resolveAuthRouteState(state, "onboarding", returnTo);
  if (decision.action === "redirect") {
    redirect(decision.destination);
  }
  if (state.kind !== "active") {
    redirect("/account-unavailable");
  }

  const [citiesResult, settingsResult, profileResult, user] = await Promise.all([
    supabase
      .from("cities")
      .select("id,name,state_code")
      .eq("is_active", true)
      .order("name"),
    supabase
      .from("app_settings")
      .select("launch_city_id")
      .eq("id", "10000000-0000-4000-8000-000000000002")
      .single(),
    supabase.from("profiles").select("full_name").eq("id", state.userId).maybeSingle(),
    getCurrentAuthUser(supabase),
  ]);

  if (
    citiesResult.error ||
    settingsResult.error ||
    profileResult.error ||
    !citiesResult.data?.length ||
    !settingsResult.data
  ) {
    redirect("/account-unavailable");
  }

  const metadataName =
    typeof user?.user_metadata.full_name === "string"
      ? user.user_metadata.full_name
      : typeof user?.user_metadata.name === "string"
        ? user.user_metadata.name
        : "";
  const initialFullName = profileResult.data?.full_name ?? metadataName;
  const launchCityId = citiesResult.data.some(
    (city) => city.id === settingsResult.data.launch_city_id,
  )
    ? settingsResult.data.launch_city_id
    : "";

  return (
    <main className="min-h-svh bg-background px-4 py-8 sm:px-6 lg:py-12">
      <section
        className="mx-auto w-full max-w-2xl rounded-3xl border border-border bg-surface p-6 shadow-xl sm:p-10"
        aria-labelledby="onboarding-title"
      >
        <p className="foundation-kicker">Primeiros passos</p>
        <h1 className="text-4xl font-bold tracking-tight sm:text-5xl" id="onboarding-title">
          Complete seu perfil
        </h1>
        <p className="mt-3 leading-7 text-muted">
          Conte o básico para personalizar sua experiência de corrida.
        </p>
        <OnboardingForm
          cities={citiesResult.data}
          initialFullName={initialFullName}
          launchCityId={launchCityId}
          returnTo={returnTo}
        />
      </section>
    </main>
  );
}
