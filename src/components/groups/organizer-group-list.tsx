import Link from "next/link";

import type { MyGroup } from "@/lib/groups/types";

const labels = { pending: "Em análise", rejected: "Ajustes necessários", approved: "Ativo", suspended: "Suspenso" } as const;
const explanations = { pending: "A equipe do CorreHub está revisando sua solicitação.", rejected: "Revise o motivo e ajuste a mesma solicitação.", approved: "O grupo está publicado e pronto para receber pessoas.", suspended: "As operações do grupo estão temporariamente pausadas." } as const;

export function OrganizerGroupList({ groups }: { groups: MyGroup[] }) {
  if (!groups.length) return <div className="border-y border-border py-10"><h2 className="text-2xl font-black">Você ainda não solicitou um grupo.</h2><p className="mt-2 max-w-xl text-muted">Crie a base da sua comunidade de corrida e acompanhe a análise por aqui.</p><Link className="mt-6 inline-flex min-h-11 items-center rounded-full bg-primary px-6 font-black text-on-primary hover:bg-primary-hover" href="/grupos/solicitar">Solicitar primeiro grupo</Link></div>;
  return <ul className="divide-y divide-border border-y border-border">{groups.map((group) => <li className="grid gap-4 py-6 sm:grid-cols-[1fr_auto] sm:items-center" key={group.id}><div><div className="flex flex-wrap items-baseline gap-x-3 gap-y-1"><h2 className="text-2xl font-black">{group.name}</h2><span className="text-sm font-bold text-muted">{labels[group.status]}</span></div><p className="mt-1 text-muted">{explanations[group.status]}</p>{group.status === "rejected" && group.rejectionReason ? <p className="mt-3 border-l-4 border-warning pl-3 text-sm"><strong>Motivo:</strong> {group.rejectionReason}</p> : null}</div><div>{group.status === "rejected" ? <Link className="inline-flex min-h-11 items-center font-bold underline decoration-primary decoration-4 underline-offset-4" href={`/grupos/${group.slug}/editar`}>Corrigir e reenviar</Link> : group.status === "approved" ? <Link className="inline-flex min-h-11 items-center font-bold underline decoration-primary decoration-4 underline-offset-4" href={`/grupos/${group.slug}`}>Abrir grupo</Link> : null}</div></li>)}</ul>;
}
