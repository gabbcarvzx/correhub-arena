# CorreHub Gate 2 — Auth + Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** implementar autenticação Google segura com Supabase SSR e onboarding idempotente do CorreHub, sem antecipar funcionalidades sociais do Gate 3.

**Architecture:** O Supabase Auth executará Google OAuth com PKCE e manterá a sessão em cookies por clientes separados de browser e servidor; o `proxy.ts` do Next.js 16 renovará cookies, enquanto páginas, Route Handlers e Server Actions repetirão autenticação e autorização no ponto de uso. Uma migration nova criará a fundação mínima da conta na mesma transação de `auth.users`, com reparo idempotente estreito para contas históricas, e o onboarding atualizará o próprio `profile` atomicamente sob RLS e constraints existentes.

**Tech Stack:** Next.js 16.3.5 App Router, React 19.3.0, TypeScript 5.9.3 strict, Supabase CLI 2.117.0, PostgreSQL 17, Supabase Auth, `@supabase/supabase-js` 2.117.2, `@supabase/ssr` 0.12.7, Zod 4.6.5, React Hook Form 7.88.0, `@hookform/resolvers` 5.9.1, Vitest 5.0.1, Testing Library 16.3.3 e Playwright 1.63.0 com Chromium.

**Spec:** `docs/superpowers/specs/2026-09-19-correhub-mvp-design.md`

## Global Constraints

- Baseline verificada em 25/09/2026: `main` limpa em `94c9c24`, repositório privado `gabbcarvzx/correhub02`, projeto Vercel `correhub`, Supabase remoto `correhub` (`svvthxrixrnrrgosydtg`) Free em `sa-east-1`, sete migrations, 26 tabelas, schemas `public`/`private` e view `public.profile_directory`.
- As sete migrations do Gate 1 são imutáveis. Toda alteração persistente do Gate 2 entra em migration nova criada pela CLI; Dashboard não é fonte de schema.
- Investimento obrigatório **R$ 0**. Não habilitar Supabase Pro, Vercel Pro, Google Workspace, add-on, domínio, SMTP, SMS ou serviço pago.
- O único método de login de produto é Google. Não criar UI nem rota de email/senha, magic link, OTP, GitHub, Apple ou login anônimo.
- O app usa somente URL Supabase e publishable key no browser. Database password, CLI token, secret key/service role, JWT signing key e Google Client Secret nunca entram no bundle, Git, README, logs, GitHub Actions ou Vercel.
- `@supabase/ssr` permanece beta; antes da instalação, a Task 1 reconfirma registry, peer dependencies e exemplos oficiais. Versões diretas são exatas e `package-lock.json` é versionado; não usar prerelease, `--force` ou `--legacy-peer-deps`.
- Autorização server-side nunca usa `getSession()` como prova de identidade. `getClaims()` valida o JWT e renova quando aplicável; `getUser()` é reservado a consultas que precisam confirmar o registro atual no Auth, como callback/prefill. Banco/RLS revalida conta ativa e ownership em mutações.
- `src/proxy.ts` renova/propaga cookies. Ele não é a camada final de autorização, não consulta domínio e não substitui checks em páginas, Server Actions ou Route Handlers.
- Conteúdo autenticado é dinâmico e não pode ser armazenado em cache público. Respostas de callback, erro Auth, onboarding e conta indisponível usam `private, no-store`; respostas que escrevem cookies preservam os headers produzidos por `@supabase/ssr`.
- Redirects usam origens configuradas e caminhos internos sanitizados. Nunca construir destino confiável de `Host`, `X-Forwarded-Host`, URL absoluta fornecida pelo cliente ou metadata do provedor.
- Metadata Google só pode sugerir `full_name` na interface. Não concede role, status, username, cidade, privacidade ou conclusão de onboarding; avatar Google não é persistido neste Gate.
- A conta nasce sem platform role. O trigger não lê email ou metadata e não cria admin/moderator.
- Gate 2 não implementa descoberta, follows, edição social completa, páginas públicas avançadas, grupos, corridas, agenda, feed, notificações, uploads, Storage, painel administrativo, analytics ou SEO.
- Uma request Auth deve falhar com mensagem segura quando configuração necessária estiver ausente, sem imprimir valores. Builds/testes recebem valores locais públicos de ensaio e nunca dependem de secrets remotos.
- A execução usa a branch `feature/gate-2-auth-onboarding`, commits pequenos e PR; não trabalha diretamente em `main`.

## Review Focus

1. **Open redirect/callback manipulation:** `returnTo`, origem do callback, URLs percent-encoded, barras invertidas e rotas de loop precisam de allowlist estrutural e testes negativos.
2. **Cookies e refresh SSR incorretos:** um `setAll` incompleto, cache público ou confiança em `getSession()` pode causar logout em reload, sessão cruzada ou autorização com token não validado.
3. **Provisionamento parcial:** `auth.users`, `profiles` e `account_controls` precisam nascer numa transação e ser reparáveis sem reativar conta suspensa nem duplicar registros.
4. **Segredos no cliente/log:** Google Client Secret, service role, token CLI e password do banco devem permanecer exclusivamente no provedor ou processo local de teste, nunca sob prefixo `NEXT_PUBLIC_`.
5. **Drift de redirects entre local, preview e produção:** Google → Supabase e Supabase → CorreHub são callbacks diferentes; cada ambiente precisa de URL exata, sem wildcard amplo ou origem derivada de header não confiável.

---

## 1. Decisões estruturais

### 1.1 Fronteira entre Auth, app e banco

| Camada | Responsabilidade | Não pode decidir |
| --- | --- | --- |
| Google Auth Platform | autenticar a conta Google com `openid`, `email`, `profile` e devolver ao callback do Supabase | role, username, cidade, conta ativa ou onboarding |
| Supabase Auth | OAuth/PKCE, identidade `auth.users`, emissão/refresh/revogação de sessão | autorização de domínio baseada só em metadata/JWT antigo |
| `src/proxy.ts` | chamar `getClaims()`, transportar cookies renovados entre request/response e aplicar headers seguros | liberar rota ou mutação como autoridade final |
| Server Components/Route Handlers/Server Actions | validar sessão atual, carregar estado da conta, aplicar redirects e mapear erros seguros | confiar em campos ocultos, payload de ID ou estado do cliente |
| PostgreSQL/RLS | identidade via `auth.uid()`, conta ativa, constraints, cidade ativa, unicidade e escrita do próprio profile | UX, labels ou destino de navegação |

O app não mantém tokens em `localStorage`, não copia access/refresh token para URLs e não cria cookie próprio de autenticação. `@supabase/ssr` é o único responsável pelo formato/chunking dos cookies Supabase.

### 1.2 Dependências e versões

As versões pesquisadas no registry em 25/09/2026 são as listadas em **Tech Stack**. A execução deve repetir `npm view <pacote> version peerDependencies engines --json`, confirmar que continuam estáveis e compatíveis com Node 24/React 19, e instalar exatamente:

```bash
npm install --save-exact @supabase/supabase-js@2.117.2 @supabase/ssr@0.12.7 zod@4.6.5 react-hook-form@7.88.0 @hookform/resolvers@5.9.1
npm install --save-dev --save-exact @playwright/test@1.63.0
```

Se o registry tiver uma patch estável posterior na data da execução, ela só substitui os números acima após conferir documentação/changelog, peers, Node 24 e ausência de prerelease. Registrar a adaptação no ledger. Supabase CLI permanece em 2.117.0, salvo incompatibilidade comprovada.

### 1.3 Clientes Supabase e validação de identidade

- `src/lib/supabase/client.ts`: singleton por ambiente de browser usando `createBrowserClient<Database>()`; consome somente `NEXT_PUBLIC_SUPABASE_URL` e `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`.
- `src/lib/supabase/server.ts`: factory `async` por request usando `createServerClient<Database>()`, `await cookies()` e API atual `getAll`/`setAll`. Em Server Components, falha de escrita de cookie é tolerada somente porque o Proxy faz refresh; Route Handlers/Actions propagam cookies.
- `src/lib/supabase/proxy.ts`: factory por `NextRequest`; copia cookies para a request e para a `NextResponse` retornada, preserva atributos/cabeçalhos da biblioteca e chama imediatamente `auth.getClaims()` antes de qualquer lógica adicional.
- `src/proxy.ts`: único arquivo de convenção Next 16, no mesmo nível de `src/app`; exclui assets estáticos, imagens e favicon, não exclui páginas autenticadas nem Server Actions.
- `src/lib/auth/current-account.ts`: Data Access Layer server-only. `requireClaims()` usa `getClaims()`; `getCurrentAuthUser()` usa `getUser()` apenas quando o registro Auth/metadata fresco é necessário; `getCurrentAccountState()` chama a RPC estreita e nunca acessa `private` diretamente.
- Nenhum módulo exporta service-role client. O app de produção não recebe service role.

### 1.4 Provisionamento e recuperação idempotente

A migration Gate 2 cria:

```sql
private.provision_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
```

O trigger `after insert on auth.users` executa, na transação de criação da identidade:

```sql
insert into public.profiles (id) values (new.id)
on conflict (id) do nothing;

insert into private.account_controls (user_id, status)
values (new.id, 'active')
on conflict (user_id) do nothing;
```

Ele não copia metadata, não cria role e não engole erros inesperados. Como o trigger roda na mesma transação, falha real reverte também `auth.users`, evitando metade de uma conta.

Para usuários históricos que antecedam o trigger, a migration cria `public.ensure_current_account_foundation()` como exceção deliberada e mínima ao padrão de helpers privados. É `SECURITY DEFINER`, `VOLATILE`, `SET search_path=''`, sem argumentos, exige `auth.uid() IS NOT NULL`, insere apenas o UUID atual com `ON CONFLICT DO NOTHING` e retorna `account_status`/`onboarding_completed`. Ela jamais altera uma linha existente, portanto não reativa `suspended`/`deleted`. Execução é revogada de `PUBLIC`/`anon` e concedida somente a `authenticated`; owner é `postgres`. Callback chama essa RPC após a troca de código.

`public.get_current_account_state()` é `STABLE SECURITY DEFINER`, sem argumentos, com as mesmas proteções, e retorna somente `account_status` e `onboarding_completed` do usuário atual. A superfície pública é justificada porque `private` não é exposto pela Data API; testes provam ausência de personificação, motivo interno e enumeração.

### 1.5 Onboarding atômico

Completar onboarding usa um único `UPDATE public.profiles ... WHERE id = auth.uid()` via cliente autenticado. Não criar RPC privilegiada: o update já é atômico, a policy `profiles_update_own` exige conta ativa, e constraints/triggers existentes impõem username, campos obrigatórios e cidade ativa.

Campos do formulário:

| Campo | Obrigatório | Persistência/validação | Rótulo PT-BR |
| --- | --- | --- | --- |
| `username` | sim | trim, lowercase, regex `^[a-z0-9_]{3,30}$`; banco decide reserva/unicidade | Nome de usuário |
| `full_name` | sim | trim, 2–80; sugestão Google apenas como valor inicial | Nome |
| `city_id` | sim | UUID de `cities.is_active=true`; launch city pré-selecionada via `app_settings` | Cidade |
| `running_level` | sim | `beginner`, `intermediate`, `advanced` | Nível de corrida |
| `preferred_distance` | sim | `up_to_5k`, `5k_to_10k`, `10k_to_21k`, `over_21k`, `flexible` | Distância preferida |
| `bio` | não | vazio → `null`; trim; 1–300 quando preenchida | Bio |
| `pace_seconds_per_km` | não | entrada humana validada e convertida para 120–1800 segundos/km | Pace aproximado |
| `is_private` | sim | checkbox, default `false`, explicação clara de perfil público/privado | Perfil privado |

O mesmo `UPDATE` grava `onboarding_completed=true`. Erros `23505` viram “Este nome de usuário já está em uso”; `23514` de reserva/constraints vira mensagem específica sem SQL interno. Se duas pessoas concorrerem, somente uma confirma; a outra mantém valores e recebe conflito recuperável. Avatar fica no padrão e `avatar_url` permanece `null`; upload e mídia controlada não entram neste Gate.

### 1.6 Retorno seguro e origem confiável

`sanitizeInternalReturnTo(input, fallback='/')` é a única função aceita para destino pós-login/onboarding. Ela:

- aceita apenas string iniciada por uma única `/`;
- faz parse contra uma base fixa, exige mesma origem sintética e devolve apenas `pathname + search`;
- rejeita URL absoluta, `//`, `\\`, controles, encoding inválido, dupla decodificação que produza separador, `%2f`, `%5c`, protocolo e host;
- remove fragmento;
- rejeita rotas de loop `/login`, `/auth/callback`, `/auth/auth-code-error`, `/logout`, `/onboarding` e `/account-unavailable`, incluindo subpaths equivalentes;
- retorna `/` para qualquer caso inválido.

`getConfiguredAppOrigin()` lê `NEXT_PUBLIC_SITE_URL`, normaliza sem barra final e exige URL absoluta `https:`; somente `http://localhost:3000` é permitido fora de HTTPS. Não usa `request.url`, `Host` nem `X-Forwarded-Host` para formar redirects confiáveis.

### 1.7 Callback, sessão e cache

Fluxo completo:

```text
visitante → /login?returnTo=/destino
→ browser client signInWithOAuth(provider=google, PKCE, scopes mínimos,
  redirectTo=<origem configurada>/auth/callback?returnTo=<interno codificado>)
→ Google → callback do Supabase → /auth/callback
→ exchangeCodeForSession → cookies SSR
→ getUser + ensure_current_account_foundation
→ suspenso/deleted: /account-unavailable
→ onboarding incompleto: /onboarding?returnTo=...
→ completo: returnTo sanitizado ou /
```

Callback sem `code`, código inválido/repetido, exchange falho ou estado de conta indisponível redireciona para `/auth/auth-code-error` com um código público curto, nunca a mensagem interna. O código OAuth não aparece em logs nem no redirect final.

Rotas que leem sessão exportam `dynamic = 'force-dynamic'`. Callback e respostas autenticadas definem `Cache-Control: private, no-store`; testes verificam ausência de token/code no corpo, URL final e console. O Proxy faz refresh; a autorização real é refeita na página/action e no banco.

### 1.8 Matriz de rotas

| Estado | `/` | `/login` | `/auth/callback` | `/onboarding` | `/logout` | `/account-unavailable` |
| --- | --- | --- | --- | --- | --- | --- |
| visitante | público | Google login | técnico | redireciona a login com retorno | mostra confirmação/ação sem mutar em GET | redireciona a login ou mostra estado neutro |
| autenticado incompleto/ativo | público | redireciona a onboarding | exchange/reparo | permitido | POST/Server Action permitido | redireciona a onboarding |
| autenticado completo/ativo | público | destino seguro ou `/` | exchange/reparo | destino seguro ou `/` | POST/Server Action permitido | redireciona `/` |
| suspenso/deleted | público + estado de conta | `/account-unavailable` | `/account-unavailable` | bloqueado | permitido | mensagem segura + logout |
| sessão inválida/expirada | público | login | erro seguro | login com retorno | estado idempotente | login |

Não existe dashboard novo. A Home pode exibir apenas ação de login/logout e estado de onboarding necessário para navegar, preservando o shell do Gate 0.

### 1.9 Ambientes e callbacks em duas camadas

| Ambiente | Google Authorized JavaScript origin | Google → Supabase Authorized redirect URI | Supabase → CorreHub allowlist |
| --- | --- | --- | --- |
| local | `http://localhost:3000` | `http://127.0.0.1:54321/auth/v1/callback` | `http://localhost:3000/auth/callback` |
| preview controlado | origem exata da URL estável da branch Gate 2, se OAuth for exercitado | `https://svvthxrixrnrrgosydtg.supabase.co/auth/v1/callback` | callback exato da mesma branch |
| produção | `https://correhub.vercel.app` | `https://svvthxrixrnrrgosydtg.supabase.co/auth/v1/callback` | `https://correhub.vercel.app/auth/callback` |

Supabase remoto usa Site URL `https://correhub.vercel.app`. Não cadastrar `https://*.vercel.app/**`, `https://**`, host arbitrário ou callback por commit. O preview Gate 2 recebe variável Vercel específica da branch e uma URL de branch estável exata; previews comuns sem allowlist exibem login indisponível de forma segura em vez de redirecionar para origem diferente. Após o Gate, remover callback de preview obsoleto ou manter somente a branch estável documentada se continuar necessária.

Google OAuth Client é do tipo **Web application** e solicita apenas `openid`, `email`, `profile`. O Google Client Secret fica no provider do Supabase remoto e, para Auth local, em variável fornecida à CLI e ignorada pelo Git. Ele nunca vai para Vercel.

Cadastro por email fica desabilitado em `supabase/config.toml` (`[auth.email].enable_signup=false`) e na configuração remota; login anônimo e SMS continuam desabilitados. O harness cria usuários com senha exclusivamente pela Admin API da stack local, fora da UI e do projeto remoto, para obter sessões determinísticas sem introduzir um método de login de produto.

### 1.10 Variáveis de ambiente

`.env.example` contém nomes vazios e comentários de escopo:

```dotenv
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
NEXT_PUBLIC_SITE_URL=

# Somente Supabase CLI local; nunca é lida pelo app Next.js nem enviada à Vercel.
SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_SECRET=
```

O Client ID Google é identificador público e será registrado em `supabase/config.toml` conforme o formato oficial vigente; o secret usa `env(SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_SECRET)`. Se a CLI 2.117.0 suportar interpolação também em `client_id`, preferir variável server-only `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID`; confirmar em `supabase start --help`/documentação e no start local antes de adotar. Não inventar sintaxe.

Vercel recebe apenas as três variáveis `NEXT_PUBLIC_*`: Production com origem estável e Preview somente para a branch controlada. Google Client Secret permanece no Supabase Auth. Alteração de env exige novo deployment.

### 1.11 Estratégia de testes

- **Vitest unitário:** returnTo/origem, schemas Zod, labels, normalização de formulário, mapeamento de erros, estados de rota e comportamento do Proxy com mocks de cookie/Auth.
- **Testing Library:** login, onboarding, erros próximos ao campo, loading, submit duplicado, privacidade, cidade, logout e acessibilidade básica.
- **pgTAP:** trigger, idempotência, reparo, ausência de role/metadata, account control, conta suspensa, cidade ativa, concorrência/username e privilégios das novas funções.
- **Integração Auth local:** cria usuários somente no GoTrue local, confirma que o trigger executa e usa sessão real em cookies. Nenhum fixture entra no seed.
- **Playwright Chromium:** visitante → login, sessão incompleta → onboarding, conclusão → retorno, reload, refresh/revogação inválida, logout e duas abas. Google real não roda na CI.
- **Smoke assistido:** OAuth Google real local, preview controlado e produção após configuração; humano intervém apenas em login/consentimento/2FA/CAPTCHA.

O harness não cria endpoint no app. `tests/e2e/support/local-auth.ts` recusa URL diferente de `http://127.0.0.1:54321`, usa a service role local somente no processo Node do Playwright para criar/apagar identidades e usa `@supabase/ssr` com cookie adapter em memória para obter cookies de uma sessão local de teste. A chave nunca é enviada ao browser, ao Next ou ao log. Artefatos `test-results/`, `playwright-report/` e estado de autenticação ficam ignorados.

### 1.12 CSRF e mutações

Onboarding e logout usam Server Actions POST. Mantém-se a proteção padrão do Next 16 que compara `Origin` com `Host`/`X-Forwarded-Host`; `serverActions.allowedOrigins` não é configurado. Cada Action revalida identidade e conta, não aceita `user_id`, não confia em campos ocultos e retorna somente erros de domínio. Callback é GET de protocolo protegido pelo PKCE/state do Supabase e não aceita ação de domínio. Logout usa `signOut({ scope: 'local' })`, é idempotente e não muta em GET.

---

## 2. Mapa de arquivos

| Caminho | Operação | Responsabilidade |
| --- | --- | --- |
| `package.json`, `package-lock.json` | modificar | dependências fixadas e scripts `test:e2e`, `test:e2e:install`, `test:auth` |
| `vitest.config.ts` | modificar | incluir `src/**/*.test.ts` e `.tsx` sem perder jsdom/setup |
| `.env.example`, `.gitignore` | modificar | contrato de env vazio e artefatos Playwright/Auth local ignorados |
| `supabase/config.toml` | modificar | Site URL/callback local exatos e provider Google local com secret por env |
| `supabase/migrations/*_auth_account_provisioning.sql` | criar | trigger, reparo idempotente e estado atual da conta |
| `supabase/tests/database/100_auth_provisioning_test.sql` | criar | pgTAP do trigger/RPC/grants/idempotência |
| `src/types/database.ts` | regenerar | contrato gerado incluindo RPCs; nunca editar manualmente |
| `src/lib/env/public.ts` | criar | leitura/validação de URL, publishable key e site origin sem revelar valores |
| `src/lib/supabase/client.ts` | criar | browser client |
| `src/lib/supabase/server.ts` | criar | server client por request |
| `src/lib/supabase/proxy.ts` | criar | refresh e propagação de cookies |
| `src/proxy.ts` | criar | convenção Next 16 e matcher |
| `src/lib/auth/return-to.ts` | criar | sanitização única de destino interno |
| `src/lib/auth/current-account.ts` | criar | DAL server-only para claims/user/estado |
| `src/lib/auth/route-state.ts` | criar | decisão pura de destino por sessão/onboarding/status |
| `src/lib/validations/onboarding.ts` | criar | Zod, normalização e labels dos enums |
| `src/app/login/page.tsx`, `src/app/login/login-button.tsx` | criar | login Google e estados seguros |
| `src/app/auth/callback/route.ts` | criar | exchange, reparo e redirect |
| `src/app/auth/auth-code-error/page.tsx` | criar | erro recuperável sem detalhes internos |
| `src/app/onboarding/page.tsx` | criar | guarda server-side, cidades ativas e valores iniciais |
| `src/app/onboarding/onboarding-form.tsx` | criar | formulário RHF mobile first |
| `src/app/onboarding/actions.ts` | criar | update atômico do próprio profile |
| `src/app/logout/page.tsx`, `src/app/logout/actions.ts` | criar | confirmação e logout POST local |
| `src/app/account-unavailable/page.tsx` | criar | conta suspensa/deleted e saída segura |
| `src/app/page.tsx`, `src/app/globals.css` | modificar minimamente | navegação Auth/onboarding sem feature Gate 3 |
| `src/**/*.test.ts`, `src/**/*.test.tsx` | criar/modificar | unidades e componentes por responsabilidade |
| `playwright.config.ts` | criar | Chromium, servidor controlado e artefatos |
| `tests/e2e/auth-onboarding.spec.ts` | criar | jornadas críticas de browser |
| `tests/e2e/support/local-auth.ts` | criar | fixtures Auth locais fora do app/bundle |
| `scripts/run-auth-e2e.mjs` | criar | obtém status local sem logar secrets, inicia app/teste e encerra processos |
| `.github/workflows/ci.yml` | modificar | Auth/E2E local no job que já inicia Supabase |
| `README.md` | modificar | setup Auth, callbacks, env e operação sem secrets |

Não criar endpoint `/api/test`, client service-role, bucket, migration de Gate 3 ou documento duplicado.

---

## 3. Interfaces produzidas e consumidas

```ts
type AccountStatus = "active" | "suspended" | "deleted";

type CurrentAccountState = {
  accountStatus: AccountStatus;
  onboardingCompleted: boolean;
};

type AuthRouteState =
  | { kind: "anonymous" }
  | { kind: "active_incomplete"; userId: string }
  | { kind: "active_complete"; userId: string }
  | { kind: "unavailable"; userId: string; status: "suspended" | "deleted" };

function sanitizeInternalReturnTo(
  input: string | null | undefined,
  fallback?: string,
): string;

function getConfiguredAppOrigin(): string;
function createBrowserSupabaseClient(): SupabaseClient<Database>;
async function createServerSupabaseClient(): Promise<SupabaseClient<Database>>;
async function requireClaims(): Promise<{ sub: string }>;
async function getCurrentAccountState(): Promise<CurrentAccountState | null>;
```

Banco exposto por tipos gerados:

```sql
public.ensure_current_account_foundation()
  returns table(account_status text, onboarding_completed boolean)

public.get_current_account_state()
  returns table(account_status text, onboarding_completed boolean)
```

Server Action do onboarding aceita apenas `FormData`, valida com Zod e retorna união discriminada `{ status: 'field_error' | 'conflict' | 'forbidden' | 'temporary_error'; ... }` ou redireciona após sucesso. Nenhuma interface aceita `user_id`, role ou status de conta do cliente.

---

## Tasks

### Task 1: Abrir a branch e fixar o contrato técnico do Gate 2

**Files:** modificar `package.json`, `package-lock.json`, `vitest.config.ts`, `.env.example`, `.gitignore`.

**Interfaces:** produz dependências/scripts e contrato de env consumidos pelas Tasks seguintes.

- [ ] Confirmar `main` limpa/sincronizada, HEAD `94c9c24` ou sucessor legítimo, sete migrations intactas e nenhum trabalho Gate 2 existente; criar `feature/gate-2-auth-onboarding` sem editar migrations antigas.
- [ ] Recuperar Node 24.21.0 conforme `.nvmrc`; executar `node --version`, `npm --version`, `npm ci` e `npm exec --no -- supabase --version`.
- [ ] Consultar registry e documentação oficial novamente; registrar versões estáveis escolhidas e instalar dependências exatas do item 1.2.
- [ ] Ampliar Vitest para `src/**/*.test.{ts,tsx}` e adicionar scripts claros: `test:e2e`, `test:e2e:install` e `test:auth`; nenhum script usa projeto remoto.
- [ ] Atualizar `.env.example` somente com nomes vazios do item 1.10 e comentários de escopo; adicionar `playwright-report/`, `test-results/` e arquivos temporários Auth/E2E ao `.gitignore`.
- [ ] Provar que `.env.local`, artefatos Playwright e `.vercel/` são ignorados com `git check-ignore -v`; `git ls-files` deve retornar vazio para todos.
- [ ] Executar `npm run lint`, `npm run typecheck`, `npm run test`, `npm run build` com valores locais públicos de ensaio apenas se o código ainda não os consumir; exigir baseline verde.
- [ ] Revisar `git diff`, lockfile, licenças e `npm audit`; não aceitar vulnerabilidade alta/crítica sem ruling e correção.
- [ ] Commit: `chore: add pinned Supabase Auth dependencies`.

**Expected:** branch isolada, dependências reproduzíveis, zero secret e qualidade do Gate 1 preservada.

### Task 2: Provisionar a fundação da conta com TDD no PostgreSQL

**Files:** criar migration `*_auth_account_provisioning.sql`, `supabase/tests/database/100_auth_provisioning_test.sql`; regenerar `src/types/database.ts`.

**Interfaces:** trigger `private.provision_auth_user`; RPCs `ensure_current_account_foundation` e `get_current_account_state`.

- [ ] Criar o teste pgTAP primeiro para: novo `auth.users` gera exatamente um profile incompleto e um control active; não cria role; ignora metadata de username/admin/avatar; repetição não duplica; suspensão não é revertida; `anon` não executa RPC; authenticated não personifica terceiro; funções têm owner/search_path/grants esperados.
- [ ] Executar `npm run db:start`, `npm run db:reset`, depois somente o novo teste e observar RED por objetos ausentes; registrar a falha esperada no ledger.
- [ ] Criar migration nova via `npm exec --no -- supabase migration new auth_account_provisioning`; não alterar os sete arquivos aplicados.
- [ ] Implementar trigger/RPCs exatamente conforme itens 1.4 e 3, com nomes qualificados, `search_path=''`, owner `postgres`, revogação de `PUBLIC`/`anon` e grant mínimo a `authenticated`.
- [ ] Testar falha transacional: provocar erro controlado em fixture e confirmar que não sobra `auth.users` sem fundação; rollback do teste remove todas as identidades.
- [ ] Testar recuperação de perfil ausente, control ausente e ambos ausentes; provar que registro suspenso/deleted e roles existentes permanecem inalterados.
- [ ] Executar `npm run db:reset`, `npm run db:test`, `npm run db:lint`; todo pgTAP e lint devem ficar verdes.
- [ ] Executar `npm run db:types` e `git diff --exit-code` após segunda geração; as duas RPCs aparecem tipadas, `private` continua ausente.
- [ ] Commit: `feat: provision authenticated accounts idempotently`.

**Expected:** criação Auth transacional, reparo seguro e nenhuma elevação automática.

### Task 3: Criar clientes SSR, validação de env e Proxy de refresh

**Files:** criar `src/lib/env/public.ts`, `src/lib/supabase/client.ts`, `server.ts`, `proxy.ts`, `src/proxy.ts` e testes focados.

**Interfaces:** factories Supabase e `updateSession(request)`.

- [ ] Escrever testes RED para env ausente/malformada, singleton browser, cookies server `getAll/setAll`, cópia request/response, matcher e chamada a `getClaims()`; incluir caso de refresh inválido sem vazamento de erro.
- [ ] Implementar validação lazy das três variáveis públicas; erro contém somente nome da variável, nunca valor. Build/typecheck não deve contactar Supabase.
- [ ] Implementar browser/server clients com generics `Database` e API atual documentada de `@supabase/ssr` 0.12.7.
- [ ] Implementar `updateSession` iniciando resposta a partir da request, espelhando cada cookie renovado nos dois lados e preservando opções/cabeçalhos da biblioteca.
- [ ] Criar `src/proxy.ts` e matcher que exclui `_next/static`, `_next/image`, favicon e assets com extensão; não fazer redirects de autorização no Proxy.
- [ ] Marcar resposta com sessão/Set-Cookie como `private, no-store`; provar que uma request anônima não recebe conteúdo de outra identidade.
- [ ] Executar os testes novos, `npm run lint`, `npm run typecheck`, `npm run build` com env local pública; exigir GREEN.
- [ ] Commit: `feat: add Supabase SSR session clients`.

**Expected:** refresh SSR oficial para Next 16 sem `middleware.ts`, `getSession()` ou service role.

### Task 4: Restringir origens e destinos OAuth

**Files:** criar `src/lib/auth/return-to.ts`, `src/lib/auth/origin.ts` e testes unitários.

**Interfaces:** `sanitizeInternalReturnTo`, `getConfiguredAppOrigin`, `buildAuthCallbackUrl`.

- [ ] Escrever tabela de testes RED com aceitos `/`, `/corridas/id`, `/corridas/id?dia=1`; rejeitados URL absoluta, protocol-relative, `javascript:`, backslash, controles, `%2f`, `%5c`, dupla codificação, percent inválido, host, fragmento e cada rota de loop.
- [ ] Testar origem: HTTPS produção/preview e localhost HTTP passam; HTTP remoto, credentials na URL, query/hash, path não raiz e URL inválida falham sem ecoar valor.
- [ ] Implementar funções puras, sem `decodeURIComponent` repetido inseguro e sem usar headers da request.
- [ ] Implementar callback URL com `URL` e `URLSearchParams`; `returnTo` já sanitizado é codificado uma única vez.
- [ ] Adicionar teste de round-trip que prova que o callback recupera exatamente pathname+query interno e nunca transforma encoding em origem externa.
- [ ] Executar `npm run test`, lint e typecheck.
- [ ] Commit: `security: constrain OAuth redirects and return paths`.

**Expected:** um único boundary testado para redirects, sem open redirect ou loop Auth.

### Task 5: Implementar estado atual e proteção server-side de rotas

**Files:** criar `src/lib/auth/current-account.ts`, `src/lib/auth/route-state.ts`, testes; preparar `src/app/account-unavailable/page.tsx`.

**Interfaces:** `requireClaims`, `getCurrentAccountState`, `resolveAuthRouteState`.

- [ ] Escrever testes RED para anonymous, active incomplete, active complete, suspended, deleted, profile/control ausente, Auth indisponível e claims expiradas.
- [ ] Implementar `requireClaims()` com `getClaims()`; não ler `getSession()`. Implementar `getCurrentAuthUser()` com `getUser()` somente para metadata fresca.
- [ ] Implementar leitura da RPC `get_current_account_state`; ausência/inconsistência é estado seguro, não `active` presumido.
- [ ] Implementar decisão pura de rota conforme matriz 1.8 e aplicar `sanitizeInternalReturnTo` antes de qualquer redirect.
- [ ] Criar página `account-unavailable` sem motivo interno, role ou dado operacional; incluir somente explicação curta e ação segura de logout quando autenticado.
- [ ] Marcar páginas autenticadas dinâmicas/no-store e testar que status suspenso bloqueia onboarding mesmo com JWT ainda válido.
- [ ] Executar testes, lint, typecheck e build.
- [ ] Commit: `feat: enforce authenticated account state`.

**Expected:** nenhuma rota depende apenas de cookie ou claim para conta ativa/onboarding.

### Task 6: Implementar Google login e callback PKCE

**Files:** criar `src/app/login/page.tsx`, `login-button.tsx`, `src/app/auth/callback/route.ts`, `src/app/auth/auth-code-error/page.tsx`, testes.

**Interfaces:** `signInWithOAuth({ provider:'google' })`, callback GET e estados de erro públicos.

- [ ] Escrever testes RED da página/botão para ação “Continuar com Google”, loading, erro recuperável, scopes mínimos, callback configurado e preservação do returnTo sanitizado.
- [ ] Implementar botão Client Component usando browser client e `redirectTo` montado apenas pela origem configurada; usar `queryParams`/`scopes` mínimos oficiais, sem prompt invasivo ou acesso a serviços Google.
- [ ] Escrever testes RED do Route Handler: code ausente, code inválido, exchange falho, callback repetido, conta incompleta/completa/suspensa e Supabase indisponível.
- [ ] Implementar callback: ler code sem log, `exchangeCodeForSession`, `getUser()`, RPC `ensure_current_account_foundation`, resolver estado e redirecionar por origem/returnTo seguros.
- [ ] Garantir `Cache-Control: private, no-store`; resposta/erro/log de teste não contém code, access token, refresh token ou mensagem SQL.
- [ ] Implementar `/auth/auth-code-error` em PT-BR com retry para `/login` e sem detalhes do provedor.
- [ ] Testar que login de usuário já autenticado não cria loop: incompleto vai onboarding; completo vai destino; suspenso vai conta indisponível.
- [ ] Executar testes, lint, typecheck e build.
- [ ] Commit: `feat: add Google login and secure callback`.

**Expected:** PKCE chega a uma sessão em cookie e a rota nunca usa destino externo/controlado por header.

### Task 7: Implementar onboarding mobile first e conclusão atômica

**Files:** criar validation/page/form/actions e testes; modificar apenas o CSS necessário.

**Interfaces:** schema Zod, labels de enums, Server Action e formulário RHF.

- [ ] Escrever testes RED do schema para todos os limites, normalização lowercase/trim, enums exatos, pace vazio/válido/inválido, UUID e mensagens PT-BR.
- [ ] Escrever testes RED do componente para campos/labels, cidade ativa, launch city preselecionada, privacidade explicada, erros junto ao campo, loading, submit único e preservação após erro.
- [ ] Implementar página server-side: exigir conta ativa/incompleta, carregar apenas cidades ativas e `launch_city_id` do banco; não hardcode São Lourenço.
- [ ] Prefill de nome usa metadata Google apenas na renderização quando `full_name` estiver vazio; não persistir até submit e não preencher username/avatar/roles.
- [ ] Implementar formulário RHF/Zod com labels humanas para os valores técnicos e controles mobile adequados; incluir bio/pace opcionais e privacidade default pública.
- [ ] Implementar Server Action: validar origem pelo mecanismo padrão Next, chamar `getUser()` ou `getClaims()` conforme contrato, consultar conta atual, fazer um único update do próprio profile e redirecionar ao returnTo seguro.
- [ ] Mapear `23505`, reserva/constraint, conta inativa, cidade inativa, sessão expirada e falha temporária sem expor SQL; concorrência real de username deixa um vencedor.
- [ ] Adicionar teste pgTAP/integração se necessário para confirmar que usuário A não conclui onboarding de B e suspenso não atualiza; não relaxar RLS.
- [ ] Verificar 360, 390, 430, 768, 1024 e 1440 px, teclado/foco, overflow, mensagens e submit duplicado usando Playwright/screenshots temporários.
- [ ] Executar testes app/DB afetados, lint, typecheck e build.
- [ ] Commit: `feat: complete runner onboarding`.

**Expected:** onboarding rápido, acessível, atômico e governado pelo banco.

### Task 8: Implementar logout, reload e falhas de sessão

**Files:** criar `src/app/logout/page.tsx`, `actions.ts`; modificar Home minimamente; criar testes.

**Interfaces:** `logoutAction()` POST e navegação Auth mínima.

- [ ] Escrever testes RED: GET não encerra sessão, POST encerra somente sessão local, repetição é segura, reload permanece logout, rota protegida volta ao login e cache não mantém conteúdo privado.
- [ ] Implementar página de confirmação e Server Action com `signOut({ scope:'local' })`; revalidar/redirect sem exibir token.
- [ ] Tratar refresh expirado/revogado como anonymous, limpar cookies inválidos conforme biblioteca e preservar somente returnTo interno.
- [ ] Adicionar à Home somente controles de autenticação/onboarding necessários; manter marca e “Em desenvolvimento”, sem dashboard/social.
- [ ] Testar duas abas no mesmo contexto: após logout e reload, ambas deixam de exibir estado autenticado.
- [ ] Testar callback/onboarding/login/logout contra loops e sessão ausente durante submit.
- [ ] Executar testes, lint, typecheck e build.
- [ ] Commit: `feat: add secure logout and session recovery`.

**Expected:** cookies deixam de representar sessão após logout e falhas expiram com estado previsível.

### Task 9: Criar integração Auth local e E2E determinístico

**Files:** criar `playwright.config.ts`, `tests/e2e/auth-onboarding.spec.ts`, suporte local e runner; modificar scripts/ignores.

**Interfaces:** harness Node local-only, sessão SSR real em cookies e suíte Chromium.

- [ ] Escrever primeiro o teste que prova recusa de qualquer Supabase URL diferente de `http://127.0.0.1:54321` e que service role nunca entra no env do processo Next/browser.
- [ ] Implementar runner que chama a CLI local em processo filho, captura URL/publishable/service role sem imprimir, passa somente valores públicos ao Next e mantém service role apenas no processo de fixture Playwright.
- [ ] Criar fixtures via GoTrue Admin local com emails reservados de teste e senha efêmera; não inserir no seed nem habilitar email/senha na UI/remoto.
- [ ] Obter cookies pelo `createServerClient`/cookie adapter oficial e injetá-los no contexto Playwright; não montar manualmente formato/chunks.
- [ ] Cobrir E2E: visitante → login, incomplete → onboarding, cidade do banco, sucesso → returnTo, reload, complete → não volta ao onboarding, logout, duas abas e sessão revogada/refresh inválido.
- [ ] Cobrir account suspended alterando somente fixture local e provar página bloqueada + update negado; cleanup remove identidades e artefatos.
- [ ] Interceptar navegação Google somente em teste de UI/contrato; não simular que mock prova OAuth real.
- [ ] Instalar apenas Chromium e dependências necessárias; executar `npm run test:auth` duas vezes para provar isolamento/idempotência.
- [ ] Executar pgTAP completo após E2E para provar que fixture não contaminou seed/schema.
- [ ] Commit: `test: cover local auth and onboarding journeys`.

**Expected:** fluxos críticos usam Auth/cookies/banco reais locais sem bypass implantável.

### Task 10: Configurar Google e validar Auth local

**Files:** modificar `supabase/config.toml`; configuração externa Google/Supabase sem arquivo de secret.

**Interfaces:** OAuth Client Web, provider Google local e configuração remota preparada, ainda desabilitada até a migration chegar ao remoto.

- [ ] Confirmar termos/cotas gratuitos atuais e que Google OAuth básico, Supabase Free e Vercel Hobby pessoal continuam com custo obrigatório R$ 0.
- [ ] Inspecionar `supabase start --help`, schema vigente de `config.toml` e Management API; configurar local Site URL/callback exatos e `[auth.external.google]` com `skip_nonce_check=false`.
- [ ] Desabilitar signup por email local/remoto e confirmar que anonymous/SMS continuam desabilitados; provar que o app não contém rota/form/action de email, senha, OTP ou magic link.
- [ ] Criar/selecionar um projeto Google Cloud apropriado e OAuth Client **Web application**; humano intervém somente em login, consentimento, 2FA ou CAPTCHA inevitável.
- [ ] Configurar no Google as origens e callbacks exatos do item 1.9; não pedir contatos, Drive, Calendar, Gmail ou localização.
- [ ] Armazenar Client Secret em variável local ignorada para CLI; nunca copiá-lo para Vercel, Git, PR ou ledger. Preparar o Client ID/Secret no Supabase remoto por Dashboard/Management API, mas manter `external_google_enabled=false` até a migration Gate 2 ser aplicada na Task 12, impedindo a criação remota de usuário sem o trigger.
- [ ] Preparar no Supabase remoto Site URL produção e allowlist com localhost, produção e branch preview exata se usada; confirmar por leitura não sensível. Não habilitar o provider remoto nesta Task.
- [ ] Reiniciar stack local com secret injetado, verificar health e executar smoke Google real local: consentimento → callback → cookie → onboarding; não registrar conta/email no relatório.
- [ ] Testar callback errado/não allowlisted e confirmar rejeição; testar scopes concedidos e ausência de permissões extras.
- [ ] Executar `git diff`/secret scan para garantir que somente config reproduzível não sensível mudou.
- [ ] Commit: `chore: configure reproducible Google Auth settings`.

**Expected:** Google/local Auth comprovados e configuração remota pronta sem permitir login antes do schema remoto.

### Task 11: Estender CI e validar o HEAD da branch

**Files:** modificar `.github/workflows/ci.yml`, `README.md`; configuração Vercel fora do Git.

**Interfaces:** CI local determinística, documentação operacional e branch pronta para promoção remota.

- [ ] Integrar `test:auth` ao job `database` já existente após reset/pgTAP/lint/types, reutilizando a mesma stack; instalar apenas Chromium e sempre parar serviços.
- [ ] Não adicionar GitHub secret Google, Supabase remoto ou service role. O runner obtém credenciais apenas da stack efêmera e não as imprime.
- [ ] Executar localmente a sequência idêntica da CI: `npm ci`, quality, DB reset/test/lint/types, Auth/E2E, diff de types e build.
- [ ] Fazer push da branch e abrir PR draft; aguardar quality/database/Auth do HEAD. O preview pode comprovar build/HTTP, mas login remoto continua deliberadamente desabilitado até a migration da Task 12.
- [ ] Exigir no preview preliminar Ready, HTTP 200, assets e estado seguro de configuração/login indisponível, sem runtime error nem segredo. Não anunciar OAuth remoto como validado.
- [ ] Atualizar README com setup local, comandos, callbacks por camada, env names, teste Auth, diferenças local/preview/prod, segredo no Supabase e fronteira com Gate 3; não registrar valores.
- [ ] Secret scan inclui tracked files, diff, build output e nomes proibidos (`SERVICE_ROLE`, Google secret, DB password, CLI token); falha bloqueia push.
- [ ] Commit: `ci: validate local Auth and onboarding flows`.

**Expected:** HEAD do PR fica verde com Auth local real; nenhuma conta remota pode nascer antes do trigger.

### Task 12: Auditar, aplicar migration remota, validar produção e finalizar

**Files:** somente correções reais; `src/types/database.ts`/README se a evidência exigir. Não fazer cleanup cosmético.

**Interfaces:** migration local/remota equivalente, PR verde e produção autenticável.

- [ ] Executar reset limpo e sequência final: `npm ci`, `npm run db:start`, `npm run db:reset`, `npm run db:test`, `npm run db:lint`, `npm run db:types`, segunda geração sem diff, `npm run test`, `npm run test:auth`, `npm run lint`, `npm run typecheck`, `npm run build`.
- [ ] Confirmar RED/GREEN registrados nas Tasks TDD, fixtures ausentes do seed, nenhuma alteração nas sete migrations Gate 1 e migration nova revisável.
- [ ] Revisar independentemente open redirect, cookies, cache, Proxy matcher, CSRF, `SECURITY DEFINER`, grants, search_path, impersonation, suspensão, metadata e bundle/env; corrigir finding Critical/Important antes de prosseguir.
- [ ] Comparar migrations local/remota, executar `supabase db push --linked --dry-run`, revisar somente a migration Gate 2 e então aplicar com CLI; não alterar Auth schema manualmente.
- [ ] Executar validações remotas não destrutivas de trigger/RPC/grants e types. Só então habilitar Google remoto e confirmar Site URL/allowlist/provider por leitura não sensível; essa ordem impede login sem provisionamento.
- [ ] Configurar Vercel Production com URL/publishable key remotas e `NEXT_PUBLIC_SITE_URL=https://correhub.vercel.app`; configurar a branch Preview Gate 2 com a origem exata da branch. Não adicionar Google Client Secret; redeploy após env.
- [ ] Aguardar preview Ready e executar smoke OAuth Google real no preview controlado: usuário sem role, control active, PKCE, reload, onboarding/retorno, suspensão bloqueada, logout, callback inválido e ausência de tokens em URL/log. Não registrar dados pessoais.
- [ ] Atualizar README somente com fatos estáveis e fazer `docs: record validated Auth preview`; push e aguardar novamente quality/database/Auth/Vercel do HEAD final, corrigindo causa raiz com commit `fix:` específico.
- [ ] Marcar PR pronto e fazer merge normal sem bypass; `git switch main` e `git pull --ff-only origin main`.
- [ ] Aguardar CI da `main` e deployment Vercel Production Ready; executar smoke em `https://correhub.vercel.app`: HTTP 200, Google → Supabase → app, reload, onboarding/retorno e logout.
- [ ] Confirmar que Vercel não contém Google secret/service role, Supabase continua Free/healthy, callbacks não têm wildcard amplo, preview obsoleto foi removido quando aplicável e custo é R$ 0. Registrar a produção final no PR/relatório; não criar novo commit em `main` só para documentar o deployment disparado pelo merge.
- [ ] Confirmar `git status` limpo, `origin/main` igual a HEAD, migration history sem drift, tipos sem diff, secret scan limpo e Gate 3 ausente.
- [ ] Registrar merge commit, CI e deployment final no ledger/relatório. O merge é o encerramento da Task; nenhuma alteração pós-auditoria é criada sem novo PR.

**Expected:** Gate 2 integrado, local/preview/produção verificados e identidade segura sem feature social.

---

## 4. Comandos de verificação final

Usar os scripts efetivamente adicionados; consultar `--help` se a CLI alterar uma flag, sem mudar escopo:

```bash
npm ci
npm run db:start
npm run db:reset
npm run db:test
npm run db:lint
npm run db:types
git diff --exit-code -- src/types/database.ts
npm run test
npm run test:auth
npm run lint
npm run typecheck
npm run build
npm run db:stop
```

Validação remota deliberada:

```bash
npm exec --no -- supabase migration list --linked
npm exec --no -- supabase db push --linked --dry-run
npm exec --no -- supabase db push --linked
node scripts/generate-database-types.mjs --linked --output "$env:TEMP/correhub-database-remote.ts"
```

O último caminho usa o diretório temporário do sistema. Comparar byte a byte com `src/types/database.ts` e apagar o arquivo temporário.

## 5. Evidências de aceite

- [ ] Google provider remoto habilitado com Client Web e scopes `openid email profile`.
- [ ] Signup por email, login anônimo e SMS continuam desabilitados; somente Google aparece como login de produto.
- [ ] Google → Supabase usa callbacks exatos local/remoto; Supabase → CorreHub usa callback exato por ambiente.
- [ ] Allowlist sem wildcard amplo; open redirect, encoding e loops rejeitados.
- [ ] Browser/server clients separados; Proxy Next 16 renova e propaga cookies.
- [ ] Sessão passa reload/request SSR/refresh válido; expiração/revogação falha com segurança.
- [ ] Logout POST local limpa sessão e conteúdo privado não reaparece por cache.
- [ ] Trigger cria profile/control atomicamente e RPC repara histórico idempotentemente.
- [ ] Nenhuma role/username/cidade/autorização deriva de Google metadata.
- [ ] Onboarding incompleto/completo e conta suspensa seguem matriz de rotas.
- [ ] Username válido passa; lowercase/regex/reserva/duplicação/concorrência falham corretamente.
- [ ] Cidade vem do banco, launch city é default e cidade inativa é rejeitada.
- [ ] Nível/distância usam valores persistidos aprovados e labels PT-BR.
- [ ] Nenhum token permanece em URL/log/localStorage; nenhum secret entra no bundle/Git/Vercel.
- [ ] `.env.example` não contém valores; `.env.local` e artefatos Auth estão ignorados.
- [ ] CI app/DB/Auth/E2E verde sem Google real ou projeto remoto destrutivo.
- [ ] Smoke Google real local, preview controlado e produção registrado sem dado pessoal.
- [ ] Migration local/remota, DB e types não têm drift.
- [ ] Vercel Production tem somente URL, publishable key e site URL; Google secret fica no Supabase.
- [ ] App continua dentro das cotas Free/Hobby elegíveis; custo obrigatório R$ 0.
- [ ] Gate 3 não foi implementado.

## 6. Human authorization boundaries

- Login/consentimento/2FA/CAPTCHA no Google Cloud ou na conta Google usada no smoke.
- Login/OAuth do Supabase/Vercel somente se as sessões existentes expirarem.
- Consentimento para criar/selecionar projeto Google Cloud apenas se a conta exigir confirmação não automatizável.
- Cópia do Client Secret apenas se o provedor impedir que o agente o transfira diretamente por browser/API; nunca solicitar que o usuário execute comandos ou manipule SQL.
- Escolha humana somente se houver múltiplos projetos/organizações Google igualmente válidos e sem contexto inequívoco.

O agente conclui antes todas as etapas independentes, inicia o fluxo oficial e pede somente a ação mínima inevitável.

## 7. Commits planejados

1. `chore: add pinned Supabase Auth dependencies`
2. `feat: provision authenticated accounts idempotently`
3. `feat: add Supabase SSR session clients`
4. `security: constrain OAuth redirects and return paths`
5. `feat: enforce authenticated account state`
6. `feat: add Google login and secure callback`
7. `feat: complete runner onboarding`
8. `feat: add secure logout and session recovery`
9. `test: cover local auth and onboarding journeys`
10. `chore: configure reproducible Google Auth settings`
11. `ci: validate local Auth and onboarding flows`
12. `docs: record validated Auth preview`

Commits `fix:` adicionais são permitidos somente para defeitos reais descobertos por teste, revisão, CI ou smoke. O commit documental 12 só existe quando a evidência de preview for real; a validação de produção após merge fica no PR/ledger/relatório para não criar ciclo de deployment.

## 8. Pesquisa oficial e rulings de compatibilidade

- Next.js 16 renomeou Middleware para `proxy.ts`; Proxy não é autorização final e Server Actions continuam exigindo checks próprios: <https://nextjs.org/docs/app/api-reference/file-conventions/proxy>.
- `cookies()` é assíncrono no App Router atual; o server client será uma factory por request: <https://nextjs.org/docs/app/api-reference/functions/cookies>.
- Server Actions já comparam `Origin` e host; não ampliar `allowedOrigins`: <https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions>.
- Supabase SSR recomenda `@supabase/ssr`, cookies, Proxy e `getClaims()`; o pacote segue beta e a API deve ser conferida na execução: <https://supabase.com/docs/guides/auth/server-side/creating-a-client>.
- `getClaims()` valida assinatura/expiração; `getUser()` confirma o registro Auth atual; `getSession()` não autoriza no servidor: <https://supabase.com/docs/guides/auth/server-side/advanced-guide>.
- Google local usa callback `http://127.0.0.1:54321/auth/v1/callback`; remoto usa o callback do project ref e o secret fica no provider Supabase: <https://supabase.com/docs/guides/auth/social-login/auth-google>.
- Supabase suporta wildcards de preview, mas este Gate escolhe URL de branch exata para reduzir superfície: <https://supabase.com/docs/guides/auth/redirect-urls>.
- Vercel permite env Production/Preview e override por branch; alterações valem somente em novo deployment: <https://vercel.com/docs/environment-variables>.

## 9. Self-review obrigatório antes da execução

- [ ] Comparar o diff planejado com as seções 5.2, 6, 8, 9, 20 e Gate 2 da seção 22 da spec.
- [ ] Confirmar que nenhuma migration Gate 1 será editada e que a nova migration tem rollback lógico testável via reset.
- [ ] Revisar callbacks Google→Supabase e Supabase→app, Site URL e cada origem local/preview/prod.
- [ ] Revisar `returnTo`, encoding, loops, callback replay e ausência de origem derivada de header.
- [ ] Revisar cookies, refresh, logout, cache, reload, revogação e múltiplas abas.
- [ ] Revisar trigger, transação, reparo idempotente, suspensão, ausência de auto-role e metadata não autorizativa.
- [ ] Revisar Zod contra constraints existentes, cidades ativas, username concorrente e update atômico.
- [ ] Revisar `SECURITY DEFINER`, owner, `search_path`, grants e impossibilidade de personificação.
- [ ] Revisar CI/harness para garantir que service role local não chega ao Next/browser/log e que Google real não é automatizado.
- [ ] Revisar env/bundle/build output e confirmar que Google Client Secret existe somente no Supabase/local CLI.
- [ ] Revisar acessibilidade, viewports e estados loading/error/session expired.
- [ ] Procurar `TODO`, `TBD`, placeholder executável, endpoint de teste, email login, Storage e feature Gate 3.
- [ ] Confirmar app/DB/types/CI/preview/produção verificáveis e custo obrigatório R$ 0.
