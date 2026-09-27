import Link from "next/link";

export function GroupManagementNav({ slug, showOwnership = false }: { slug: string; showOwnership?: boolean }) {
  const links = [
    ["Grupo", `/grupos/${slug}`], ["Configurações", `/grupos/${slug}/configuracoes`], ["Membros", `/grupos/${slug}/membros`],
    ...(showOwnership ? [["Responsabilidade", `/grupos/${slug}/transferencia`]] : []),
  ];
  return <nav aria-label="Gestão do grupo" className="mb-8 grid grid-cols-2 gap-1 border-b border-border pb-3 sm:flex">{links.map(([label, href]) => <Link className="min-h-11 px-3 py-3 font-bold text-muted hover:text-foreground sm:px-4" href={href} key={href}>{label}</Link>)}</nav>;
}
