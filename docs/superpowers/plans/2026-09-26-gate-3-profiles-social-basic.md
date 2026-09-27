# CorreHub Gate 3 — Profiles + Basic Social Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** entregar perfis públicos/privados seguros, edição do próprio perfil, descoberta básica de corredores e relações de follow sem transformar follow em autorização ou antecipar Gate 4+.

**Architecture:** `public.profiles` continua sendo a fonte completa e só é lida diretamente pelo próprio usuário ou quando a RLS já permite um perfil público; `public.profile_directory` permanece uma projeção `security_invoker` exclusivamente pública. Uma RPC de leitura estreita produz a representação completa pública ou mínima privada, enquanto follows usam INSERT/DELETE direto sob RLS e funções privilegiadas somente para listas sanitizadas e para a transição transacional de privacidade.

**Tech Stack:** Next.js 16.3.5 App Router, React 19.3.0, TypeScript 5.9.3 strict, Tailwind CSS 4.3.3, Supabase PostgreSQL/Auth/RLS, `@supabase/supabase-js` 2.117.2, `@supabase/ssr` 0.12.7, Zod 4.6.5, React Hook Form 7.88.0, Vitest 5.0.1, Testing Library 16.3.3, pgTAP via Supabase CLI 2.117.0 e Playwright Chromium 1.63.0.

**Spec:** `docs/superpowers/specs/2026-09-19-correhub-mvp-design.md`

## Global Constraints

- Implementar somente perfil, privacidade, edição do próprio perfil, descoberta básica de pessoas e follows unilaterais. Não criar grupos, corridas, feed, posts UI, likes, comentários, notificações, administração, analytics nem busca ampla do Gate 7.
- Não editar as oito migrations existentes. Todo objeto persistente novo entra em migrations Gate 3 criadas por `supabase migration new`.
- `follow` nunca concede acesso adicional. O read model de perfil não consulta `user_follows` para decidir campos visíveis.
- RLS, grants de coluna e funções são a autoridade; componentes nunca recebem um profile completo para esconder campos no React.
- Mutação social exige identidade atual, onboarding completo e `private.account_controls.status='active'`, mesmo com JWT ainda válido.
- Nenhum upload/bucket é criado. `avatar_url` é somente leitura; perfil privado sempre recebe avatar genérico para terceiros.
- Não persistir `followers_count` ou `following_count`. Gate 3 não precisa mostrar números; listas autorizadas são paginadas.
- Nenhum fixture social entra em `supabase/seed.sql` ou no projeto remoto. Fixtures ficam em pgTAP/Playwright local e são removidas.
- Páginas dependentes de sessão/follow usam renderização dinâmica e não entram em cache público compartilhado.
- Custo obrigatório R$ 0; não adicionar serviço, plano ou dependência paga.
- Branch de execução: `feature/gate-3-profiles-social-basic`.

## Review Focus

1. **Vazamento de perfil privado:** RPC, view, metadata, HTML e listas devem retornar somente username, nome e avatar genérico para terceiros; pgTAP e E2E comparam o conjunto de campos antes e depois do follow.
2. **Follow confundido com autorização:** nenhuma policy/função de perfil contém predicate baseado em `user_follows`; seguir B privado não muda o resultado da leitura.
3. **Edição cross-user/BOLA:** Server Action não aceita ator, RLS fixa `id=auth.uid()`, grants excluem campos de sistema e testes tentam update direto de B por A.
4. **Grafo privado exposto:** SELECT direto de `user_follows` fica limitado às relações do próprio usuário; funções de lista omitem grafo de target privado para terceiros e omitem counterpart privado nas listas públicas.
5. **Transição public→private incompleta:** trigger transacional privatiza posts pessoais públicos na mesma transação; private→public não restaura nenhuma visibilidade.

---

## 1. Decisões arquiteturais

### 1.1 Contratos de leitura

| Contrato | Execução | Uso | Garantia |
| --- | --- | --- | --- |
| `public.profiles` | RLS + grants atuais, endurecidos | `/me`, formulário de edição e onboarding | próprio perfil completo; público completo somente quando a policy permitir |
| `public.profile_directory` | view `security_invoker` | cards de descoberta de perfis públicos | nunca contém private, suspended ou incomplete; acrescenta somente dados públicos da cidade |
| `public.get_profile_by_username(target_username text)` | `STABLE SECURITY DEFINER`, `search_path=''` | `/u/[username]` e metadata segura | público/self completo; private de terceiro somente identidade mínima; suspended/incomplete inexistente |
| `public.discover_profiles(...)` | `STABLE SECURITY INVOKER` sobre `profile_directory` | `/people` | busca/paginação pública sem contornar RLS |
| `public.list_profile_connections(...)` | `STABLE SECURITY DEFINER`, autenticado | followers/following | target privado só para owner; private counterpart mínimo apenas ao owner; terceiros veem somente perfis públicos |

`get_profile_by_username` retorna `id`, `username`, `full_name`, `avatar_url`, `bio`, dados de cidade, nível, distância, pace, `visibility ('self'|'public'|'private')` e `created_at`. Para `private`, todos os campos além de `id`, `username`, `full_name`, `visibility` e `created_at` são `NULL`; o componente gera o avatar neutro. A função retorna zero linhas para username ausente, onboarding incompleto ou conta não ativa.

`profile_directory` continua sendo a projeção de descoberta. A migration usa `CREATE OR REPLACE VIEW ... WITH (security_invoker=true)` e preserva a ordem das colunas existentes, acrescentando `city_name`, `city_slug`, `country_code` e `state_code`. Não inclui `is_private`, controles, roles ou email.

### 1.2 URL e identidade

- Perfil canônico: `/u/[username]`, conforme a spec. O segmento `u` evita colisão com rotas institucionais e usernames reservados.
- Próprio perfil: `/me`; edição: `/settings/profile`; descoberta: `/people`.
- Listas: `/u/[username]/followers` e `/u/[username]/following`.
- Troca de username faz a URL antiga responder `not_found`; não há alias no MVP. FKs/follows continuam por UUID e links são sempre gerados com o username atual.
- Suspended, deleted e incomplete não possuem página pública nem aparecem na busca. O próprio suspended/deleted continua no fluxo `/account-unavailable` do Gate 2.

### 1.3 Mutação de perfil e privacidade

Edição usa um único `UPDATE public.profiles ... WHERE id=auth.uid()` via Server Action. O payload contém somente `username`, `full_name`, `bio`, `city_id`, `running_level`, `preferred_distance`, `pace_seconds_per_km` e `is_private`; não aceita `id`, `avatar_url`, `onboarding_completed`, timestamps, roles ou status.

A migration revoga o grant de UPDATE de `avatar_url`, mantém os campos usados pelo onboarding e adiciona:

- trigger privado que rejeita `onboarding_completed: true→false`;
- trigger privado `AFTER UPDATE OF is_private` que, somente em `false→true`, executa na mesma transação:
  `UPDATE public.posts SET visibility='private' WHERE author_user_id=NEW.id AND group_id IS NULL AND visibility='public'`;
- nenhuma ação em `true→false`, portanto posts antigos continuam privados;
- funções do trigger em `private`, owner `postgres`, `SET search_path=''`, nomes qualificados e `EXECUTE` revogado de `PUBLIC`, `anon` e `authenticated`.

O trigger é necessário para cobrir qualquer update autorizado, inclusive Data API e onboarding, sem conceder UPDATE de posts ao cliente. Falha ao privatizar posts aborta também a mudança do profile.

### 1.4 Follow/unfollow

Não criar RPC privilegiada para mutar follows. Server Actions identificam o ator e fazem INSERT/DELETE direto; o banco decide:

- helper `private.current_account_is_social_ready()` = conta atual ativa + profile com onboarding completo;
- helper `private.profile_is_socially_eligible(uuid)` = target ativo + onboarding completo;
- SELECT de `user_follows`: somente relações em que o caller é `follower_id` ou `followed_id`, e somente enquanto social-ready;
- INSERT: `follower_id=auth.uid()`, social-ready, target elegível e diferente; PK/check permanecem defesa concorrente;
- DELETE: somente `follower_id=auth.uid()` e caller social-ready;
- nenhum UPDATE; nenhum grant/policy para `anon`.

Follow duplicado (`23505`) é tratado como sucesso `following=true`; unfollow sem linha é sucesso `following=false`. A Action aceita target UUID/username, nunca `follower_id`. Suspended não insere nem remove. Follow existente é preservado historicamente quando uma conta é suspensa, mas deixa de ser exibido por contratos públicos.

### 1.5 Followers/following

`list_profile_connections(target_username, direction, after_username, after_id, page_size)` aceita `direction IN ('followers','following')`, limita página a 20 e exige caller autenticado, ativo e completo.

- Target público: qualquer caller social-ready vê somente counterparties públicos, ativos e completos.
- Target privado: somente o próprio target consulta a lista.
- Owner da lista: vê counterparties públicas completas e privadas como identidade mínima; suspended/incomplete são omitidos.
- Follower de target privado continua sem lista, sem contagem e sem campos adicionais.
- Visitante não consulta listas. Gate 3 não mostra contagens, evitando vazamento e denormalização.

### 1.6 Descoberta básica e multi-cidade

`/people` é público e lista apenas profiles públicos, ativos e completos. Busca opcional por username/nome é substring case-insensitive, com texto trimado e no máximo 80 caracteres. Ordenação/cursor estável: `(username ASC, id ASC)`, página de 20 e leitura de 21 para detectar próxima página.

Filtro `city=<uuid>` vem de `<select>` carregado com cidades ativas. Sem parâmetro válido, usar: cidade do profile ativo completo → `app_settings.launch_city_id`. Visitante usa launch city. Nenhum componente contém nome/UUID de São Lourenço.

O cursor é base64url de `{ username, id }`, validado por Zod; cursor inválido reinicia com erro de query seguro. Não criar `pg_trgm` ou índice textual nesta fase: `profiles_city_id_idx`, unique de username, PK `(follower_id,followed_id)` e `user_follows_followed_id_idx` já cobrem filtro/ordem/FKs principais. Antes de qualquer índice extra, executar `EXPLAIN (ANALYZE, BUFFERS)` com fixture local representativa e registrar evidência.

### 1.7 Cache, metadata e erro

- `/me`, `/settings/profile`, `/u/*`, `/people` e listas exportam `dynamic='force-dynamic'`; não usar `use cache` em resposta dependente de sessão.
- Server Components fazem leitura inicial; Client Components existem somente para formulário e follow/unfollow.
- Metadata usa o mesmo read model seguro. Private recebe título com identidade mínima, descrição genérica e `robots: noindex`; nunca bio/cidade/pace/avatar real. Suspended/incomplete/unknown retornam `notFound()`.
- Erros de Action: `unauthenticated`, `forbidden`, `not_found`, `validation_error`, `conflict`, `temporary_error`. SQL, policy, UUID interno e detalhes de conta não chegam à UI.
- Depois de mutação, `revalidatePath` cobre `/me`, `/settings/profile`, `/people`, URL antiga/nova e listas afetadas; a UI só muda após resposta confirmada.

---

## 2. Matriz de visibilidade

Legenda: **completo** = valor real permitido; **mínimo** = username + full name e avatar genérico; **oculto** = nem campo nem contagem/lista; **login** = ação preserva `returnTo` e leva ao Google login.

| Viewer / target | username | full_name | avatar | bio | city | level | distance | pace | followers | following | follow action |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| próprio ativo, target próprio public/private | completo | completo | real/padrão | completo | completo | completo | completo | completo | lista própria; private counterpart mínimo | lista própria; private counterpart mínimo | oculto |
| visitante, target public ativo/completo | completo | completo | real/padrão | completo | completo | completo | completo | completo | oculto | oculto | login |
| visitante, target private ativo/completo | mínimo | mínimo | genérico | oculto | oculto | oculto | oculto | oculto | oculto | oculto | login, sem promessa de acesso |
| autenticado ativo/completo terceiro, target public | completo | completo | real/padrão | completo | completo | completo | completo | completo | perfis públicos | perfis públicos | follow/unfollow |
| follower ativo, target public | igual ao terceiro | igual ao terceiro | igual ao terceiro | igual ao terceiro | igual ao terceiro | igual ao terceiro | igual ao terceiro | igual ao terceiro | perfis públicos | perfis públicos | following/unfollow |
| autenticado ativo/completo terceiro, target private | mínimo | mínimo | genérico | oculto | oculto | oculto | oculto | oculto | oculto | oculto | follow/unfollow |
| follower ativo, target private | mínimo | mínimo | genérico | oculto | oculto | oculto | oculto | oculto | oculto | oculto | following/unfollow; sem acesso extra |
| viewer suspended, target public | completo público | completo público | público | público | público | público | público | público | oculto | oculto | oculto |
| viewer suspended, target private | mínimo | mínimo | genérico | oculto | oculto | oculto | oculto | oculto | oculto | oculto | oculto |
| qualquer viewer, target suspended/deleted/incomplete | oculto/not_found | oculto | oculto | oculto | oculto | oculto | oculto | oculto | oculto | oculto | oculto |

Follow não altera nenhuma célula de dados do target private; muda somente o estado do botão para o próprio follower.

---

## 3. Matriz de RLS e grants

| Objeto/operação | Role/grant | Policy/contrato |
| --- | --- | --- |
| `profiles SELECT` | grants existentes por coluna para anon; tabela para authenticated | anon = active+complete+public; authenticated = próprio ou active+complete+public |
| `profiles UPDATE` | authenticated apenas nas colunas de profile; revogar `avatar_url`; manter `onboarding_completed` somente para Gate 2 | `id=auth.uid()` + conta ativa em `USING/WITH CHECK`; trigger impede regressão do onboarding e garante privacidade de posts |
| `profile_directory SELECT` | anon/authenticated | `security_invoker`; herda RLS e só materializa public active complete |
| `get_profile_by_username EXECUTE` | anon/authenticated, revogado de PUBLIC antes do grant | função definer retorna shape sanitizado; nunca retorna account controls/roles/email |
| `discover_profiles EXECUTE` | anon/authenticated | invoker sobre view pública, parâmetros limitados e cursor validado |
| `user_follows SELECT` | authenticated | caller social-ready e ator/destinatário da própria relação |
| `user_follows INSERT(follower_id, followed_id)` | authenticated | ator = `auth.uid()`, target elegível, caller social-ready, self negado |
| `user_follows DELETE` | authenticated | somente `follower_id=auth.uid()` e caller social-ready |
| `user_follows UPDATE` | nenhum | deny-by-default |
| `list_profile_connections EXECUTE` | authenticated | definer sanitiza target/counterpart; PUBLIC/anon revogados |
| `posts UPDATE` pela transição | nenhum grant cliente novo | trigger privado atualiza somente posts pessoais do profile cuja privacidade mudou |

---

## 4. Contratos TypeScript produzidos

```ts
type ProfileVisibility = "self" | "public" | "private";

type ProfilePresentation = {
  id: string;
  username: string;
  fullName: string;
  avatarUrl: string | null;
  bio: string | null;
  city: { id: string; name: string; slug: string; countryCode: string; stateCode: string } | null;
  runningLevel: "beginner" | "intermediate" | "advanced" | null;
  preferredDistance: "up_to_5k" | "5k_to_10k" | "10k_to_21k" | "over_21k" | "flexible" | null;
  paceSecondsPerKm: number | null;
  visibility: ProfileVisibility;
};

type ProfileCursor = { username: string; id: string };
type ConnectionDirection = "followers" | "following";

type SocialActionResult =
  | { ok: true; following: boolean }
  | { ok: false; code: "unauthenticated" | "forbidden" | "not_found" | "temporary_error"; message: string };

async function getProfileByUsername(username: string): Promise<ProfilePresentation | null>;
async function getOwnProfile(): Promise<ProfilePresentation | null>;
async function discoverProfiles(input: DiscoveryInput): Promise<CursorPage<ProfilePresentation>>;
async function listProfileConnections(input: ConnectionInput): Promise<CursorPage<ProfilePresentation>>;
async function followProfile(targetUserId: string): Promise<SocialActionResult>;
async function unfollowProfile(targetUserId: string): Promise<SocialActionResult>;
```

Server Actions recebem `unknown`/`FormData`, validam com Zod e jamais aceitam ator. Types de RPC/tabela vêm exclusivamente de `src/types/database.ts` regenerado.

---

## 5. Mapa de arquivos

| Caminho | Operação | Responsabilidade |
| --- | --- | --- |
| `supabase/migrations/*_gate3_profile_visibility.sql` | criar | projeções/RPCs de profile, triggers de privacidade e endurecimento de update |
| `supabase/migrations/*_gate3_user_follows.sql` | criar | helpers social-ready, grants/policies de follows e lista sanitizada |
| `supabase/tests/database/110_profile_visibility_test.sql` | criar | profile público/privado, metadata estrutural, update alheio e transição de posts |
| `supabase/tests/database/120_user_follows_test.sql` | criar | follow/unfollow, suspensão, grafo e follower≠authorization |
| `src/types/database.ts` | regenerar | tipos das views/RPCs/migrations Gate 3 |
| `src/lib/profiles/types.ts` | criar | tipos de apresentação e paginação do domínio |
| `src/lib/profiles/cursor.ts` | criar | encode/decode base64url validado |
| `src/lib/profiles/queries.ts` | criar | DAL server-only de own/public/discovery/connections |
| `src/lib/social/actions.ts` | criar | Server Actions follow/unfollow |
| `src/lib/validations/profile.ts` | criar | campos compartilhados, edição, query e cursor |
| `src/lib/validations/onboarding.ts` | modificar | consumir campos/labels compartilhados sem mudar contrato Gate 2 |
| `src/components/profile/profile-card.tsx` | criar | card público/minimal acessível |
| `src/components/profile/profile-detail.tsx` | criar | apresentação completa ou privada explícita |
| `src/components/profile/profile-form.tsx` | criar | edição mobile first sem avatar upload |
| `src/components/social/follow-button.tsx` | criar | estados follow/following/loading/error |
| `src/components/social/profile-list.tsx` | criar | lista paginada e vazio seguro |
| `src/app/me/page.tsx` | criar | próprio perfil completo e links de edição/relações |
| `src/app/settings/profile/page.tsx` | criar | guarda e formulário de edição |
| `src/app/settings/profile/actions.ts` | criar | update próprio e revalidação |
| `src/app/u/[username]/page.tsx` | criar | página canônica pública/minimal e metadata segura |
| `src/app/u/[username]/followers/page.tsx` | criar | lista autorizada de followers |
| `src/app/u/[username]/following/page.tsx` | criar | lista autorizada de following |
| `src/app/people/page.tsx` | criar | descoberta pública por cidade/query/cursor |
| `src/app/page.tsx`, `src/app/globals.css` | modificar minimamente | navegação Perfil/Descobrir e estilos com tokens existentes |
| `tests/e2e/profiles-social.spec.ts` | criar | jornadas Gate 3 contra Supabase local real |
| `tests/e2e/support/local-auth.ts` | modificar | fixture local para profiles/status sem expor service role ao browser |
| `.github/workflows/ci.yml` | modificar somente se necessário | manter `test:auth` executando todos os specs na stack única |
| `README.md` | modificar | rotas, comandos e limites de privacidade/follow, somente fatos validados |

Cada módulo terá teste colocalizado `.test.ts`/`.test.tsx`. Não criar endpoint de teste, bucket, tabela de contagem ou documento paralelo.

---

## Tasks

### Task 1: Abrir a branch e preservar o baseline aprovado

**Files:** adicionar este plano à branch; criar ledger `.superpowers/sdd/2026-09-26-gate-3-profiles-social-basic/progress.md` ignorado.

**Interfaces:** baseline Gate 2 e hashes imutáveis das oito migrations consumidos por todas as Tasks.

- [ ] Confirmar `main` limpa, `origin/main` igual a HEAD, CI Gate 2 verde e projeto/ref remotos corretos; registrar somente metadados não sensíveis.
- [ ] Criar worktree/branch `feature/gate-3-profiles-social-basic` conforme `superpowers:using-git-worktrees`; nunca implementar em `main`.
- [ ] Registrar SHA-256 das oito migrations, spec e generated types; falhar se existir migration Gate 3 parcial desconhecida.
- [ ] Executar baseline `npm ci`, `npm run lint`, `npm run typecheck`, `npm run test`, `npm run build`.
- [ ] Iniciar uma vez a stack local e executar `db:reset`, pgTAP, DB lint, types sem diff e Auth E2E; registrar contagens reais.
- [ ] Confirmar zero dados fake no seed e nenhuma feature Gate 4/7/8 no app.
- [ ] Commit: `docs: establish Gate 3 execution plan`.

**Expected:** branch isolada começa no Gate 2 verde, com histórico anterior verificável e plano versionado.

### Task 2: Fechar leitura de profiles e transição de privacidade no banco

**Files:** criar migration `gate3_profile_visibility`; criar `110_profile_visibility_test.sql`.

**Interfaces:** produz `get_profile_by_username`, `discover_profiles`, `profile_directory` com cidade e triggers de privacidade.

- [ ] Escrever pgTAP RED para anon/A/follower lendo public B completo, private C mínimo pela RPC e zero private em `profile_directory`; suspenso/incomplete/unknown retornam zero.
- [ ] Escrever RED que compara resultado de private C antes/depois de A seguir C e exige os mesmos valores/NULLs, incluindo avatar real ausente.
- [ ] Escrever RED de grants: view invoker, funções inexistentes/sem execução indevida, sem acesso a controls/roles/email e sem UPDATE de avatar.
- [ ] Escrever RED da transição: public→private atualiza somente posts pessoais `public`; não toca posts de grupo/private; rollback atômico; private→public não republica.
- [ ] Escrever RED de regressão `onboarding_completed true→false` e de A tentando atualizar B.
- [ ] Criar migrations via `npm exec --no -- supabase migration new gate3_profile_visibility`; não editar arquivos anteriores.
- [ ] Implementar funções/triggers/grants definidos nas seções 1.1/1.3 com owner, `search_path`, revoke e nomes qualificados explícitos.
- [ ] Manter `profile_directory security_invoker`; acrescentar cidade sem alterar o significado das colunas existentes.
- [ ] Executar reset e apenas `110` até GREEN; depois toda pgTAP e DB lint.
- [ ] Revisar `EXPLAIN` da busca por cidade/username; não adicionar índice sem evidência.
- [ ] Commit: `security: enforce profile privacy projections`.

**Expected:** o banco produz representações seguras e toda transição para privado fecha posts pessoais na mesma transação.

### Task 3: Autorizar follows e listas sem vazar o grafo

**Files:** criar migration `gate3_user_follows`; criar `120_user_follows_test.sql`.

**Interfaces:** produz RLS/grants de `user_follows`, helpers social-ready e `list_profile_connections`.

- [ ] Escrever pgTAP RED com anon, A, B public, C private, D suspended e E incomplete.
- [ ] Provar RED que criar/provisionar um novo usuário/profile produz zero linhas em `user_follows`; não existe trigger ou auto-follow.
- [ ] Provar RED: A segue B/C; self-follow falha; duplicado não duplica; target suspended/incomplete falha; A não insere como B.
- [ ] Provar RED: A remove somente follow criado por A; C não remove A→B; unfollow inexistente deixa zero linhas.
- [ ] Provar RED: suspended não SELECT/INSERT/DELETE mesmo com JWT; B/C suspended desaparecem das listas sem apagar histórico.
- [ ] Provar RED: terceiro vê listas somente de target público e somente counterpart público; grafo de target private retorna zero.
- [ ] Provar RED: owner de lista private vê relação, mas counterpart private retorna identidade mínima; follower não recebe esse privilégio.
- [ ] Criar migration pelo CLI e implementar os predicates/grants exatos da seção 1.4; nenhum UPDATE e nenhum grant anon.
- [ ] Implementar `list_profile_connections` com page size 1–20, direction validada e sanitização por linha; revogar PUBLIC/anon.
- [ ] Inspecionar índices existentes com `EXPLAIN`: PK cobre following/existência e `followed_id_idx` cobre followers; não duplicar.
- [ ] Executar `120` até GREEN, toda pgTAP, DB lint e reset limpo.
- [ ] Commit: `feat: authorize user follow relationships`.

**Expected:** follow é unilateral, concorrente e reversível, sem virar permissão de leitura nem expor grafo privado.

### Task 4: Regenerar types e criar a DAL tipada

**Files:** regenerar `src/types/database.ts`; criar `src/lib/profiles/{types,cursor,queries}.ts`, `src/lib/validations/profile.ts` e testes; modificar onboarding validation.

**Interfaces:** produz as funções TypeScript da seção 4 e preserva `onboardingSchema`.

- [ ] Regenerar types após reset; executar duas vezes e exigir zero diff na segunda geração.
- [ ] Escrever RED do cursor: round trip, Unicode rejeitado quando inválido, UUID inválido, JSON adulterado, tamanho excessivo e fallback seguro.
- [ ] Escrever RED das queries: mapping public/private, cidade nullable, `limit=21`, cursor composto, query trim/max 80 e erros `not_found/temporary_error`.
- [ ] Extrair campos/labels/pace compartilhados para `profile.ts`; provar que todos os testes Gate 2 continuam idênticos.
- [ ] Implementar DAL `server-only`; nenhuma query usa service role ou lê tabela `private` diretamente.
- [ ] Confirmar que profile privado nunca é representado por um objeto previamente completo com campos escondidos no componente.
- [ ] Executar testes dos módulos, lint, typecheck e generated-types diff.
- [ ] Commit: `feat: add typed profile and social data access`.

**Expected:** UI consome somente objetos já sanitizados e paginação tipada, sem reconstruir autorização.

### Task 5: Implementar páginas própria e pública de profile

**Files:** criar `profile-card`, `profile-detail`, `/me`, `/u/[username]` e testes; modificar CSS somente com tokens.

**Interfaces:** consome `getOwnProfile/getProfileByUsername`; produz páginas e metadata seguras.

- [ ] Escrever testes RED para own profile completo, public profile completo, private mínimo, generic avatar, suspended/incomplete/unknown `notFound`.
- [ ] Escrever RED de metadata/HTML: private não contém bio/city/level/distance/pace/avatar real e recebe `noindex`; public usa somente dados autorizados.
- [ ] Implementar `/me` exigindo active+complete, com links para edição e listas; incomplete volta ao onboarding, unavailable usa fluxos Gate 2.
- [ ] Implementar `/u/[username]` canônica, normalizando lowercase sem aceitar segmento inválido; não exibir UUID/email/controls/roles.
- [ ] Exibir aviso claro “Perfil privado” sem sugerir que follow desbloqueia dados.
- [ ] Para visitante, follow CTA leva a `/login?returnTo=<perfil>` pelo sanitizer existente; próprio perfil nunca mostra follow.
- [ ] Marcar rotas como dinâmicas e testar ausência de cache público compartilhado.
- [ ] Validar acessibilidade, foco, contraste, touch target 44×44 e viewports 360/390/430/768/1024/1440.
- [ ] Executar testes afetados, lint, typecheck e build.
- [ ] Commit: `feat: add secure runner profile pages`.

**Expected:** profile público é útil e profile privado nunca envia os campos ocultos ao HTML/metadata.

### Task 6: Permitir edição segura do próprio profile

**Files:** criar `/settings/profile/page.tsx`, `actions.ts`, `profile-form.tsx` e testes.

**Interfaces:** produz `updateProfile(input)`; consome profile schema, account state e update direto sob RLS/triggers.

- [ ] Escrever RED do schema para username, nome, bio, city UUID, enums, pace e boolean privacy, incluindo vazio→NULL e labels PT-BR.
- [ ] Escrever RED do formulário para valores atuais, erros por campo, accessible names, loading, submit único, preservação após erro e ausência de avatar upload.
- [ ] Escrever RED da Action: anonymous/incomplete/suspended negados; A não escolhe ID de B; campos extras são descartados/rejeitados.
- [ ] Testar username reservado/duplicado/concorrente, cidade inativa, constraint e falha temporária com mensagens seguras.
- [ ] Implementar um único UPDATE do próprio profile; consultar username antigo server-side e revalidar URLs antiga/nova, `/me` e `/people` após sucesso.
- [ ] Provar que troca de username preserva follow por UUID e a URL antiga passa a `not_found`.
- [ ] Provar via integração que toggle private executa o trigger de posts e toggle public não republica.
- [ ] Executar unit/component/pgTAP afetados, lint, typecheck e build.
- [ ] Commit: `feat: allow secure profile editing`.

**Expected:** usuário ativo edita somente seus campos permitidos e privacidade muda de forma transacional.

### Task 7: Implementar follow/unfollow na aplicação

**Files:** criar `src/lib/social/actions.ts`, `follow-button.tsx` e testes; integrar em profile detail.

**Interfaces:** produz `followProfile/unfollowProfile` com `SocialActionResult`.

- [ ] Escrever RED das Actions para anonymous, incomplete, suspended, self, target ausente/ineligível, duplicado e delete idempotente.
- [ ] Provar que input não aceita `follower_id`, status, role ou campos de profile; target ID é validado e o ator vem da sessão.
- [ ] Implementar INSERT/DELETE direto com cliente autenticado e traduzir `23505`, RLS/zero rows e indisponibilidade sem SQL bruto.
- [ ] Escrever testes do botão: Follow, Following, loading, erro, dupla submissão, próprio profile ausente e login CTA para visitante.
- [ ] Não usar optimistic success; reconciliar somente resposta do servidor e `router.refresh/revalidatePath`.
- [ ] Reexecutar teste central: seguir private altera apenas estado do botão, sem alterar nenhum campo de profile.
- [ ] Executar testes afetados, pgTAP social, lint, typecheck e build.
- [ ] Commit: `feat: add follow and unfollow actions`.

**Expected:** mutação é idempotente na UX, autorizada no banco e incapaz de ampliar visibilidade.

### Task 8: Implementar descoberta básica de corredores

**Files:** criar `/people/page.tsx`, `profile-list.tsx` e testes; modificar navegação mínima.

**Interfaces:** consome `discoverProfiles`, cidades ativas, profile/launch city e cursor; produz listagem pública mínima do Gate 3.

- [ ] Escrever RED do parser para `q`, `city` UUID e cursor; query inválida nunca vira filtro PostgREST bruto.
- [ ] Escrever RED de resultado: public active complete aparece; private/suspended/incomplete não; ordem username/id; page size 20 e next cursor.
- [ ] Testar busca por username e nome case-insensitive, vazio, sem resultado e erro temporário.
- [ ] Implementar fallback de cidade profile→launch city e select de cidades ativas; visitante usa launch city.
- [ ] Não hardcode cidade, ranking, recomendação, grupos, corridas ou geolocalização.
- [ ] Cards exibem somente dados do directory; follow pode aparecer apenas após navegação ao profile, reduzindo mutações na lista.
- [ ] Adicionar navegação “Descobrir”→`/people` e “Perfil”→`/me` somente onde o estado Auth permitir, sem criar shell Gate 7.
- [ ] Validar empty/error/loading sem layout shift e viewports prioritários.
- [ ] Executar testes, lint, typecheck e build.
- [ ] Commit: `feat: add basic runner discovery`.

**Expected:** descoberta pública, determinística e multi-cidade encontra somente corredores elegíveis.

### Task 9: Implementar followers/following autorizados

**Files:** criar rotas `/u/[username]/followers`, `/following`, componentes/testes compartilhados.

**Interfaces:** consome `listProfileConnections`; produz listas autenticadas paginadas sem counts.

- [ ] Escrever RED: visitante redireciona a login com returnTo; active complete acessa lista pública; suspended/incomplete não acessa.
- [ ] Testar target public com public/private/suspended counterpart: terceiro vê somente public; owner vê private mínimo; suspended é omitido.
- [ ] Testar target private: owner vê lista sanitizada; terceiro e follower recebem `not_found/forbidden` sem revelar contagem.
- [ ] Implementar as duas páginas sobre o mesmo componente e `direction` fixo pela rota, nunca por input livre do browser.
- [ ] Paginar com cursor composto; cursor adulterado produz estado seguro e não SQL bruto.
- [ ] Não renderizar números ou placeholders que revelem relações ocultas.
- [ ] Executar component tests, pgTAP do grafo, lint, typecheck e build.
- [ ] Commit: `feat: add privacy-aware social lists`.

**Expected:** usuários autenticados veem somente o subconjunto social autorizado e profile privado preserva seu grafo.

### Task 10: Cobrir jornadas reais locais e integrar à CI

**Files:** criar `tests/e2e/profiles-social.spec.ts`; modificar suporte local, CI somente se necessário e README.

**Interfaces:** reutiliza runner Gate 2/Supabase local; produz evidência integrada Gate 3 sem bypass deployável.

- [ ] Estender fixture Node local-only para completar profiles e consultar cleanup; service role permanece somente no processo Playwright e URL remota continua recusada.
- [ ] E2E public: visitante abre B public e vê campos permitidos; private não envia bio/city/pace/graph.
- [ ] E2E follow: A segue B, reload mantém Following, A unfollows e reload mantém Follow.
- [ ] E2E private invariant: snapshot textual/campos de B private antes/depois de follow é idêntico, exceto botão.
- [ ] E2E edit: A altera dados próprios/username/privacy; relação por UUID permanece e B não é alterado.
- [ ] E2E discovery: B public aparece; private/suspended/incomplete não aparecem; filtro cidade vem do banco.
- [ ] E2E cross-user: request direto de A para update/delete alheio é negado pelo banco, não apenas pela UI.
- [ ] Rodar nos viewports 360/390/430/768/1024/1440 pelo menos profile, edit e people; verificar overflow, foco, contraste e targets.
- [ ] Executar `test:auth` duas vezes, toda pgTAP depois e confirmar zero identities/fixtures residuais.
- [ ] Manter CI com uma única stack: reset→pgTAP→lint/types→Chromium→Auth+social E2E→stop; não usar Google real/remoto.
- [ ] Atualizar README com rotas, scripts, privacidade, follow unilateral e fronteira Gate 4/7/8; sem copiar a spec.
- [ ] Commit: `test: cover profiles privacy and follows`.

**Expected:** browser, sessão, RLS e banco reais locais provam as jornadas; CI continua dentro da cota gratuita.

### Task 11: Auditar, validar remoto, PR, deploy e finalizar

**Files:** somente correções reais e documentação factual de preview quando houver; nenhum cleanup cosmético.

**Interfaces:** branch auditada, duas migrations equivalentes local/remoto, PR/CI/deploy verdes e `main` atualizada.

- [ ] Executar auditoria limpa: `npm ci`, db start/reset/test/lint/types duas vezes, `npm run test`, `npm run test:auth`, lint, typecheck, build e db stop.
- [ ] Confirmar hashes das oito migrations anteriores inalterados; revisar as duas Gate 3, grants, policies, owners, `search_path`, `SECURITY DEFINER` e Data API.
- [ ] Fazer secret scan de tracked/diff/build; nenhuma service role, DB password, access token, cookie ou Google secret.
- [ ] Revisar com contexto fresco os cinco Review Focus, cache/metadata, target enumeration, cursor, CSRF Server Actions e nenhuma feature Gate 4/7/8.
- [ ] Push branch e criar PR draft; aguardar quality/database/Auth+social E2E/Vercel do HEAD. Corrigir falha real com commit `fix:` específico.
- [ ] Para preview, configurar somente as três env públicas na branch exata; validar páginas públicas/empty states. OAuth real no preview só se callback exato temporário for necessário, nunca wildcard; remover env/callback temporários ao final.
- [ ] Depois de local+CI verdes, comparar migration history, executar `db push --linked --dry-run`, aplicar somente migrations Gate 3 e confirmar 10 versões equivalentes, schema/RLS/types sem drift e projeto Free healthy.
- [ ] Não inserir usuários/follows fake remotamente. Usar conta real autorizada somente no smoke de produção, sem registrar dados pessoais.
- [ ] Atualizar README/PR somente com evidência estável; commit opcional `docs: record validated Gate 3 preview` existe apenas se houver fato novo versionável.
- [ ] Marcar PR ready, exigir CI final, fazer merge normal sem bypass e atualizar `main` por `pull --ff-only`.
- [ ] Confirmar CI `main`, Vercel Production Ready e smoke em `https://correhub.vercel.app`: public/private, edit próprio, follow/unfollow, discovery, reload e logout.
- [ ] Reconfirmar Supabase Free, Vercel Hobby, nenhuma env privilegiada, Git limpo, `origin/main=HEAD`, custo R$ 0 e Gate 4+ ausente.
- [ ] Registrar evidências e merge no ledger; não criar commit pós-merge somente para relatório.

**Expected:** Gate 3 integrado, reproduzível e seguro em local/CI/remoto/produção, sem ampliar escopo.

---

## 6. Comandos de verificação

Descobrir flags vigentes por `npm exec --no -- supabase <grupo> --help` antes de adaptar qualquer comando:

```bash
npm ci
npm run db:start
npm run db:reset
npm run db:test
npm run db:lint
npm run db:types
git diff --exit-code -- src/types/database.ts
npm run db:types
git diff --exit-code -- src/types/database.ts
npm run test
npm run test:auth
npm run lint
npm run typecheck
npm run build
npm run db:stop
```

Validação remota deliberada, somente após local/CI verdes:

```bash
npm exec --no -- supabase migration list --linked
npm exec --no -- supabase db push --linked --dry-run
npm exec --no -- supabase db push --linked
node scripts/generate-database-types.mjs --linked --output "$TEMP/correhub-gate3-remote-types.ts"
```

Comparar types remotos byte a byte e apagar o arquivo temporário. Warnings do DB lint/advisors são analisados; finding de segurança ou integridade bloqueia merge.

---

## 7. Evidências de aceite

- [ ] Próprio usuário vê profile completo público ou privado.
- [ ] Visitante vê somente campos permitidos de profile público.
- [ ] Terceiro/follower vê somente identidade mínima de private, com avatar genérico.
- [ ] Private, suspended e incomplete não aparecem em discovery.
- [ ] Suspended/incomplete/unknown não têm página pública legível.
- [ ] A não atualiza B por UI, Action, Data API ou chamada direta.
- [ ] Username válido/reservado/duplicado/concorrente e troca de URL têm comportamento testado.
- [ ] Mudança de username preserva follows por UUID.
- [ ] Provisionamento/onboarding não cria follow automático.
- [ ] Self-follow é negado; duplicado não cria segunda linha.
- [ ] Follow/unfollow persistem e são idempotentes na UX.
- [ ] Follow de private não altera nenhum campo visível nem libera grafo.
- [ ] Target/caller suspended ou incomplete não recebe mutação social.
- [ ] Terceiro não lê grafo de private; owner vê relações com private counterpart mínimo.
- [ ] Public→private privatiza posts pessoais na mesma transação.
- [ ] Private→public não republica posts anteriormente privados.
- [ ] Nenhuma contagem social persistida ou exposta onde o grafo é oculto.
- [ ] `profile_directory` permanece `security_invoker` e sem private/suspended/incomplete.
- [ ] Nenhum email, metadata Auth, role, account control ou UUID é exibido como conteúdo da UI.
- [ ] Rotas autenticadas/personalizadas não usam cache público compartilhado.
- [ ] pgTAP Gate 1–3, DB reset/lint/types e types remotos estão verdes/sem drift.
- [ ] Vitest/Testing Library, Auth+social Playwright, lint, typecheck e build estão verdes.
- [ ] CI PR/main, Vercel e smoke produção estão verdes.
- [ ] Seed/remoto não contêm runner/follow fake; secret scan está limpo.
- [ ] Migrations Gates 1/2 e spec permanecem inalteradas.
- [ ] Nenhuma feature Gate 4/7/8 foi implementada.
- [ ] Custo obrigatório R$ 0.

---

## 8. Commits planejados

1. `docs: establish Gate 3 execution plan`
2. `security: enforce profile privacy projections`
3. `feat: authorize user follow relationships`
4. `feat: add typed profile and social data access`
5. `feat: add secure runner profile pages`
6. `feat: allow secure profile editing`
7. `feat: add follow and unfollow actions`
8. `feat: add basic runner discovery`
9. `feat: add privacy-aware social lists`
10. `test: cover profiles privacy and follows`
11. `docs: record validated Gate 3 preview` somente se houver evidência versionável real.

Commits `fix:` adicionais existem somente para defeitos reproduzidos por teste, review, CI ou smoke. Não squashar o histórico previsto.

## 9. Human Authorization Boundaries

- Nenhuma autorização humana é esperada para migrations locais, implementação, testes, Git, PR ou CI.
- Se sessões Supabase/GitHub/Vercel expirarem, o agente inicia o login oficial e o usuário conclui apenas OAuth/2FA/CAPTCHA.
- Smoke autenticado em produção pode exigir login/consentimento Google da conta real; o agente opera o restante e não registra PII.
- Nenhum recurso novo, plano pago, cartão, organização ou projeto externo deve ser criado.

## 10. Pesquisa oficial e rulings de compatibilidade

- Supabase exige combinar grants e RLS; views normalmente usam privilégios do owner e `security_invoker=true` é obrigatório para herdar RLS: <https://supabase.com/docs/guides/database/postgres/row-level-security> e <https://supabase.com/docs/guides/database/views>.
- Funções são `SECURITY INVOKER` por padrão. As exceções definer deste plano usam `search_path=''`, nomes qualificados, `auth.uid()`, revoke de `PUBLIC` e grants mínimos: <https://supabase.com/docs/guides/database/functions>.
- A Data API não torna tabela segura apenas por RLS; grants e exposição são revisados separadamente: <https://supabase.com/docs/guides/api/securing-your-api>.
- O changelog atual anuncia que novas tabelas deixarão de ser expostas automaticamente; Gate 3 não cria tabela e mantém grants explícitos, portanto não depende desse default: <https://supabase.com/changelog?types=breaking-change>.
- Next.js 16 Server Actions são endpoints POST e precisam revalidar autorização; leitura de cookies torna a rota dinâmica. Não usar Actions para leitura: <https://nextjs.org/docs/app/getting-started/mutating-data> e <https://nextjs.org/docs/app/api-reference/functions/cookies>.
- `revalidatePath`/refresh é usado somente após mutação confirmada; não introduzir `use cache` para conteúdo personalizado neste Gate: <https://nextjs.org/docs/app/guides/upgrading/version-16>.

## 11. Self-review obrigatório antes da execução

- [ ] Comparar o plano com as seções 6, 7.2, 7.4, 7.5, 9, 13.1, 17–18, 20, 22 e 24 da spec.
- [ ] Confirmar cada célula da matriz de visibilidade em pgTAP/component/E2E correspondente.
- [ ] Confirmar que `profile_directory` não expõe coluna/linha private e a RPC mínima nunca retorna avatar real.
- [ ] Procurar qualquer predicate de profile baseado em `user_follows`; o resultado deve ser zero.
- [ ] Revisar SELECT/INSERT/DELETE de `user_follows`, sem UPDATE e sem grant anon.
- [ ] Revisar definer functions, owner, search_path, grants, argumentos, paginação e enumeração.
- [ ] Revisar update de profile, grants de coluna, onboarding regression, username/cidade e cross-user.
- [ ] Revisar transição posts public→private e ausência de republicação private→public.
- [ ] Revisar listas do owner/terceiro/follower/suspended e ausência de contagens privadas.
- [ ] Revisar cidade profile→launch, query/cursor e índices com EXPLAIN.
- [ ] Revisar cache/metadata/HTML de private e URLs após troca de username.
- [ ] Revisar harness local, cleanup, seed e impossibilidade de service role no app/browser.
- [ ] Confirmar que Auth Google/PKCE/proxy Gate 2 não foi reescrito.
- [ ] Procurar grupos/corridas/feed/posts UI/likes/comments/notificações/admin/analytics ou discovery ampla antecipados.
- [ ] Procurar `TODO`, `TBD`, placeholder, “etc.” normativo e interface sem Task proprietária.
- [ ] Confirmar R$ 0, migrations antigas imutáveis, nenhum segredo e execução possível sem esta conversa.
