import { redirect } from "next/navigation";

import { getCurrentAccountState } from "@/lib/auth/current-account";
import { getOwnProfile } from "@/lib/profiles/queries";
import { createServerSupabaseClient } from "@/lib/supabase/server";

import { ProfileForm } from "./profile-form";

export const dynamic = "force-dynamic";

function paceInput(seconds: number | null): string {
  if (!seconds) return "";
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
}

export default async function SettingsProfilePage() {
  const supabase = await createServerSupabaseClient();
  const state = await getCurrentAccountState(supabase);
  if (state.kind === "anonymous") redirect("/login?returnTo=%2Fsettings%2Fprofile");
  if (state.kind === "active" && !state.onboardingCompleted) {
    redirect("/onboarding?returnTo=%2Fsettings%2Fprofile");
  }
  if (state.kind !== "active") redirect("/account-unavailable");

  const [profile, cities, privacy] = await Promise.all([
    getOwnProfile(supabase),
    supabase.from("cities").select("id,name,state_code").eq("is_active", true).order("name"),
    supabase.from("profiles").select("is_private").eq("id", state.userId).maybeSingle(),
  ]);
  if (!profile || !profile.city || cities.error || !cities.data?.length || privacy.error || !privacy.data || !profile.runningLevel || !profile.preferredDistance) {
    redirect("/account-unavailable");
  }

  return (
    <main className="min-h-svh bg-background px-4 py-8 sm:px-6 lg:py-12">
      <section className="mx-auto w-full max-w-2xl rounded-3xl border border-border bg-surface p-6 shadow-xl sm:p-10" aria-labelledby="edit-profile-title">
        <p className="foundation-kicker">Seu perfil</p>
        <h1 className="text-4xl font-black tracking-tight sm:text-5xl" id="edit-profile-title">Editar perfil</h1>
        <ProfileForm
          cities={cities.data}
          initialValues={{
            username: profile.username,
            full_name: profile.fullName,
            city_id: profile.city.id,
            running_level: profile.runningLevel,
            preferred_distance: profile.preferredDistance,
            bio: profile.bio ?? "",
            pace: paceInput(profile.paceSecondsPerKm),
            is_private: privacy.data.is_private,
          }}
        />
      </section>
    </main>
  );
}
