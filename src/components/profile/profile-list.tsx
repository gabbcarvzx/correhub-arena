import Link from "next/link";

import type { ProfilePresentation } from "@/lib/profiles/types";

import { ProfileCard } from "./profile-card";

export function ProfileList({
  profiles,
  nextHref,
}: {
  profiles: ProfilePresentation[];
  nextHref?: string | null;
}) {
  if (profiles.length === 0) {
    return (
      <p className="rounded-3xl border border-border bg-surface p-8 text-center text-muted" role="status">
        Nenhum corredor encontrado.
      </p>
    );
  }
  return (
    <>
      <div className="grid gap-4 sm:grid-cols-2">
        {profiles.map((profile) => <ProfileCard key={profile.id} profile={profile} />)}
      </div>
      {nextHref ? (
        <div className="mt-8 text-center">
          <Link className="inline-flex min-h-11 items-center rounded-full border border-border bg-surface px-5 py-3 font-bold" href={nextHref}>
            Próxima página
          </Link>
        </div>
      ) : null}
    </>
  );
}
