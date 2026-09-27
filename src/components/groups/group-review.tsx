"use client";

import * as AlertDialog from "@radix-ui/react-alert-dialog";
import Link from "next/link";
import { useRouter } from "next/navigation";
import type { MouseEvent } from "react";
import { useState } from "react";

import { approveGroup, rejectGroup } from "@/lib/groups/actions";
import type { GroupReview } from "@/lib/groups/types";

const typeLabel = { community: "Comunidade", professional: "Profissional" } as const;
const policyLabel = { open: "Entrada aberta", approval_required: "Entrada sob aprovação" } as const;

export function GroupReviewQueue({ items }: { items: GroupReview[] }) {
  if (!items.length) return <div className="border-y border-border py-12"><p className="text-xl font-black">Nenhuma solicitação aguardando análise.</p><p className="mt-2 text-muted">Novos pedidos aparecerão aqui em ordem de envio.</p></div>;
  return <ul className="divide-y divide-border border-y border-border">
    {items.map(group => <li className="py-5" key={group.id}>
      <Link className="group flex min-h-11 flex-col gap-2 sm:flex-row sm:items-center sm:justify-between" href={`/admin/grupos/${group.id}`} aria-label={`Revisar ${group.name}`}>
        <div><p className="text-lg font-black group-hover:text-primary-hover">{group.name}</p><p className="mt-1 text-sm text-muted">{group.city.name} · {typeLabel[group.type]} · {policyLabel[group.joinPolicy]}</p></div>
        <span className="font-bold text-foreground">Revisar →</span>
      </Link>
    </li>)}
  </ul>;
}

export function GroupReviewDecision({ group, canDecide }: { group: GroupReview; canDecide: boolean }) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [reason, setReason] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [reasonError, setReasonError] = useState<string | null>(null);

  async function approve() {
    if (pending) return;
    setPending(true); setMessage(null);
    const result = await approveGroup({ groupId: group.id });
    setPending(false);
    if (!result.ok) setMessage(result.message); else { setMessage("Grupo aprovado. A decisão foi registrada."); router.refresh(); }
  }
  async function reject(event: MouseEvent<HTMLButtonElement>) {
    event.preventDefault();
    if (pending) return;
    const normalized = reason.trim();
    if (normalized.length < 3) { setReasonError("Informe pelo menos 3 caracteres."); return; }
    if (normalized.length > 1000) { setReasonError("Use no máximo 1000 caracteres."); return; }
    setPending(true); setMessage(null); setReasonError(null);
    const result = await rejectGroup({ groupId: group.id }, normalized);
    setPending(false);
    if (!result.ok) setMessage(result.message); else { setMessage("Solicitação rejeitada. O motivo ficou disponível para a pessoa responsável."); router.refresh(); }
  }

  if (!canDecide) return <aside className="border-l-4 border-primary bg-surface p-5" aria-label="Revisão independente"><p className="font-black">Revisão independente necessária</p><p className="mt-2 text-muted">Outra pessoa administradora da plataforma precisa decidir esta solicitação.</p></aside>;
  return <section className="border-t border-border pt-7" aria-labelledby="decision-title">
    <p className="foundation-kicker">Decisão</p><h2 className="mt-2 text-2xl font-black" id="decision-title">Concluir análise</h2>
    <p className="mt-2 max-w-2xl text-muted">A aprovação ativa o grupo e a pessoa responsável. A rejeição preserva o pedido para correção e reenvio.</p>
    <div className="mt-6 flex flex-col gap-3 sm:flex-row">
      <button className="min-h-11 rounded-full bg-primary px-6 font-black text-on-primary hover:bg-primary-hover disabled:opacity-60" disabled={pending} onClick={approve} type="button">{pending ? "Processando…" : "Aprovar grupo"}</button>
      <AlertDialog.Root>
        <AlertDialog.Trigger asChild><button className="min-h-11 rounded-full border border-border px-6 font-black text-destructive disabled:opacity-60" disabled={pending} type="button">Rejeitar solicitação</button></AlertDialog.Trigger>
        <AlertDialog.Portal>
          <AlertDialog.Overlay className="fixed inset-0 z-40 bg-foreground/45" />
          <AlertDialog.Content className="fixed left-1/2 top-1/2 z-50 w-[min(34rem,calc(100vw-2rem))] -translate-x-1/2 -translate-y-1/2 border border-border bg-surface p-6 shadow-xl">
            <AlertDialog.Title className="text-2xl font-black">Rejeitar esta solicitação?</AlertDialog.Title>
            <AlertDialog.Description className="mt-3 leading-7 text-muted">O grupo não ficará público. A pessoa responsável poderá corrigir os dados e reenviar o mesmo pedido.</AlertDialog.Description>
            <label className="mt-5 block font-bold" htmlFor="rejection-reason">Motivo da rejeição</label>
            <textarea aria-describedby={reasonError ? "rejection-reason-error" : "rejection-reason-help"} aria-invalid={Boolean(reasonError)} className="mt-2 min-h-28 w-full border border-border bg-background p-3 outline-none focus:border-primary-hover" id="rejection-reason" maxLength={1000} onChange={event => setReason(event.target.value)} value={reason} />
            {reasonError ? <p className="mt-2 text-sm font-semibold text-destructive" id="rejection-reason-error" role="alert">{reasonError}</p> : <p className="mt-2 text-sm text-muted" id="rejection-reason-help">De 3 a 1000 caracteres. O motivo será privado.</p>}
            <div className="mt-7 flex flex-col-reverse gap-3 sm:flex-row sm:justify-end"><AlertDialog.Cancel className="min-h-11 px-5 font-bold text-muted">Cancelar</AlertDialog.Cancel><AlertDialog.Action className="min-h-11 rounded-full bg-destructive px-5 font-black text-white disabled:opacity-60" disabled={pending} onClick={reject}>{pending ? "Processando…" : "Confirmar rejeição"}</AlertDialog.Action></div>
          </AlertDialog.Content>
        </AlertDialog.Portal>
      </AlertDialog.Root>
    </div>
    {message ? <p className="mt-4 font-semibold" role="alert">{message}</p> : null}
  </section>;
}
