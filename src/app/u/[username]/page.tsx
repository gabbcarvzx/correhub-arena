import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { ProfileDetail } from "@/components/profile/profile-detail";
import { getCurrentAccountState } from "@/lib/auth/current-account";
import { getProfileByUsername } from "@/lib/profiles/queries";
import { profileUsernameSchema } from "@/lib/validations/profile";

export const dynamic = "force-dynamic";

type ProfilePageProps = { params: Promise<{ username: string }> };

async function resolveProfile(rawUsername: string) {
  const parsed = profileUsernameSchema.safeParse(rawUsername);
  if (!parsed.success) return null;
  return getProfileByUsername(parsed.data);
}

export async function generateMetadata({ params }: ProfilePageProps): Promise<Metadata> {
  const { username } = await params;
  const profile = await resolveProfile(username);
  if (!profile) return { title: "Perfil não encontrado | CorreHub", robots: { index: false } };

  if (profile.visibility === "private") {
    return {
      title: `${profile.fullName} (@${profile.username}) | CorreHub`,
      description: "Perfil privado no CorreHub.",
      robots: { index: false, follow: false },
    };
  }

  return {
    title: `${profile.fullName} (@${profile.username}) | CorreHub`,
    description: profile.bio ?? `Perfil de ${profile.fullName} no CorreHub.`,
  };
}

export default async function ProfilePage({ params }: ProfilePageProps) {
  const { username } = await params;
  const profile = await resolveProfile(username);
  if (!profile) notFound();

  const state = await getCurrentAccountState();
  const viewer =
    profile.visibility === "self" && state.kind === "active"
      ? "self"
      : state.kind === "active" && state.onboardingCompleted
        ? "authenticated"
        : "visitor";

  return (
    <main className="min-h-svh bg-background px-4 py-8 sm:px-6 lg:py-12">
      <ProfileDetail profile={profile} viewer={viewer} />
    </main>
  );
}
