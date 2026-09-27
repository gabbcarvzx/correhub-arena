import { redirect } from "next/navigation";

import { ProfileDetail } from "@/components/profile/profile-detail";
import { getCurrentAccountState } from "@/lib/auth/current-account";
import { getOwnProfile } from "@/lib/profiles/queries";

export const dynamic = "force-dynamic";

export default async function MyProfilePage() {
  const state = await getCurrentAccountState();
  if (state.kind === "anonymous") redirect("/login?returnTo=%2Fme");
  if (state.kind === "active" && !state.onboardingCompleted) {
    redirect("/onboarding?returnTo=%2Fme");
  }
  if (state.kind !== "active") redirect("/account-unavailable");

  const profile = await getOwnProfile();
  if (!profile) redirect("/account-unavailable");

  return (
    <main className="min-h-svh bg-background px-4 py-8 sm:px-6 lg:py-12">
      <ProfileDetail profile={profile} viewer="self" />
    </main>
  );
}
