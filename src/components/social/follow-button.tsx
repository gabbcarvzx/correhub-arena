"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import { followProfile, unfollowProfile } from "@/lib/social/actions";

export function FollowButton({
  initialFollowing,
  targetUserId,
  username,
}: {
  initialFollowing: boolean;
  targetUserId: string;
  username: string;
}) {
  const router = useRouter();
  const [following, setFollowing] = useState(initialFollowing);
  const [pending, setPending] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  async function toggle() {
    if (pending) return;
    setPending(true);
    setMessage(null);
    const result = following
      ? await unfollowProfile(targetUserId, username)
      : await followProfile(targetUserId, username);
    if (result.ok) {
      setFollowing(result.following);
      router.refresh();
    } else {
      setMessage(result.message);
    }
    setPending(false);
  }

  const label = pending ? (following ? "Deixando de seguir…" : "Seguindo…") : following ? "Seguindo" : "Seguir";
  return (
    <div>
      <button
        className="min-h-11 rounded-full bg-primary px-5 py-3 font-bold text-on-primary hover:bg-primary-hover disabled:cursor-not-allowed disabled:bg-disabled"
        disabled={pending}
        onClick={toggle}
        type="button"
      >
        {label}
      </button>
      {message ? <p className="mt-2 text-sm text-destructive" role="alert">{message}</p> : null}
    </div>
  );
}
