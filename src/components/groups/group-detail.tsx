import Link from "next/link";

import { sanitizeInternalReturnTo } from "@/lib/auth/return-to";
import type { GroupRelation, PublicGroup } from "@/lib/groups/types";

import { GroupFollowButton } from "./group-follow-button";
import { GroupMembershipAction } from "./group-membership-action";

const typeLabel = { community: "Comunidade", professional: "Grupo profissional" } as const;

export function GroupDetail({ group, relation, viewer, isFollowing = false }: {
  group: PublicGroup; relation: GroupRelation | null; viewer: "visitor" | "authenticated"; isFollowing?: boolean;
}) {
  if (group.status !== "approved") {
    const restricted = {
      pending: ["Solicitação em análise", "A equipe do CorreHub está revisando os dados do grupo."],
      rejected: ["Solicitação devolvida", "Revise os dados e o motivo informado antes de reenviar."],
      suspended: ["Grupo indisponível", "As operações deste grupo estão temporariamente suspensas."],
    }[group.status];
    return <section className="mx-auto max-w-3xl border-t-4 border-primary pt-8">
      <p className="foundation-kicker">Grupos</p>
      <h1 className="text-4xl font-black tracking-tight sm:text-5xl">{restricted[0]}</h1>
      <p className="mt-4 max-w-xl text-lg leading-8 text-muted">{restricted[1]}</p>
      {group.isOwner && group.status !== "suspended" ? <Link className="mt-8 inline-flex min-h-11 items-center rounded-full bg-primary px-5 font-black text-on-primary hover:bg-primary-hover" href={`/grupos/${group.slug}/editar`}>Revisar solicitação</Link> : null}
    </section>;
  }

  const returnTo = sanitizeInternalReturnTo(`/grupos/${group.slug}`);
  const loginHref = `/login?${new URLSearchParams({ returnTo }).toString()}`;
  return <article className="mx-auto max-w-5xl">
    <header className="border-b border-border pb-8">
      <div className="flex flex-wrap items-center gap-3 text-sm font-bold uppercase tracking-widest text-muted"><span>{typeLabel[group.type]}</span><span aria-hidden="true">·</span><span>{group.city.name}</span></div>
      <h1 className="mt-4 max-w-4xl text-5xl font-black tracking-tight sm:text-6xl">{group.name}</h1>
      <p className="mt-5 max-w-3xl text-lg leading-8 text-muted">{group.description}</p>
    </header>
    <div className="grid gap-10 py-8 lg:grid-cols-[1fr_18rem]">
      <section aria-labelledby="participation-title">
        <h2 className="text-2xl font-black" id="participation-title">Participação</h2>
        <p className="mt-2 max-w-xl leading-7 text-muted">{group.joinPolicy === "open" ? "A entrada é livre para corredores com conta ativa." : "A gestão analisa cada pedido antes de liberar a entrada."}</p>
        <div className="mt-5">{viewer === "visitor" ? <Link className="inline-flex min-h-11 items-center rounded-full bg-primary px-5 font-black text-on-primary hover:bg-primary-hover" href={loginHref}>Entrar para participar</Link> : <GroupMembershipAction groupId={group.id} joinPolicy={group.joinPolicy} relation={relation} slug={group.slug} />}</div>
      </section>
      <aside className="border-t border-border pt-6 lg:border-l lg:border-t-0 lg:pl-8 lg:pt-0">
        <h2 className="text-xl font-black">Acompanhar</h2>
        <div className="mt-4">{viewer === "visitor" ? <Link className="inline-flex min-h-11 items-center rounded-full border border-border bg-surface px-5 font-bold" href={loginHref}>Entrar para seguir</Link> : <GroupFollowButton groupId={group.id} initialFollowing={isFollowing} slug={group.slug} />}</div>
      </aside>
    </div>
    {group.isOwner ? <nav aria-label="Gestão do grupo" className="border-t border-border pt-6"><Link className="font-bold underline decoration-primary decoration-4 underline-offset-4" href={`/grupos/${group.slug}/configuracoes`}>Gerenciar grupo</Link></nav> : null}
  </article>;
}
