# CorreHub

Fundação do CorreHub em Next.js com banco PostgreSQL/Supabase reproduzível. O Gate 1 define schema, constraints, seed e limites iniciais de acesso; os fluxos de autenticação e as funcionalidades de produto continuam reservados aos Gates seguintes.

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

### Banco local

O ambiente de banco exige um runtime compatível com a API do Docker. Com o daemon ativo, use a Supabase CLI fixada no projeto:

```bash
npm run db:start
npm exec --no -- supabase status
npm run db:reset
npm run db:test
npm run db:lint
npm run db:types
npm run db:stop
```

`db:reset` recria o banco local a partir das migrations e aplica o seed. `db:test` executa a suíte pgTAP, `db:lint` inspeciona os schemas `public` e `private`, e `db:types` regenera `src/types/database.ts` somente a partir de `public`. A saída completa de `supabase status` contém credenciais locais de desenvolvimento e não deve ser copiada para issues ou logs públicos.

As migrations versionadas são a única fonte de verdade do schema. `supabase/seed.sql` contém apenas São Lourenço da Mata e o singleton `launch_city_id`; fixtures dos testes vivem dentro de transações com rollback. Comandos `--local` operam somente na stack Docker. Comandos `--linked` são reservados à validação deliberada do projeto remoto e nunca fazem parte dos testes locais ou da CI.

## Estrutura

- `src/app/page.tsx`: landing institucional mínima.
- `src/app/globals.css`: tokens semânticos e shell responsivo.
- `src/app/page.test.tsx`: teste observável de marca e status.
- `.github/workflows/ci.yml`: validação automática (adicionado no Gate 0).
- `supabase/migrations/`: schema, constraints, helpers, grants e RLS versionados.
- `supabase/tests/database/`: testes pgTAP transacionais.
- `supabase/seed.sql`: dados invariantes de lançamento, sem usuários ou conteúdo fictício.
- `src/types/database.ts`: tipos gerados do schema exposto `public`.
- `docs/superpowers/specs/`: especificação oficial.
- `docs/superpowers/plans/`: planos aprovados dos Gates.

## Tokens e contraste

Os tokens vivem exclusivamente em `src/app/globals.css`. Pares usados na landing foram medidos pela fórmula WCAG: foreground `#151515` em background `#F8F9F7` (17,29:1), foreground em surface `#FFFFFF` (18,26:1), muted `#70756D` em surface (4,71:1), on-primary `#151515` em primary `#B7F34A` (13,85:1) e primary-hover `#8ED120` (9,82:1). Os estados adicionais usam destructive `#B42318` (6,57:1), success `#167A3E` (5,40:1), warning `#8A5900` (5,98:1), focus `#5B5BD6` em background (5,08:1) e disabled `#6D7569` em surface (4,77:1).

## Git e CI

`main` recebe baselines integrados. O Gate 1 usa `feature/gate-1-database-base`; correções usam `fix/...`. Commits seguem Conventional Commits e permanecem pequenos. Pull requests executam checks de aplicação e banco sem usar projeto remoto ou secrets de produção.

## Deploy Vercel

- Projeto: `correhub`, no plano Hobby.
- Repositório conectado: `gabbcarvzx/correhub02` (privado).
- Preview da branch `feature/gate-0-foundation`, validado em 23/09/2026: <https://correhub-tqq5wh5tu-gabbcarvzxs-projects.vercel.app>.
- URL estável de `main`, validada em 23/09/2026: <https://correhub.vercel.app>.
- Finalidade: desenvolvimento e validação pessoal não comercial, com custo obrigatório de R$ 0.

Os deployments ficaram `Ready`, retornaram HTTP 200 e serviram o título `CorreHub` e o status `Em desenvolvimento`, sem erro de runtime. Como o preview usa Deployment Protection, a verificação do conteúdo da branch foi feita pela sessão autenticada da Vercel CLI.

## Variáveis e segurança

`.env.local` é ignorado pelo Git e não é necessário nesta fase. `.env.example` contém apenas comentários. O app Next.js ainda não se conecta ao Supabase; essa integração começa no Gate 2. O browser só poderá receber chaves publicáveis em Gates futuros; segredos privilegiados serão server-only. É proibido criar `NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY` ou equivalente.

`.vercel/`, `.next/`, `node_modules/` e artefatos locais também são ignorados. Nenhum segredo é versionado.

O schema `private` não faz parte da configuração da Data API e não concede acesso de tabela a `anon` ou `authenticated`. O schema `public` usa RLS e grants explícitos; neste Gate, apenas geografia/configuração, a projeção pública de perfis e a atualização restrita do próprio perfil ficam disponíveis.

## Custo e Supabase

O custo obrigatório desta fase é R$ 0. A validação usa ferramentas gratuitas dentro das cotas aplicáveis e não compra domínio, add-on, upgrade ou créditos. O Vercel Hobby só é elegível para desenvolvimento e validação pessoal não comercial; essa condição deve ser reconfirmada antes de qualquer uso comercial.

A Supabase CLI permanece fixada como dependência local. O Gate 1 não configura Google OAuth, callback, sessão SSR, Storage ou credenciais Supabase na Vercel. O único projeto remoto Free é criado e validado depois que migrations, seed, pgTAP, lint e CI locais estiverem verdes.

## Fontes

- [Especificação oficial](docs/superpowers/specs/2026-09-19-correhub-mvp-design.md)
- [Plano aprovado do Gate 0](docs/superpowers/plans/2026-09-19-gate-0-foundation.md)
- [Plano aprovado do Gate 1](docs/superpowers/plans/2026-09-23-gate-1-database-base.md)
