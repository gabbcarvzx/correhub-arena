"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import { acceptOwnerTransfer, cancelOwnerTransfer, initiateOwnerTransfer } from "@/lib/groups/actions";
import type { GroupMemberPresentation, GroupOwnerTransfer } from "@/lib/groups/types";
import { ConfirmAction } from "@/components/ui/alert-dialog";

export function OwnerTransferPanel({ groupId, currentUserId, candidates, transfer }: {
  groupId: string; currentUserId: string; candidates: GroupMemberPresentation[]; transfer: GroupOwnerTransfer | null;
}) {
  const router = useRouter(); const [target, setTarget] = useState(""); const [message, setMessage] = useState<string | null>(null);
  async function finish(result: Awaited<ReturnType<typeof cancelOwnerTransfer>>) {
    if (!result.ok) setMessage(result.message); else router.refresh();
  }
  if (transfer?.status === "expired") return <p className="border-l-4 border-warning pl-4 font-bold">Transferência expirada</p>;
  if (transfer?.status === "pending") {
    const isRecipient = transfer.toUserId === currentUserId; const isSender = transfer.fromUserId === currentUserId;
    return <section className="border-y border-border py-6"><h2 className="text-2xl font-black">Transferência em andamento</h2><p className="mt-2 max-w-2xl leading-7 text-muted">A mudança exige aceite explícito e expira em {new Intl.DateTimeFormat("pt-BR", { dateStyle: "long" }).format(new Date(transfer.expiresAt))}.</p><div className="mt-5 flex flex-wrap gap-3">
      {isRecipient ? <ConfirmAction confirmLabel="Aceitar responsabilidade" description="Você se tornará owner e a pessoa atual passará a membro comum." onConfirm={async () => finish(await acceptOwnerTransfer({ transferId: transfer.transferId }))} title="Assumir o grupo?" trigger={<button className="min-h-11 rounded-full bg-primary px-5 font-black text-on-primary" type="button">Aceitar responsabilidade</button>} /> : null}
      {isSender ? <ConfirmAction confirmLabel="Cancelar transferência" description="O convite perde validade e você permanece owner." destructive onConfirm={async () => finish(await cancelOwnerTransfer({ transferId: transfer.transferId }))} title="Cancelar transferência?" trigger={<button className="min-h-11 rounded-full border border-border px-5 font-bold" type="button">Cancelar transferência</button>} /> : null}
    </div>{message ? <p className="mt-4 text-destructive" role="alert">{message}</p> : null}</section>;
  }
  return <section><h2 className="text-2xl font-black">Transferir responsabilidade</h2><p className="mt-2 max-w-2xl leading-7 text-muted">Escolha um membro ativo. A pessoa terá 7 dias para aceitar explicitamente.</p><div className="mt-6 max-w-xl"><label className="font-bold" htmlFor="owner-target">Nova pessoa responsável</label><select className="mt-2 min-h-12 w-full rounded-xl border border-border bg-surface px-4" id="owner-target" onChange={event => setTarget(event.target.value)} value={target}><option value="">Selecione um membro</option>{candidates.map(candidate => <option key={candidate.userId} value={candidate.userId}>{candidate.fullName} (@{candidate.username})</option>)}</select></div>
    <div className="mt-5"><ConfirmAction confirmLabel="Enviar convite" description="Você continua owner até que a outra pessoa aceite. O convite expira em 7 dias." onConfirm={async () => finish(await initiateOwnerTransfer({ groupId, userId: target }))} title="Transferir responsabilidade?" trigger={<button className="min-h-11 rounded-full bg-primary px-5 font-black text-on-primary disabled:bg-disabled" disabled={!target} type="button">Iniciar transferência</button>} /></div>{message ? <p className="mt-4 text-destructive" role="alert">{message}</p> : null}</section>;
}
