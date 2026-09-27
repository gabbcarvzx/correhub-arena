import Link from "next/link";

import { sanitizeInternalReturnTo } from "@/lib/auth/return-to";
import type { ProfilePresentation } from "@/lib/profiles/types";
import {
  DISTANCE_LABELS,
  RUNNING_LEVEL_LABELS,
} from "@/lib/validations/profile";

import { ProfileAvatar } from "./profile-avatar";
import { FollowButton } from "@/components/social/follow-button";

type Viewer = "visitor" | "authenticated" | "self";

function formatPace(seconds: number): string {
  const minutes = Math.floor(seconds / 60);
  return `${minutes}:${String(seconds % 60).padStart(2, "0")} min/km`;
}

export function ProfileDetail({
  profile,
  viewer,
  isFollowing = false,
}: {
  profile: ProfilePresentation;
  viewer: Viewer;
  isFollowing?: boolean;
}) {
  const isPrivate = profile.visibility === "private";
  const returnTo = sanitizeInternalReturnTo(`/u/${profile.username}`);
  const loginHref = `/login?${new URLSearchParams({ returnTo }).toString()}`;

  return (
    <article className="mx-auto w-full max-w-3xl rounded-3xl border border-border bg-surface p-6 shadow-xl sm:p-10">
      <header className="flex flex-col gap-5 sm:flex-row sm:items-center">
        <ProfileAvatar
          avatarUrl={profile.avatarUrl}
          fullName={profile.fullName}
          isPrivate={isPrivate}
        />
        <div className="min-w-0">
          <p className="text-sm font-bold uppercase tracking-widest text-muted">
            @{profile.username}
          </p>
          <h1 className="mt-1 break-words text-4xl font-black tracking-tight sm:text-5xl">
            {profile.fullName}
          </h1>
        </div>
      </header>

      {isPrivate ? (
        <section className="mt-8 rounded-2xl border border-border bg-background p-5">
          <h2 className="text-xl font-bold">Perfil privado</h2>
          <p className="mt-2 leading-7 text-muted">
            Esta pessoa escolheu manter os detalhes do perfil em privado. Seguir não altera essa
            preferência.
          </p>
        </section>
      ) : (
        <div className="mt-8 space-y-6">
          {profile.bio ? <p className="max-w-2xl text-lg leading-8">{profile.bio}</p> : null}
          <dl className="grid gap-4 sm:grid-cols-2">
            {profile.city ? (
              <div className="rounded-2xl bg-background p-4">
                <dt className="text-sm font-semibold text-muted">Cidade</dt>
                <dd className="mt-1 font-bold">
                  {profile.city.name}, {profile.city.stateCode}
                </dd>
              </div>
            ) : null}
            {profile.runningLevel ? (
              <div className="rounded-2xl bg-background p-4">
                <dt className="text-sm font-semibold text-muted">Nível</dt>
                <dd className="mt-1 font-bold">{RUNNING_LEVEL_LABELS[profile.runningLevel]}</dd>
              </div>
            ) : null}
            {profile.preferredDistance ? (
              <div className="rounded-2xl bg-background p-4">
                <dt className="text-sm font-semibold text-muted">Distância preferida</dt>
                <dd className="mt-1 font-bold">
                  {DISTANCE_LABELS[profile.preferredDistance]}
                </dd>
              </div>
            ) : null}
            {profile.paceSecondsPerKm ? (
              <div className="rounded-2xl bg-background p-4">
                <dt className="text-sm font-semibold text-muted">Pace</dt>
                <dd className="mt-1 font-bold">{formatPace(profile.paceSecondsPerKm)}</dd>
              </div>
            ) : null}
          </dl>
        </div>
      )}

      <nav aria-label="Ações do perfil" className="mt-8 flex flex-wrap gap-3">
        {viewer === "self" ? (
          <>
            <Link className="inline-flex min-h-11 items-center rounded-full bg-primary px-5 py-3 font-bold text-on-primary hover:bg-primary-hover" href="/settings/profile">
              Editar perfil
            </Link>
            <Link className="inline-flex min-h-11 items-center rounded-full border border-border px-5 py-3 font-semibold" href={`/u/${profile.username}/followers`}>
              Seguidores
            </Link>
            <Link className="inline-flex min-h-11 items-center rounded-full border border-border px-5 py-3 font-semibold" href={`/u/${profile.username}/following`}>
              Seguindo
            </Link>
          </>
        ) : viewer === "visitor" ? (
          <Link className="inline-flex min-h-11 items-center rounded-full bg-primary px-5 py-3 font-bold text-on-primary hover:bg-primary-hover" href={loginHref}>
            Entrar para seguir
          </Link>
        ) : (
          <FollowButton
            initialFollowing={isFollowing}
            targetUserId={profile.id}
            username={profile.username}
          />
        )}
      </nav>
    </article>
  );
}
