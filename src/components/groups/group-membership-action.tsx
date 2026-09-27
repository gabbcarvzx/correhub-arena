"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import { joinGroup, leaveGroup } from "@/lib/groups/actions";
import type { GroupJoinPolicy, GroupRelation } from "@/lib/groups/types";

export function GroupMembershipAction({ groupId, slug, joinPolicy, relation }: {
  groupId: string; slug: string; joinPolicy: GroupJoinPolicy; relation: GroupRelation | null;
}) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  async function act(kind: "join" | "leave") {
    if (pending) return;
    setPending(true); setMessage(null); setSuccess(null);
    const result = kind === "join" ? await joinGroup({ groupId }, slug) : await leaveGroup({ groupId }, slug);
    if (result.ok) {
      setSuccess(kind === "join" ? (joinPolicy === "open" ? "Você entrou no grupo." : "Pedido enviado para análise.") : "Você saiu do grupo.");
      router.refresh();
    } else setMessage(result.message);
    setPending(false);
  }

  if (relation?.status === "pending") return <p className="font-bold text-warning">Pedido em análise</p>;
  if (relation?.status === "blocked") return <p className="font-bold text-destructive">Entrada indisponível</p>;
  if (relation?.status === "active" && relation.role === "owner") return <p className="font-bold text-success">Você organiza este grupo.</p>;

  return <div className="space-y-2">
    <button className="min-h-11 rounded-full bg-primary px-5 py-3 font-black text-on-primary hover:bg-primary-hover disabled:cursor-not-allowed disabled:bg-disabled" disabled={pending} onClick={() => act(relation?.status === "active" ? "leave" : "join")} type="button">
      {pending ? "Aguarde…" : relation?.status === "active" ? "Sair do grupo" : joinPolicy === "open" ? "Entrar no grupo" : "Pedir para entrar"}
    </button>
    {success ? <p className="text-sm font-semibold text-success" role="status">{success}</p> : null}
    {message ? <p className="text-sm font-semibold text-destructive" role="alert">{message}</p> : null}
  </div>;
}
