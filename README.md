# CorreHub

Fundação do CorreHub: uma landing mínima em Next.js, preparada para evolução por Gates. O Gate 0 não implementa grupos, corridas, perfis, feed, autenticação ou banco de domínio.

## Stack fixada

| Ferramenta | Versão |
| --- | --- |
| Node.js | 24.21.0 (LTS) |
| npm | 11.19.0 |
| Next.js | 16.3.5 |
| React / React DOM | 19.3.0 |
| Tailwind CSS / PostCSS | 4.3.3 |
| TypeScript | 5.9.3 |
| ESLint / eslint-config-next | 9.39.5 / 16.3.5 |
| Vitest | 5.0.1 |
| Vite React plugin | 6.1.1 |
| Testing Library React | 16.3.3 |
| Testing Library Jest DOM | 7.0.1 |
| jsdom | 30.1.0 |
| Supabase CLI (devDependency) | 2.117.0 |

## Setup e scripts

Use Node.js 24.21.0 e npm 11.19.0. Depois, instale o lockfile e execute:

```bash
npm ci
npm run dev
npm run lint
npm run typecheck
npm run test
npm run test:watch
npm run build
```

`npm run lint`, `npm run typecheck`, `npm run test` e `npm run build` não dependem de `.env.local` no Gate 0.

O Next.js 16.3.5 gera `next-env.d.ts` por `next typegen`, por isso o arquivo permanece ignorado conforme a documentação da versão. `agentRules: false` evita que `npm run dev` gere arquivos auxiliares de agentes na raiz do projeto.

## Estrutura

- `src/app/page.tsx`: landing institucional mínima.
- `src/app/globals.css`: tokens semânticos e shell responsivo.
- `src/app/page.test.tsx`: teste observável de marca e status.
- `.github/workflows/ci.yml`: validação automática (adicionado no Gate 0).
- `docs/superpowers/specs/`: especificação oficial.
- `docs/superpowers/plans/`: plano aprovado do Gate 0.

## Tokens e contraste

Os tokens vivem exclusivamente em `src/app/globals.css`. Pares usados na landing foram medidos pela fórmula WCAG: foreground `#151515` em background `#F8F9F7` (17,29:1), foreground em surface `#FFFFFF` (18,26:1), muted `#70756D` em surface (4,71:1), on-primary `#151515` em primary `#B7F34A` (13,85:1) e primary-hover `#8ED120` (9,82:1). Os estados adicionais usam destructive `#B42318` (6,57:1), success `#167A3E` (5,40:1), warning `#8A5900` (5,98:1), focus `#5B5BD6` em background (5,08:1) e disabled `#6D7569` em surface (4,77:1).

## Git e CI

`main` recebe baselines integrados. O trabalho do Gate usa `feature/gate-0-foundation`; correções usam `fix/...`. Commits seguem Conventional Commits e permanecem pequenos. Pull requests executam os mesmos checks locais via GitHub Actions, sem secrets.

## Preview Vercel

- Projeto: `correhub`, no plano Hobby.
- Branch: `feature/gate-0-foundation`.
- Preview validado em 23/09/2026: <https://correhub-tqq5wh5tu-gabbcarvzxs-projects.vercel.app>.
- Finalidade: desenvolvimento e validação pessoal não comercial, com custo obrigatório de R$ 0.

O deployment ficou `Ready`, retornou HTTP 200 e serviu o título `CorreHub` e o status `Em desenvolvimento`. Como o preview usa Deployment Protection, a verificação do conteúdo foi feita pela sessão autenticada da Vercel CLI.

## Variáveis e segurança

`.env.local` é ignorado pelo Git e não é necessário nesta fase. `.env.example` contém apenas comentários. O browser só poderá receber chaves publicáveis em Gates futuros; segredos privilegiados serão server-only. É proibido criar `NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY` ou equivalente.

`.vercel/`, `.next/`, `node_modules/` e artefatos locais também são ignorados. Nenhum segredo é versionado.

## Custo e Supabase

O custo obrigatório desta fase é R$ 0. A validação usa ferramentas gratuitas dentro das cotas aplicáveis e não compra domínio, add-on, upgrade ou créditos. O Vercel Hobby só é elegível para desenvolvimento e validação pessoal não comercial; essa condição deve ser reconfirmada antes de qualquer uso comercial.

A Supabase CLI é preparada como dependência local para o Gate 1. Deliberadamente não há login Supabase, projeto remoto, `supabase init`, `supabase link`, migration, SQL, seed, schema, RLS, Auth ou Storage neste Gate.

## Fontes

- [Especificação oficial](docs/superpowers/specs/2026-09-19-correhub-mvp-design.md)
- [Plano aprovado do Gate 0](docs/superpowers/plans/2026-09-19-gate-0-foundation.md)
