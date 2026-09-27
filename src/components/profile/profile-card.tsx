import Link from "next/link";

import type { ProfilePresentation } from "@/lib/profiles/types";

import { ProfileAvatar } from "./profile-avatar";

export function ProfileCard({ profile }: { profile: ProfilePresentation }) {
  return (
    <article className="rounded-3xl border border-border bg-surface p-5 shadow-sm">
      <Link
        className="flex min-h-14 items-center gap-4 rounded-2xl focus-visible:outline-offset-4"
        href={`/u/${profile.username}`}
      >
        <ProfileAvatar
          avatarUrl={profile.avatarUrl}
          fullName={profile.fullName}
          isPrivate={profile.visibility === "private"}
          size="small"
        />
        <span className="min-w-0">
          <strong className="block truncate text-lg">{profile.fullName}</strong>
          <span className="block truncate text-muted">@{profile.username}</span>
        </span>
      </Link>
    </article>
  );
}
