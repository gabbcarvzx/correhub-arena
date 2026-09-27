import { notFound, redirect } from "next/navigation";

import { ProfileList } from "@/components/profile/profile-list";
import { getCurrentAccountState } from "@/lib/auth/current-account";
import { sanitizeInternalReturnTo } from "@/lib/auth/return-to";
import { getProfileByUsername, listProfileConnections } from "@/lib/profiles/queries";
import type { ConnectionDirection } from "@/lib/profiles/types";

export async function ConnectionListPage({
  username,
  direction,
  cursor,
}: {
  username: string;
  direction: ConnectionDirection;
  cursor?: string;
}) {
  const route = sanitizeInternalReturnTo(`/u/${username}/${direction}`);
  const state = await getCurrentAccountState();
  if (state.kind === "anonymous") {
    redirect(`/login?${new URLSearchParams({ returnTo: route }).toString()}`);
  }
  if (state.kind === "active" && !state.onboardingCompleted) {
    redirect(`/onboarding?${new URLSearchParams({ returnTo: route }).toString()}`);
  }
  if (state.kind !== "active") redirect("/account-unavailable");

  const profile = await getProfileByUsername(username);
  if (!profile || profile.visibility === "private") notFound();

  let page;
  try {
    page = await listProfileConnections({ username: profile.username, direction, cursor });
  } catch {
    notFound();
  }

  const title = direction === "followers" ? `Seguidores de ${profile.fullName}` : `Seguindo por ${profile.fullName}`;
  const params = new URLSearchParams();
  if (page.nextCursor) params.set("cursor", page.nextCursor);

  return (
    <main className="min-h-svh bg-background px-4 py-8 sm:px-6 lg:py-12">
      <section className="mx-auto w-full max-w-4xl" aria-labelledby="connections-title">
        <p className="foundation-kicker">Conexões</p>
        <h1 className="mb-8 text-4xl font-black tracking-tight sm:text-5xl" id="connections-title">{title}</h1>
        <ProfileList profiles={page.items} nextHref={page.nextCursor ? `${route}?${params.toString()}` : null} />
      </section>
    </main>
  );
}
