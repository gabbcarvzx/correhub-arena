# CorreHub

Fundação do CorreHub em Next.js com banco PostgreSQL/Supabase reproduzível. O Gate 2 adiciona autenticação Google com PKCE, sessão SSR em cookies e onboarding governado por RLS; funcionalidades sociais continuam reservadas ao Gate 3.

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
| Supabase JS / SSR | 2.117.2 / 0.12.7 |
| React Hook Form / Zod | 7.88.0 / 4.6.5 |
| Playwright | 1.63.0 (Chromium) |
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

`npm run lint`, `npm run typecheck`, `npm run test` e `npm run build` não dependem de `.env.local`. Para executar login e onboarding localmente, copie apenas os nomes de `.env.example` para `.env.local` e use os valores públicos retornados pela stack local; nunca copie service role, secret key, senha do banco ou token da CLI.

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
npm run test:e2e:install
npm run test:auth
npm run db:stop
```

`db:reset` recria o banco local a partir das migrations e aplica o seed. `db:test` executa a suíte pgTAP, `db:lint` inspeciona os schemas `public` e `private`, e `db:types` regenera `src/types/database.ts` somente a partir de `public`. O gerador normaliza apenas metadados da versão hospedada do PostgREST e finais de linha, permitindo uma comparação byte a byte do contrato local e remoto. A saída completa de `supabase status` contém credenciais locais de desenvolvimento e não deve ser copiada para issues ou logs públicos.

As migrations versionadas são a única fonte de verdade do schema. `supabase/seed.sql` contém apenas São Lourenço da Mata e o singleton `launch_city_id`; fixtures dos testes vivem dentro de transações com rollback. Comandos `--local` operam somente na stack Docker. Comandos `--linked` são reservados à validação deliberada do projeto remoto e nunca fazem parte dos testes locais ou da CI.

`test:auth` aceita exclusivamente `http://127.0.0.1:54321`, cria identidades efêmeras pela Admin API local, obtém cookies com o adapter oficial de `@supabase/ssr`, inicia o Next com somente as três variáveis públicas e apaga as identidades ao final. A service role efêmera permanece no processo de fixture e não entra no Next, browser, GitHub Secrets ou logs. O fluxo é executado duas vezes durante a validação do Gate para comprovar isolamento.

### Auth e callbacks

O app oferece somente **Continuar com Google**. Não há formulário de email/senha, magic link, OTP, login anônimo ou outro provider. O fluxo usa duas camadas distintas:

- Google → Supabase local: `http://127.0.0.1:54321/auth/v1/callback`.
- Google → Supabase remoto: `https://svvthxrixrnrrgosydtg.supabase.co/auth/v1/callback`.
- Supabase → app local: `http://localhost:3000/auth/callback`.
- Supabase → produção: `https://correhub.vercel.app/auth/callback`.

A allowlist usa callbacks exatos. Preview OAuth só pode usar a URL estável exata da branch validada; não é permitido wildcard amplo. O Client Secret Google vive no provider do Supabase e, localmente, em `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_SECRET` ignorada pelo Git. Ele nunca pertence à Vercel ou ao bundle Next.

Para iniciar o provider Google local, forneça o secret somente ao processo da Supabase CLI e reinicie a stack. O `client_id` público fica em `supabase/config.toml`; `skip_nonce_check=false` preserva a validação de nonce.

## Estrutura

- `src/app/page.tsx`: landing institucional mínima.
- `src/app/globals.css`: tokens semânticos e shell responsivo.
- `src/app/page.test.tsx`: teste observável de marca e status.
- `.github/workflows/ci.yml`: validação automática (adicionado no Gate 0).
- `supabase/migrations/`: schema, constraints, helpers, grants e RLS versionados.
- `supabase/tests/database/`: testes pgTAP transacionais.
- `supabase/seed.sql`: dados invariantes de lançamento, sem usuários ou conteúdo fictício.
- `src/types/database.ts`: tipos gerados do schema exposto `public`.
- `src/lib/supabase/`: clientes separados de browser, servidor e Proxy.
- `src/app/login`, `src/app/auth/callback`, `src/app/onboarding`, `src/app/logout`: fluxo Auth e onboarding do Gate 2.
- `tests/e2e/`: jornadas determinísticas contra Supabase Auth local e Chromium.
- `docs/superpowers/specs/`: especificação oficial.
- `docs/superpowers/plans/`: planos aprovados dos Gates.

## Tokens e contraste

Os tokens vivem exclusivamente em `src/app/globals.css`. Pares usados na landing foram medidos pela fórmula WCAG: foreground `#151515` em background `#F8F9F7` (17,29:1), foreground em surface `#FFFFFF` (18,26:1), muted `#70756D` em surface (4,71:1), on-primary `#151515` em primary `#B7F34A` (13,85:1) e primary-hover `#8ED120` (9,82:1). Os estados adicionais usam destructive `#B42318` (6,57:1), success `#167A3E` (5,40:1), warning `#8A5900` (5,98:1), focus `#5B5BD6` em background (5,08:1) e disabled `#6D7569` em surface (4,77:1).

## Git e CI

`main` recebe baselines integrados. O Gate 2 usa `feature/gate-2-auth-onboarding`; correções usam `fix/...`. Commits seguem Conventional Commits e permanecem pequenos. Pull requests executam quality, banco e Auth/E2E local sem usar projeto remoto, conta Google real ou secrets de produção.

## Deploy Vercel

- Projeto: `correhub`, no plano Hobby.
- Repositório conectado: `gabbcarvzx/correhub02` (privado).
- Preview da branch `feature/gate-0-foundation`, validado em 23/09/2026: <https://correhub-tqq5wh5tu-gabbcarvzxs-projects.vercel.app>.
- Preview protegido da branch `feature/gate-2-auth-onboarding`, validado em 26/09/2026: <https://correhub-git-feature-gate-2-auth-on-526ce7-gabbcarvzxs-projects.vercel.app>.
- URL estável de `main`, validada em 23/09/2026: <https://correhub.vercel.app>.
- Finalidade: desenvolvimento e validação pessoal não comercial, com custo obrigatório de R$ 0.

Os deployments ficaram `Ready`, retornaram HTTP 200 e serviram o título `CorreHub` e o status `Em desenvolvimento`, sem erro de runtime. Como o preview usa Deployment Protection, a verificação do conteúdo da branch foi feita pela sessão autenticada da Vercel CLI. O preview do Gate 2 também validou Google → Supabase → callback do app até o onboarding; reload, conclusão do onboarding, suspensão e logout permanecem cobertos pelo E2E determinístico local, sem mutar a conta real para simular suspensão.

## Variáveis e segurança

`.env.local` é ignorado pelo Git. `.env.example` contém somente nomes vazios: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `NEXT_PUBLIC_SITE_URL` e o secret local do provider usado apenas pela Supabase CLI. O browser recebe apenas URL e chave publicável; service role, Google Client Secret, senha do banco, tokens OAuth e token da CLI nunca usam prefixo `NEXT_PUBLIC_`.

`.vercel/`, `.next/`, `node_modules/` e artefatos locais também são ignorados. Nenhum segredo é versionado.

O schema `private` não faz parte da configuração da Data API e não concede acesso de tabela a `anon` ou `authenticated`. O schema `public` usa RLS e grants explícitos; neste Gate, apenas geografia/configuração, a projeção pública de perfis e a atualização restrita do próprio perfil ficam disponíveis.

## Custo e Supabase

O custo obrigatório desta fase é R$ 0. A validação usa ferramentas gratuitas dentro das cotas aplicáveis e não compra domínio, add-on, upgrade ou créditos. O Vercel Hobby só é elegível para desenvolvimento e validação pessoal não comercial; essa condição deve ser reconfirmada antes de qualquer uso comercial.

A Supabase CLI permanece fixada como dependência local. O Gate 2 não adiciona Storage, avatar remoto, descoberta, follows, feed, grupos ou corridas. O Google Client Secret permanece no Supabase Auth; a Vercel recebe somente variáveis públicas usadas pelo app.

### Banco remoto validado

- Organização: `correhub`, plano Free.
- Projeto: `correhub` (`svvthxrixrnrrgosydtg`), região `sa-east-1` (São Paulo), estado `ACTIVE_HEALTHY` em 24/09/2026.
- As oito migrations e o seed versionado foram aplicados; o histórico remoto corresponde ao local.
- O lint remoto não encontrou erros, a Data API permite somente as leituras previstas e nega escrita anônima, domínio futuro e acesso direto ao schema `private`.
- O contrato TypeScript normalizado de `public` é byte a byte idêntico entre local e remoto.
- Nenhum add-on foi selecionado, as chaves JWT legadas estão desativadas e nenhum segredo Supabase foi adicionado ao frontend ou à Vercel.

## Fontes

- [Especificação oficial](docs/superpowers/specs/2026-09-19-correhub-mvp-design.md)
- [Plano aprovado do Gate 0](docs/superpowers/plans/2026-09-19-gate-0-foundation.md)
- [Plano aprovado do Gate 1](docs/superpowers/plans/2026-09-23-gate-1-database-base.md)
- [Plano aprovado do Gate 2](docs/superpowers/plans/2026-09-25-gate-2-auth-onboarding.md)
