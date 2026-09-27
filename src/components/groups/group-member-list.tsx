"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import {
  approveGroupMember, blockGroupMember, demoteGroupAdmin,
  promoteGroupAdmin, rejectGroupMember,
} from "@/lib/groups/actions";
import type { GroupMemberPresentation, GroupMemberRole, GroupMemberStatus } from "@/lib/groups/types";
import { ConfirmAction } from "@/components/ui/alert-dialog";

const roleLabel = { member: "Membro", admin: "Gestor", owner: "Responsável" } as const;

export function GroupMemberList({ groupId, slug, status, viewerRole, members }: {
  groupId: string; slug: string; status: GroupMemberStatus; viewerRole: GroupMemberRole; members: GroupMemberPresentation[];
}) {
  const router = useRouter(); const [message, setMessage] = useState<string | null>(null);
  async function run(action: (input: unknown, slug?: string) => Promise<{ ok: boolean; message?: string }>, userId: string) {
    setMessage(null); const result = await action({ groupId, userId }, slug);
    if (!result.ok) setMessage(result.message ?? "Não foi possível concluir a ação."); else router.refresh();
  }
  if (!members.length) return <p className="border-y border-border py-8 text-muted">Nenhuma pessoa neste estado.</p>;
  const canManage = viewerRole === "admin" || viewerRole === "owner";
  return <div>
    <ul className="divide-y divide-border border-y border-border">
      {members.map(member => <li className="flex flex-col gap-4 py-5 sm:flex-row sm:items-center sm:justify-between" key={member.userId}>
        <div className="min-w-0"><p className="truncate text-lg font-black">{member.fullName}</p><div className="flex flex-wrap gap-x-2 text-sm text-muted"><span>@{member.username}</span><span>{roleLabel[member.role]}</span>{member.visibility === "private" ? <span>Perfil privado</span> : null}</div></div>
        {canManage && member.role === "member" ? <div className="flex flex-wrap gap-2">
          {status === "pending" ? <>
            <button aria-label={`Aprovar ${member.fullName}`} className="min-h-11 rounded-full bg-primary px-4 font-bold text-on-primary" onClick={() => run(approveGroupMember, member.userId)} type="button">Aprovar</button>
            <ConfirmAction confirmLabel="Confirmar rejeição" description="O pedido será removido. A pessoa poderá solicitar entrada novamente." destructive onConfirm={() => run(rejectGroupMember, member.userId)} title="Rejeitar pedido?" trigger={<button aria-label={`Rejeitar ${member.fullName}`} className="min-h-11 rounded-full border border-border px-4 font-bold" type="button">Rejeitar</button>} />
          </> : null}
          {status === "active" && viewerRole === "owner" ? <ConfirmAction confirmLabel="Confirmar promoção" description="A pessoa poderá gerir membros comuns deste grupo. Apenas a pessoa responsável controla gestores e a transferência do grupo." onConfirm={() => run(promoteGroupAdmin, member.userId)} title="Tornar esta pessoa gestora?" trigger={<button aria-label={`Promover ${member.fullName}`} className="min-h-11 rounded-full border border-border px-4 font-bold" type="button">Promover</button>} /> : null}
          {status !== "blocked" ? <ConfirmAction confirmLabel="Bloquear membro" description="A pessoa perderá o acesso restrito e não poderá entrar novamente por conta própria." destructive onConfirm={() => run(blockGroupMember, member.userId)} title="Bloquear esta pessoa?" trigger={<button aria-label={`Bloquear ${member.fullName}`} className="min-h-11 px-4 font-bold text-destructive" type="button">Bloquear</button>} /> : null}
        </div> : null}
        {viewerRole === "owner" && status === "active" && member.role === "admin" ? <ConfirmAction confirmLabel="Confirmar rebaixamento" description="A pessoa volta a ser membro comum e perde os controles de gestão." destructive onConfirm={() => run(demoteGroupAdmin, member.userId)} title="Remover da gestão?" trigger={<button aria-label={`Rebaixar ${member.fullName}`} className="min-h-11 rounded-full border border-border px-4 font-bold" type="button">Rebaixar</button>} /> : null}
      </li>)}
    </ul>
    {message ? <p className="mt-4 text-sm font-semibold text-destructive" role="alert">{message}</p> : null}
  </div>;
}
