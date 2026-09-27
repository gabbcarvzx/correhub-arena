"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import { followGroup, unfollowGroup } from "@/lib/groups/actions";

export function GroupFollowButton({ groupId, slug, initialFollowing }: { groupId: string; slug: string; initialFollowing: boolean }) {
  const router = useRouter();
  const [following, setFollowing] = useState(initialFollowing);
  const [pending, setPending] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [confirmation, setConfirmation] = useState<string | null>(null);

  async function toggle() {
    if (pending) return;
    setPending(true); setMessage(null); setConfirmation(null);
    const result = following ? await unfollowGroup({ groupId, slug }) : await followGroup({ groupId, slug });
    if (result.ok) {
      setFollowing(Boolean(result.following));
      setConfirmation(following ? "Você deixou de seguir. Isso não altera sua participação no grupo." : "Agora você acompanha as novidades públicas do grupo.");
      router.refresh();
    }
    else setMessage(result.message);
    setPending(false);
  }

  return <div className="space-y-2">
    <button className="min-h-11 rounded-full border border-border bg-surface px-5 py-3 font-bold hover:border-foreground disabled:cursor-not-allowed disabled:text-disabled" disabled={pending} onClick={toggle} type="button">
      {pending ? "Aguarde…" : following ? "Seguindo grupo" : "Seguir grupo"}
    </button>
    <p className="max-w-xs text-sm leading-6 text-muted">{following ? "Deixar de seguir não altera sua participação no grupo." : "Acompanhe as novidades públicas. Seguir não torna você membro."}</p>
    {confirmation ? <p className="text-sm font-semibold text-success" role="status">{confirmation}</p> : null}
    {message ? <p className="text-sm font-semibold text-destructive" role="alert">{message}</p> : null}
  </div>;
}
