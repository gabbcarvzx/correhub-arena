# CorreHub Gate 1 — Database Base Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** estabelecer o banco base reproduzível e seguro do CorreHub, com schema, constraints, seeds e RLS inicial, sem implementar features dos Gates seguintes.

**Architecture:** Migrations PostgreSQL versionadas serão a única fonte do schema, reaplicáveis em uma stack Supabase local e depois em um único projeto Supabase Free. Tabelas que formarão a API do produto ficam em `public`, sempre com RLS e grants explícitos; controles e estruturas operacionais ficam em `private`, fora dos schemas expostos, com funções estreitas para os poucos predicados de autorização necessários. O Gate cria as estruturas completas da seção 7, mas libera apenas leituras públicas de geografia/configuração e acesso mínimo ao próprio perfil; operações de domínio permanecem negadas até os Gates responsáveis.

**Tech Stack:** PostgreSQL 17/Supabase local, Supabase CLI 2.117.0 fixada em npm, migrations SQL, pgTAP por `supabase test db`, RLS, PostgREST/Data API, TypeScript 5.9.3, GitHub Actions e runtime compatível com Docker APIs.

**Spec:** `docs/superpowers/specs/2026-09-19-correhub-mvp-design.md`

## Global Constraints

- Baseline verificada em 23/09/2026: `main` em `bde5aaa`, repositório privado `gabbcarvzx/correhub02`, Next 16.3.5, React 19.3.0, Tailwind 4.3.3, TypeScript 5.9.3, Supabase CLI 2.117.0 no lockfile, `.nvmrc` 24.21.0, CI/deploy do Gate 0 documentados e nenhuma pasta `supabase/` ou arquivo SQL existente.
- O processo PowerShell usado nesta revisão não encontrou `node`/`npm` no `PATH`, embora o runtime esteja fixado no repositório e tenha sido usado no Gate 0. A Task 1 deve primeiro reativar/reutilizar Node 24.21.0 e verificar npm, sem alterar versões nem instalar outro runtime se o existente puder ser localizado.
- Investimento obrigatório **R$ 0**. Usar runtime local gratuito, GitHub Free e exatamente um projeto Supabase Free; não habilitar Pro, add-on, IPv4 dedicado, PITR, domínio ou compute pago.
- Migrations versionadas são a única fonte de schema, funções, policies, grants e dados invariantes. Não fazer alteração manual definitiva no Dashboard.
- Supabase CLI permanece em `2.117.0` durante a execução deste Gate; consultar `--help` antes de adaptar qualquer comando que tenha mudado.
- Next.js 16.3.5, TypeScript strict e o shell do Gate 0 continuam funcionando sem `.env.local` e sem credenciais Supabase.
- UUID identifica entidades; relações puras podem usar chave composta. Instantes usam `timestamptz`, datas civis usam `date`, horários locais usam `time`, fuso usa identificador IANA, distância usa metros inteiros e pace usa segundos/km.
- Estados usam `text` com `CHECK` nomeado. Não usar enums PostgreSQL neste Gate: os estados evoluirão nos Gates de domínio, e checks permitem migrations aditivas/reversíveis sem recriar tipos. Não usar domains porque regras por coluna diferem e ficariam menos visíveis no SQL gerado.
- `gen_random_uuid()` é o único gerador de UUID para novas entidades. Habilitar `pgcrypto` sem fixar versão da extensão, em conformidade com o changelog atual do Supabase.
- RLS é habilitada em toda tabela de `public` e, como defesa adicional, nas tabelas de `private`. Grants e policies são explícitos; a ausência de ambos é a negação padrão.
- `private` não entra em `[api].schemas`, não recebe grants de tabela para `anon`/`authenticated` e não é exposto na Data API. `USAGE` só é concedido quando indispensável para chamar helper expressamente autorizado.
- Nenhum `SECURITY DEFINER` fica em `public`. Funções privilegiadas usam schema `private`, nomes qualificados, `SET search_path = ''`, execução revogada de `PUBLIC`/`anon` e grants mínimos.
- Nenhum papel decorre de e-mail, username, `raw_user_meta_data`, `user_metadata` ou claims controláveis pelo usuário.
- Não criar trigger automático de `auth.users` neste Gate. Gate 2 implementará provisionamento idempotente de `profiles` e `account_controls` junto do Auth; os testes do Gate 1 criam identidades apenas dentro de transações revertidas.
- O seed contém somente a cidade de lançamento, o singleton de configuração e dados invariantes. Não contém usuários, grupos, corridas, posts ou conteúdo fictício.
- O app não recebe URL, publishable key, secret key ou service role neste Gate. Vercel não recebe variáveis Supabase.
- Não executar `supabase db reset --linked`; o remoto será atualizado somente por `supabase db push --linked --include-seed --skip-vault` após `--dry-run` e validação local/CI.
- Não implementar Google OAuth, callback, sessão SSR, UI de onboarding, fluxos de grupos/corridas/participação, feed, upload, notificações, painel admin, analytics UI ou SEO.

## Review Focus

1. **Exclusão destrutiva da identidade:** apagar `auth.users` não pode apagar grupos, corridas, posts institucionais, participações históricas, denúncias ou auditoria; testes de FK devem provar `SET NULL`, `RESTRICT` ou `CASCADE` apenas nas relações documentadas.
2. **Exposição acidental pela Data API:** toda tabela `public` recebe RLS, grants explícitos e testes como `anon`/`authenticated`; toda tabela `private` deve continuar sem privilégio de tabela e ausente dos schemas expostos.
3. **Username concorrente ou reservado:** regex, lowercase, unicidade e lista reservada são impostas pelo banco; testes cobrem duplicação, maiúscula e reserva sem depender de Zod.
4. **Divergência local/remota:** reset limpo, migration history, seed, lint, tipos gerados e consultas de verificação devem produzir o mesmo contrato antes e depois do `db push` remoto.
5. **Escopo futuro antecipado:** tabelas e invariantes existem, mas nenhuma policy/RPC libera aprovação de grupo, gestão de membros, recorrência, participação, social, moderação ou jobs antes do Gate correspondente.

---

## 1. Decisões estruturais

### 1.1 Fronteira de schemas e Data API

O schema exposto permanece `public`, além dos schemas gerenciados que o `supabase init` registrar. `private` nunca é adicionado a `[api].schemas`. O Gate adota desde já o novo padrão do Supabase de opt-in por `GRANT`: migrations revogam defaults amplos de `anon`/`authenticated`, e cada acesso permitido aparece ao lado da RLS correspondente.

| Entidade | Schema | Data API / grants de cliente no Gate 1 | RLS inicial | Motivo |
| --- | --- | --- | --- | --- |
| `cities` | `public` | `SELECT` para `anon`, `authenticated` | leitura pública de todas as cidades | Geografia não é sensível; cidades inativas permanecem legíveis no histórico, enquanto triggers impedem novas associações. |
| `app_settings` | `public` | `SELECT` para `anon`, `authenticated` | leitura do singleton | `launch_city_id` é configuração pública, sem segredo. |
| `profiles` | `public` | `SELECT` por colunas; `UPDATE` próprio por colunas para `authenticated`; sem `INSERT/DELETE` | público ativo/completo e não privado; próprio perfil; update próprio com conta ativa | Base de identidade da aplicação; RLS protege linhas e grants protegem colunas. |
| `profile_directory` | view `public` | `SELECT` para `anon`, `authenticated` | `security_invoker`, herda RLS de `profiles` | Projeção pública estável sem colunas de onboarding/controle. |
| `groups` | `public` | nenhum para `anon`/`authenticated` | habilitada, sem policy | Estrutura do Gate 4, negada até o fluxo existir. |
| `group_members` | `public` | nenhum | habilitada, sem policy | Relação futura sensível. |
| `group_follows` | `public` | nenhum | habilitada, sem policy | Gate 4 libera operações. |
| `run_series` | `public` | nenhum | habilitada, sem policy | Gate 5 implementa recorrência. |
| `runs` | `public` | nenhum | habilitada, sem policy | Gate 5 define acesso público/membros. |
| `run_participations` | `public` | nenhum | habilitada, sem policy | Gate 6 implementa transações/capacidade. |
| `user_follows` | `public` | nenhum | habilitada, sem policy | Gate 3 implementa relações. |
| `posts` | `public` | nenhum | habilitada, sem policy | Gate 8 implementa publicação/privacidade efetiva. |
| `post_likes` | `public` | nenhum | habilitada, sem policy | Gate 8 implementa interação. |
| `comments` | `public` | nenhum | habilitada, sem policy | Gate 8 implementa interação/moderação. |
| `activity_events` | `public` | nenhum | habilitada, sem policy | Feed futuro precisa revalidar alvo; sem leitura agora. |
| `notifications` | `public` | nenhum | habilitada, sem policy | Gate 9 libera somente ao destinatário. |
| `account_controls` | `private` | nenhuma tabela; helpers booleanos estreitos | habilitada, sem policy de cliente | Status e motivo são operacionais e não pertencem à Data API. |
| `platform_roles` | `private` | nenhuma tabela; helper consulta somente papel do usuário atual | habilitada, sem policy de cliente | Impede autoatribuição e enumeração de administradores. |
| `reserved_usernames` | `private` | nenhum | habilitada, sem policy de cliente | Usada por trigger; lista não precisa ser endpoint. |
| `reports` | `private` | nenhum | habilitada, sem policy de cliente | Denúncias entram por RPC no Gate 10 e nunca são leitura livre. |
| `admin_audit_logs` | `private` | nenhum | habilitada, sem policy de cliente | Append confiável e consulta administrativa futura. |
| `analytics_events` | `private` | nenhum | habilitada, sem policy de cliente | Escrita validada e agregação futura, sem leitura pública. |
| `notification_jobs` | `private` | nenhum | habilitada, sem policy de cliente | Estado interno de fan-out. |
| `media_uploads` | `private` | nenhum | habilitada, sem policy de cliente | Controle interno de upload; Storage entra no Gate 8. |
| `rate_limit_buckets` | `private` | nenhum | habilitada, sem policy de cliente | Contador atômico interno. |
| `group_owner_transfers` | `private` | nenhum | habilitada, sem policy de cliente | Fluxo transacional do Gate 4. |
| `domain_event_receipts` | `private` | nenhum | habilitada, sem policy de cliente | Deduplicação interna durável. |

`service_role` conserva os privilégios administrativos padrão esperados pelo Supabase, mas não é usado pelo app neste Gate. O SQL concede DML a `service_role` apenas quando necessário para manter comportamento idêntico entre a stack local e o remoto; nenhum segredo dessa role é lido, impresso ou versionado.

### 1.2 Catálogo de tabelas e colunas

Todos os nomes abaixo são contratos do Gate. Cada `id uuid PK` usa `DEFAULT gen_random_uuid()`, exceto os dois singletons determinísticos explicitados. Colunas `created_at`/`updated_at` usam `timestamptz NOT NULL DEFAULT now()`; tabelas mutáveis recebem trigger `private.set_updated_at()`.

#### Identidade e geografia

- `public.cities`: `id uuid PK DEFAULT gen_random_uuid()`, `name text NOT NULL`, `country_code text NOT NULL`, `state_code text NOT NULL`, `slug text NOT NULL`, `timezone text NOT NULL`, `is_active boolean NOT NULL DEFAULT false`, timestamps; `UNIQUE(country_code,state_code,slug)`.
- `public.app_settings`: `id uuid PK`, `launch_city_id uuid NOT NULL REFERENCES public.cities(id) ON DELETE RESTRICT`, timestamps. Um `CHECK` fixa o único ID permitido `10000000-0000-4000-8000-000000000002`, eliminando múltiplos registros sem serial.
- `public.profiles`: `id uuid PK REFERENCES auth.users(id) ON DELETE CASCADE`, `username text NULL UNIQUE`, `full_name text NULL`, `avatar_url text NULL`, `bio text NULL`, `city_id uuid NULL REFERENCES public.cities(id) ON DELETE RESTRICT`, `running_level text NULL`, `preferred_distance text NULL`, `pace_seconds_per_km integer NULL`, `is_private boolean NOT NULL DEFAULT false`, `onboarding_completed boolean NOT NULL DEFAULT false`, timestamps.
- `private.account_controls`: `user_id uuid PK REFERENCES auth.users(id) ON DELETE CASCADE`, `status text NOT NULL DEFAULT 'active'`, `reason text NULL`, `status_changed_at timestamptz NOT NULL DEFAULT now()`, timestamps.
- `private.platform_roles`: `user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE`, `role text NOT NULL`, `granted_by uuid NULL REFERENCES auth.users(id) ON DELETE SET NULL`, `created_at`; PK `(user_id,role)`.
- `private.reserved_usernames`: `username text PK`, `created_at`. A migration insere `admin`, `administrator`, `correhub`, `login`, `signup`, `register`, `api`, `settings`, `support`, `help`, `auth`, `account`, `onboarding`, `groups`, `runs`, `people`, `notifications`, `privacy` e `terms` com `ON CONFLICT DO NOTHING`.

#### Grupos e corridas

- `public.groups`: `id uuid PK`, `slug text NOT NULL UNIQUE`, `name text NOT NULL`, `description text NOT NULL`, `city_id uuid NOT NULL REFERENCES cities ON DELETE RESTRICT`, `type text NOT NULL`, `join_policy text NOT NULL`, `status text NOT NULL DEFAULT 'pending'`, `created_by uuid NULL REFERENCES auth.users ON DELETE SET NULL`, `owner_user_id uuid NOT NULL REFERENCES auth.users ON DELETE RESTRICT`, `avatar_url text NULL`, `cover_url text NULL`, `approved_by uuid NULL REFERENCES auth.users ON DELETE SET NULL`, `approved_at timestamptz NULL`, `rejection_reason text NULL`, `suspended_at timestamptz NULL`, timestamps.
- `public.group_members`: `group_id uuid NOT NULL REFERENCES groups ON DELETE CASCADE`, `user_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE`, `role text NOT NULL`, `status text NOT NULL`, `joined_at timestamptz NULL`, `updated_at`; PK `(group_id,user_id)`. Índice único parcial permite no máximo um `role='owner' AND status='active'` por grupo.
- `public.group_follows`: `user_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE`, `group_id uuid NOT NULL REFERENCES groups ON DELETE CASCADE`, `created_at`; PK `(user_id,group_id)`.
- `public.run_series`: `id uuid PK`, `group_id uuid NOT NULL REFERENCES groups ON DELETE RESTRICT`, `city_id uuid NOT NULL REFERENCES cities ON DELETE RESTRICT`, `title text NOT NULL`, `description text NOT NULL`, `weekday smallint NOT NULL`, `local_start_time time NOT NULL`, `meeting_offset_minutes smallint NOT NULL DEFAULT 0`, `timezone text NOT NULL`, `starts_on date NOT NULL`, `ends_on date NULL`, `location_text text NOT NULL`, `distance_meters integer NOT NULL`, `level text NOT NULL`, `visibility text NOT NULL`, `max_participants integer NULL`, `status text NOT NULL DEFAULT 'active'`, `created_by uuid NULL REFERENCES auth.users ON DELETE SET NULL`, `generated_through date NULL`, timestamps; `UNIQUE(id,group_id,city_id)` suporta FK composta das ocorrências.
- `public.runs`: `id uuid PK`, `group_id uuid NOT NULL REFERENCES groups ON DELETE RESTRICT`, `city_id uuid NOT NULL REFERENCES cities ON DELETE RESTRICT`, `series_id uuid NULL`, `occurrence_date date NULL`, `title text NOT NULL`, `description text NOT NULL`, `starts_at timestamptz NOT NULL`, `meeting_time timestamptz NULL`, `location_text text NOT NULL`, `distance_meters integer NOT NULL`, `level text NOT NULL`, `visibility text NOT NULL`, `max_participants integer NULL`, `status text NOT NULL DEFAULT 'scheduled'`, `created_by uuid NULL REFERENCES auth.users ON DELETE SET NULL`, `cancelled_at timestamptz NULL`, `cancellation_reason text NULL`, timestamps. FK `(series_id,group_id,city_id)` referencia `run_series(id,group_id,city_id) ON DELETE RESTRICT`; `UNIQUE(series_id,occurrence_date)`.
- `public.run_participations`: `id uuid PK`, `run_id uuid NOT NULL REFERENCES runs ON DELETE RESTRICT`, `user_id uuid NULL REFERENCES auth.users ON DELETE SET NULL`, `status text NOT NULL DEFAULT 'going'`, `joined_at timestamptz NOT NULL DEFAULT now()`, `updated_at`; `UNIQUE(run_id,user_id)` mantém unicidade enquanto a identidade existe e o `id` preserva o registro após anonimização.

#### Social e operação

- `public.user_follows`: `follower_id uuid NOT NULL` e `followed_id uuid NOT NULL` referenciam `auth.users ON DELETE CASCADE`, `created_at`; PK do par e `CHECK(follower_id <> followed_id)`.
- `public.posts`: `id uuid PK`, `author_user_id uuid NULL REFERENCES auth.users ON DELETE SET NULL`, `group_id uuid NULL REFERENCES groups ON DELETE RESTRICT`, `body text NOT NULL`, `image_url text NULL`, `visibility text NOT NULL`, timestamps, `deleted_at timestamptz NULL`. Após anonimização, um post preservado exige `group_id` não nulo; conteúdo pessoal será purgado pela operação futura de exclusão.
- `public.post_likes`: `post_id uuid NOT NULL REFERENCES posts ON DELETE CASCADE`, `user_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE`, `created_at`; PK `(post_id,user_id)`.
- `public.comments`: `id uuid PK`, `post_id uuid NOT NULL REFERENCES posts ON DELETE CASCADE`, `user_id uuid NULL REFERENCES auth.users ON DELETE SET NULL`, `body text NOT NULL`, timestamps, `deleted_at`.
- `public.activity_events`: `id uuid PK`, `actor_user_id uuid NULL REFERENCES auth.users ON DELETE SET NULL`, `group_id uuid NULL REFERENCES groups ON DELETE SET NULL`, `event_type text NOT NULL`, `entity_type text NOT NULL`, `entity_id uuid NOT NULL`, `metadata jsonb NOT NULL DEFAULT '{}'`, `dedupe_key text NOT NULL UNIQUE`, `created_at`.
- `public.notifications`: `id uuid PK`, `recipient_user_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE`, `actor_user_id uuid NULL REFERENCES auth.users ON DELETE SET NULL`, `type text NOT NULL`, `target_type text NOT NULL`, `target_id uuid NULL`, `dedupe_key text NOT NULL`, `read_at timestamptz NULL`, `created_at`; `UNIQUE(recipient_user_id,dedupe_key)`.
- `private.reports`: `id uuid PK`, `reporter_user_id uuid NULL REFERENCES auth.users ON DELETE SET NULL`, `target_type text`, `target_id uuid`, `reason text`, `details text NULL`, `status text NOT NULL DEFAULT 'open'`, `assigned_to uuid NULL REFERENCES auth.users ON DELETE SET NULL`, `resolution text NULL`, timestamps.
- `private.admin_audit_logs`: `id uuid PK`, `actor_user_id uuid NULL REFERENCES auth.users ON DELETE SET NULL`, `action text`, `target_type text`, `target_id uuid NULL`, `metadata jsonb NOT NULL DEFAULT '{}'`, `created_at`. Não possui `updated_at` e não terá `UPDATE/DELETE` grant.
- `private.analytics_events`: `id uuid PK`, `event_name text`, `user_id uuid NULL REFERENCES auth.users ON DELETE SET NULL`, `anonymous_session_id uuid NULL`, `city_id uuid NULL REFERENCES cities ON DELETE SET NULL`, `entity_type text NULL`, `entity_id uuid NULL`, `properties jsonb NOT NULL DEFAULT '{}'`, `event_key text NOT NULL UNIQUE`, `created_at`. `user_id` e `anonymous_session_id` podem ser simultaneamente nulos para eventos internos; ingestão de cliente será validada no Gate 12.
- `private.notification_jobs`: `id uuid PK`, `event_type text`, `source_entity_type text`, `source_entity_id uuid`, `recipient_cursor uuid NULL`, `status text DEFAULT 'pending'`, `attempt_count integer DEFAULT 0`, `available_at timestamptz DEFAULT now()`, `last_error_code text NULL`, timestamps; `UNIQUE(event_type,source_entity_type,source_entity_id)`.
- `private.media_uploads`: `id uuid PK`, `owner_user_id uuid NULL REFERENCES auth.users ON DELETE SET NULL`, `target_type text`, `target_id uuid NULL`, `object_path text UNIQUE`, `content_hash text`, `size_bytes bigint`, `expires_at timestamptz NULL`, `status text DEFAULT 'pending'`, timestamps.
- `private.rate_limit_buckets`: `user_id uuid REFERENCES auth.users ON DELETE CASCADE`, `action text`, `window_started_at timestamptz`, `consumed integer DEFAULT 0`, `expires_at timestamptz`; PK `(user_id,action,window_started_at)`.
- `private.group_owner_transfers`: `id uuid PK`, `group_id uuid REFERENCES groups ON DELETE CASCADE`, `from_user_id uuid REFERENCES auth.users ON DELETE RESTRICT`, `to_user_id uuid REFERENCES auth.users ON DELETE CASCADE`, `status text DEFAULT 'pending'`, `accepted_at timestamptz NULL`, `expires_at timestamptz`, timestamps; um índice único parcial limita uma transferência pendente por grupo.
- `private.domain_event_receipts`: `id uuid PK`, `event_type text`, `business_key text`, `first_processed_at timestamptz DEFAULT now()`, `entity_type text`, `entity_id uuid NULL`; `UNIQUE(event_type,business_key)`.

### 1.3 Constraints concretas

- Texto obrigatório usa `char_length(btrim(value))`, rejeita somente espaços e exige `value = btrim(value)` para armazenar forma normalizada sem espaços externos; campos opcionais, quando presentes, seguem a mesma regra.
- `cities`: `country_code ~ '^[A-Z]{2}$'`, `state_code ~ '^[A-Z]{2}$'`, slug `^[a-z0-9]+(?:-[a-z0-9]+)*$`, nome 2–100, timezone validado por trigger contra `pg_timezone_names`.
- `profiles`: username nulo ou `^[a-z0-9_]{3,30}$`; full name nulo ou 2–80; bio até 300 e não branca; URL até 2048; `running_level IN ('beginner','intermediate','advanced')`; `preferred_distance IN ('up_to_5k','5k_to_10k','10k_to_21k','over_21k','flexible')`; pace 120–1800. Se `onboarding_completed=true`, username, full_name, city, running level e preferred distance são obrigatórios. Trigger rejeita username encontrado em `private.reserved_usernames`; `UNIQUE(username)` resolve concorrência.
- `account_controls.status IN ('active','suspended','deleted')`; reason tem 1–1000 quando presente. `platform_roles.role IN ('platform_admin','moderator')`.
- `group_members.role IN ('member','admin','owner')`; status `IN ('active','pending','blocked')`; `joined_at` é obrigatório apenas em `active`.
- `groups`: slug 3–100 e regex de slug; nome 3–100; descrição 1–2000; type `community/professional`; join policy `open/approval_required`; status `pending/approved/rejected/suspended`. `pending` não tem campos de decisão; `approved` exige `approved_by/approved_at`; `rejected` exige `rejection_reason` de 1–1000 e não carrega aprovação/suspensão; `suspended` preserva aprovação e exige `suspended_at`; combinações incoerentes falham.
- `private.assert_active_city_reference()` rejeita onboarding concluído, novo grupo, nova série ou nova corrida que referencie cidade inativa. Updates que não alteram `city_id` nem completam onboarding preservam histórico já existente de cidade posteriormente inativada.
- Trigger de constraint deferrable `private.assert_group_owner_consistency()` garante: no máximo um owner ativo; `approved/suspended` possui exatamente um owner ativo igual a `groups.owner_user_id`; `pending/rejected` permite exatamente o owner designado como `owner/pending`. Essa é integridade estrutural, não implementação dos fluxos do Gate 4.
- `run_series`: título 3–120; descrição até 5000; weekday 1–7; offset 0–120; location 3–300; distance 100–100000; level inclui `all_levels`; visibility `public/members_only`; capacidade nula ou 1–10000; status `active/paused/ended`; `ends_on >= starts_on`; `generated_through` nulo ou `>= starts_on`; timezone IANA válida.
- `runs`: mesmos limites de conteúdo/distância/nível/visibilidade/capacidade; status `scheduled/cancelled/completed`; `meeting_time BETWEEN starts_at - interval '2 hours' AND starts_at`; `series_id` e `occurrence_date` ambos nulos ou ambos não nulos; cancelada exige `cancelled_at` e reason 1–1000, demais estados não carregam esses campos.
- `run_participations.status IN ('going','attended','no_show','cancelled')`.
- `posts`: body 1–2000 mesmo com imagem; image URL até 2048; `visibility IN ('public','members_only','private')`; pessoal aceita apenas `public/private`, grupo apenas `public/members_only`; `author_user_id` nulo somente se `group_id` não nulo.
- `comments`: body 1–1000. `activity_events.event_type IN ('run_created','run_joined','group_joined')`; metadata precisa ser objeto JSON. Dedupe key 1–200.
- `notifications`: type/target type 1–80, dedupe 1–200. `reports.target_type IN ('user','post','comment','group')`, status `open/in_review/resolved/dismissed`, reason 1–120, details até 2000, resolution até 2000; status final exige resolution.
- JSONB de auditoria/analytics precisa ser objeto; nomes/chaves têm 1–200. Eventos originados em cliente precisarão de identidade ou sessão anônima no Gate 12, enquanto eventos internos podem ter ambos nulos.
- Estados internos: jobs `pending/processing/completed/failed`; uploads `pending/ready/expired/failed`; owner transfer `pending/accepted/cancelled/expired`. Contadores/tamanhos não negativos; `expires_at` posterior à criação/janela; from/to owner diferentes.

### 1.4 Índices essenciais

Além de PK/UNIQUE: `profiles(city_id)` e índice parcial em `username WHERE username IS NOT NULL`; `groups(city_id,status)`; `group_members(user_id,status)` e `(group_id,role,status)`; `group_follows(group_id)`; `run_series(status,generated_through)` e `(city_id,status)`; `runs(city_id,visibility,status,starts_at)` e `(group_id,starts_at)`; `run_participations(user_id,status)` e `(run_id,status)`; `user_follows(followed_id)`; `posts(author_user_id,created_at DESC) WHERE deleted_at IS NULL` e `(group_id,created_at DESC) WHERE deleted_at IS NULL`; `comments(post_id,created_at) WHERE deleted_at IS NULL`; `activity_events(actor_user_id,created_at DESC)` e `(group_id,created_at DESC)`; `notifications(recipient_user_id,read_at,created_at DESC)`; `reports(status,created_at)`; `analytics_events(city_id,event_name,created_at)`; índices de expiração/status nas cinco tabelas internas. Não criar índices de busca textual nem contadores persistidos neste Gate.

### 1.5 Helpers, projeções e bootstrap administrativo

- `private.current_account_is_active()` retorna boolean para `auth.uid()`, é `STABLE SECURITY DEFINER`, não aceita `user_id` e é executável somente por `authenticated`.
- `private.account_is_active_for_visibility(uuid)` retorna apenas boolean para o ID da linha avaliada em policy; argumento é necessário porque `auth.uid()` não representa o perfil alvo. É executável por `anon`/`authenticated` e não revela motivo/status.
- `private.current_user_has_platform_role(text)` consulta apenas roles de `auth.uid()`, valida o papel permitido e é executável somente por `authenticated`.
- `private.set_updated_at()`, `private.enforce_profile_username()`, `private.assert_active_city_reference()` e os triggers de consistência não recebem grant de execução de cliente. Os dois triggers que leem tabelas fora da linha são `SECURITY DEFINER`, pertencem a `postgres`, fixam `search_path=''` e usam nomes qualificados.
- `public.profile_directory WITH (security_invoker=true)` seleciona somente `id,username,full_name,avatar_url,bio,city_id,running_level,preferred_distance,pace_seconds_per_km,created_at` e apenas linhas que a RLS de `profiles` permite. `anon` recebe grants de coluna correspondentes na tabela base para que a view invoker funcione, mas não recebe colunas `is_private`, `onboarding_completed` ou `updated_at`.
- Nenhum admin é inserido por migration/seed. No Gate 10, o bootstrap inicial será uma transação operacional revisada executada como `postgres`, por UUID explícito já existente em `auth.users`, com inserção simultânea em `platform_roles` e `admin_audit_logs`; não haverá e-mail, username ou metadata hardcoded. Este Gate testa roles somente por fixture transacional revertida.

### 1.6 Exclusão e anonimização

| Relação | `ON DELETE` | Razão |
| --- | --- | --- |
| `profiles.id → auth.users` | `CASCADE` | Perfil é dado pessoal removível. |
| `account_controls/platform_roles → auth.users` | `CASCADE` | Controles/roles deixam de ter utilidade após remoção da identidade. |
| `platform_roles.granted_by` | `SET NULL` | Preserva concessão sem identidade pessoal. |
| `groups.created_by/approved_by` | `SET NULL` | Preserva histórico do grupo. |
| `groups.owner_user_id` | `RESTRICT` | Obriga transferência antes de excluir owner. |
| membership/follows/likes/rate limits | `CASCADE` | Relações pessoais descartáveis. |
| `run_series.created_by`, `runs.created_by` | `SET NULL` | Preserva calendário/histórico operacional. |
| `run_participations.user_id` | `SET NULL` | Preserva registro técnico independente. |
| `posts.author_user_id` | `SET NULL` | Só post institucional de grupo pode sobreviver; pessoal será purgado antes. |
| `comments.user_id`, `activity_events.actor_user_id`, `notifications.actor_user_id` | `SET NULL` | Mantém referência mínima até retenção/purga. |
| `notifications.recipient_user_id` | `CASCADE` | Inbox é dado pessoal. |
| `reports.reporter_user_id/assigned_to`, `audit.actor_user_id`, `analytics.user_id` | `SET NULL` | Preserva evidência/contagem mínima sem identidade. |
| `group_id/city_id/run_id/series_id` históricos | `RESTRICT`, salvo relações descartáveis explicitadas | Evita apagar domínio por cascata. |
| tabelas internas efêmeras | `CASCADE` apenas para bucket, follow, like, transferência pendente/recipient inbox | Não são histórico durável. |

Gate 1 prova o comportamento físico das FKs, mas não implementa o fluxo completo de exclusão de conta; revogação de sessões, purga de mídia/conteúdo e transferência assistida pertencem ao Gate 10.

## 2. Mapa de arquivos

| Caminho | Responsabilidade |
| --- | --- |
| `supabase/config.toml` | Configuração local gerada por `supabase init`; `public` exposto, `private` ausente, migrations/seed habilitados. |
| `supabase/migrations/*_foundation.sql` | Extensão, schema `private`, defaults de privilégios, funções comuns. |
| `supabase/migrations/*_identity_geography.sql` | Cidades, settings, perfis, controles, roles, usernames e triggers associados. |
| `supabase/migrations/*_groups_runs.sql` | Grupos, membros, follows, séries, corridas, participações e invariantes de owner/ocorrência. |
| `supabase/migrations/*_social_operations.sql` | Follows pessoais, posts, likes, comments, atividades e notificações. |
| `supabase/migrations/*_internal_operations.sql` | Reports, auditoria, analytics, jobs, uploads, rate limits, transfers e receipts em `private`. |
| `supabase/migrations/*_authorization.sql` | RLS, grants, helpers autorizados e `profile_directory`. |
| `supabase/seed.sql` | Apenas cidade determinística e `app_settings`, com UPSERT idempotente. |
| `supabase/tests/database/00_foundation_test.sql` | Schemas, extensão, defaults e funções comuns. |
| `supabase/tests/database/10_identity_geography_test.sql` | Schema/seed/profile/username/onboarding. |
| `supabase/tests/database/20_group_run_schema_test.sql` | Constraints, relações e owner/occurrence. |
| `supabase/tests/database/30_social_internal_schema_test.sql` | Social, operação e presença das estruturas internas. |
| `supabase/tests/database/40_constraints_test.sql` | Limites de texto, estados, tempo, distância, pace e pares. |
| `supabase/tests/database/50_delete_behavior_test.sql` | `CASCADE`, `SET NULL`, `RESTRICT` e anonimização estrutural. |
| `supabase/tests/database/60_rls_public_reads_test.sql` | `anon`, cidades/settings e projeção pública. |
| `supabase/tests/database/70_rls_profiles_test.sql` | user A/B, profile próprio/privado e conta suspensa. |
| `supabase/tests/database/80_roles_controls_test.sql` | moderator/admin, autoelevação e controles privados. |
| `supabase/tests/database/90_private_surface_test.sql` | Grants, ausência de policies futuras e inacessibilidade de `private`. |
| `src/types/database.ts` | Tipos TypeScript gerados de `public`; nunca editados manualmente. |
| `package.json` | Scripts explícitos de start/stop/reset/test/lint/types. |
| `package-lock.json` | Deve permanecer inalterado enquanto a versão já fixada da CLI não mudar; qualquer diferença inesperada é revisada antes de commit. |
| `.gitignore` | Estado temporário do Supabase e artefatos de verificação remota, sem ignorar migrations/config/types. |
| `.github/workflows/ci.yml` | Job de aplicação existente mais job `database` local/efêmero sem secrets. |
| `README.md` | Workflow local/remoto, segurança, custo e fronteira com Gate 2. |

Arquivos de migrations sempre são criados pelos comandos `supabase migration new` nomeados em cada Task; o timestamp do arquivo é gerado pela CLI e nunca digitado manualmente. Não adotar `supabase/schemas/` neste Gate, pois migrations seriam duas fontes concorrentes.

## Tasks

### Task 1: Abrir a branch e inicializar a stack local

**Files:** criar `supabase/config.toml`; modificar `.gitignore` somente para artefatos realmente gerados; adicionar scripts explícitos ao `package.json`.

**Interfaces:** produz a raiz Supabase versionada e um runtime local saudável; migrations posteriores consomem `supabase/config.toml`.

- [ ] Confirmar `main` limpa e sincronizada: `git status --short`, `git branch --show-current`, `git pull --ff-only origin main`. Reativar/reutilizar o Node fixado pela `.nvmrc`, exigir `node --version` igual a `v24.21.0`, validar npm compatível e então executar `npm exec --no -- supabase --version`; criar `feature/gate-1-database-base` somente depois dessas verificações.
- [ ] Detectar runtime sem instalar: `Get-Command docker,podman,nerdctl -ErrorAction SilentlyContinue`; para Docker, executar `docker version` e exigir cliente/servidor saudáveis. Reutilizar runtime compatível existente.
- [ ] Se nenhum runtime compatível estiver saudável, instalar uma opção gratuita compatível com Docker APIs. Em Windows, verificar primeiro elegibilidade do Docker Desktop para uso pessoal não comercial; se não for elegível, usar Rancher Desktop ou Podman somente após confirmar compatibilidade atual da Supabase CLI. Elevação administrativa, aceite de licença ou reboot obrigatório é fronteira humana; o agente inicia o instalador e solicita somente a ação inevitável.
- [ ] Executar `npm exec --no -- supabase init --yes`; inspecionar todos os arquivos gerados antes de editar. Não usar `--force`.
- [ ] Ajustar `config.toml` para `project_id = "correhub"`, seed habilitado com `sql_paths = ["./seed.sql"]`, migrations habilitadas e `[api].schemas` contendo `public`/schemas gerenciados gerados, nunca `private`. Não habilitar Auth provider, Storage bucket ou credencial externa.
- [ ] Adicionar ao `package.json`, antes de qualquer Task que os invoque:

```json
{
  "db:start": "supabase start --exclude studio,imgproxy,mailpit,edge-runtime,logflare,vector,realtime,storage-api,supavisor",
  "db:stop": "supabase stop",
  "db:reset": "supabase db reset --local",
  "db:test": "supabase test db --local supabase/tests/database",
  "db:lint": "supabase db lint --local --schema public,private --level warning --fail-on error",
  "db:types": "supabase gen types --local --lang typescript --schema public > src/types/database.ts"
}
```

Confirmar que `package-lock.json` não muda, pois nenhuma dependência foi alterada. Se a lista de exclusão impedir health/PostgREST na CLI 2.117.0 real, reduzir somente após reproduzir e documentar; manter `postgres` e `postgrest` disponíveis para testes.
- [ ] Incluir no `.gitignore` somente `supabase/.temp/`, `supabase/.branches/` e arquivos locais sensíveis que a CLI efetivamente gerar. Confirmar que `config.toml`, migrations, seed, testes e tipos continuam rastreáveis.
- [ ] Executar `npm exec --no -- supabase start`, `npm exec --no -- supabase status -o json` e exigir serviços saudáveis; então `npm exec --no -- supabase stop`. Não imprimir o objeto de status completo porque ele pode conter chaves locais; registrar apenas nomes/health.
- [ ] Verificar `git diff --check`, staged files e ausência de secrets. Commit: `chore: initialize reproducible Supabase workspace`.

### Task 2: Criar a fundação PostgreSQL e privilégios padrão

**Files:** criar migration `*_foundation.sql` e teste `00_foundation_test.sql`.

**Interfaces:** produz `private`, `pgcrypto`, `private.set_updated_at()`, validação de timezone e defaults deny-by-default consumidos por todas as migrations.

- [ ] Criar primeiro `00_foundation_test.sql` com `begin; select plan(...)`, assertions `has_schema('private')`, `has_extension('pgcrypto')`, `has_function(...)`, verificações dos objetos atuais em `information_schema.role_table_grants` e dos privilégios padrão futuros em `pg_default_acl`. Executar `npm exec --no -- supabase test db --local supabase/tests/database/00_foundation_test.sql` e confirmar falha porque a migration ainda não existe.
- [ ] Criar a migration por `npm exec --no -- supabase migration new foundation`. Implementar `create schema if not exists private`, `create extension if not exists pgcrypto with schema extensions`, `private.set_updated_at()`, `private.assert_valid_timezone()` e revogações explícitas:

```sql
revoke all on schema private from public, anon, authenticated;
alter default privileges for role postgres in schema public
  revoke select, insert, update, delete on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke usage, select on sequences from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;
alter default privileges for role postgres in schema private
  revoke all on tables from public, anon, authenticated;
alter default privileges for role postgres in schema private
  revoke execute on functions from public, anon, authenticated;
```

- [ ] Todas as funções declaram volatility correta, nomes qualificados e `SET search_path = ''`; não especificar versão de extensão. Executar `npm run db:reset`, `npm exec --no -- supabase test db --local supabase/tests/database/00_foundation_test.sql` e `npm run db:lint`; esperado PASS e nenhum erro crítico.
- [ ] Verificar migration com `npm exec --no -- supabase migration list --local`, `git diff --check` e commit `feat: establish PostgreSQL security foundation`.

### Task 3: Implementar identidade, geografia e seed determinístico

**Files:** criar migration `*_identity_geography.sql`, `supabase/seed.sql`, testes `10_identity_geography_test.sql`.

**Interfaces:** produz `cities`, `app_settings`, `profiles`, `account_controls`, `platform_roles`, `reserved_usernames` e a cidade de lançamento; Gate 2 consumirá as tabelas sem trigger Auth automático.

- [ ] Escrever testes falhando para tabelas/colunas/FKs, username, lista reservada, onboarding incompleto/completo, pace e seed. Incluir assertion de que inserir `auth.users` não cria profile/control automaticamente.
- [ ] Criar migration com `npm exec --no -- supabase migration new identity_geography`; implementar exatamente o catálogo 1.2 e constraints 1.3. `private.enforce_profile_username()` é trigger `BEFORE INSERT OR UPDATE OF username`, `SECURITY DEFINER` endurecido, e lança SQLSTATE `23514` para reserva; `UNIQUE(username)` trata concorrência. O trigger de cidade ativa rejeita concluir onboarding em cidade inativa sem afetar profile histórico já concluído.
- [ ] Criar `supabase/seed.sql` somente com UPSERTs por IDs determinísticos:

```sql
insert into public.cities
  (id,name,country_code,state_code,slug,timezone,is_active)
values
  ('10000000-0000-4000-8000-000000000001','São Lourenço da Mata','BR','PE','sao-lourenco-da-mata','America/Recife',true)
on conflict (id) do update set
  name=excluded.name, country_code=excluded.country_code,
  state_code=excluded.state_code, slug=excluded.slug,
  timezone=excluded.timezone, is_active=excluded.is_active;

insert into public.app_settings (id,launch_city_id)
values ('10000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001')
on conflict (id) do update set launch_city_id=excluded.launch_city_id;
```

- [ ] Rodar RED antes da migration; depois `npm run db:reset` e `npm exec --no -- supabase test db --local supabase/tests/database/10_identity_geography_test.sql`. Executar o seed novamente com `npm exec --no -- supabase db query --local --file supabase/seed.sql` e confirmar uma cidade/um singleton sem duplicação.
- [ ] Casos obrigatórios: `valid_runner` passa; `ValidRunner`, `ab`, 31 caracteres, hífen e cada username reservado falham; duplicação falha com `23505`; full name/bio/pace inválidos falham; profile incompleto aceita somente os nulos previstos; `onboarding_completed=true` sem cada campo obrigatório ou com cidade inativa falha.
- [ ] Confirmar nenhuma linha em `auth.users`, `profiles`, `account_controls` ou `platform_roles` permanece fora das transações de teste. Commit `feat: add identity geography and launch seed`.

### Task 4: Criar a estrutura de grupos, séries, corridas e participações

**Files:** migration `*_groups_runs.sql`, testes `20_group_run_schema_test.sql` e parte de `40_constraints_test.sql`.

**Interfaces:** produz tabelas estruturais dos Gates 4–6 e invariantes de owner/ocorrência, sem liberar operações a clientes.

- [ ] Escrever testes RED para tabelas, FKs, `ON DELETE`, pares únicos, owner parcial, estados, limites, coerência de aprovação, séries e corridas.
- [ ] Criar migration por `npm exec --no -- supabase migration new groups_runs`; implementar catálogo/constraints/índices de grupos e corridas.
- [ ] Implementar `private.assert_group_owner_consistency()` com constraint triggers `DEFERRABLE INITIALLY DEFERRED` em `groups` e `group_members`. O teste usa `SET CONSTRAINTS ALL IMMEDIATE` para provar: segundo owner ativo falha; owner divergente falha; pending com owner/pending passa; approved com owner/active correspondente passa.
- [ ] Usar FK composta `(series_id,group_id,city_id)` para impedir ocorrência em grupo/cidade diferentes. Testar ocorrência única, evento avulso com ambos campos nulos e combinação parcial inválida.
- [ ] Testar `meeting_time`, offset, weekday, datas, capacidade, distância, nível e rejeição de cidade inativa na criação sem implementar geração de recorrência nem reserva de vaga.
- [ ] Executar `npm run db:reset`, depois `npm exec --no -- supabase test db --local supabase/tests/database/20_group_run_schema_test.sql`, repetir para `40_constraints_test.sql`, e rodar `npm run db:lint`; commit `feat: define group and running domain schema`.

### Task 5: Criar social, operação e estruturas privadas

**Files:** migrations `*_social_operations.sql`, `*_internal_operations.sql`; testes `30_social_internal_schema_test.sql`, completar `40_constraints_test.sql` e criar `50_delete_behavior_test.sql`.

**Interfaces:** produz persistência estrutural dos Gates 3, 8, 9, 10 e 12 e tabelas internas, todas inacessíveis a clientes neste Gate.

- [ ] Escrever testes RED para todas as tabelas/colunas, self-follow, pares únicos, visibilidade de posts, conteúdo em branco, JSON objeto, dedupe e estados internos.
- [ ] Criar as duas migrations via `supabase migration new social_operations` e `supabase migration new internal_operations`; implementar catálogo, constraints e índices definidos nas seções 1.2–1.4.
- [ ] Não criar validação polimórfica privilegiada nem RPC de escrita neste Gate; `target_type/target_id` ficam restritos por CHECK/NOT NULL e serão validados pela operação transacional do Gate responsável.
- [ ] Em `50_delete_behavior_test.sql`, criar usuários/grupo/corrida/participação/post institucional dentro de `BEGIN/ROLLBACK`; apagar identidades e provar: profile/control/roles/follows/likes/bucket somem; autoria/participação/auditoria vira nula; grupo/corrida continuam; apagar owner é bloqueado até transferência; apagar run/series referenciada é bloqueado.
- [ ] Testar que apagar post remove likes/comments, apagar grupo remove relações descartáveis mas é bloqueado quando domínio histórico o referencia, e inbox é removida com destinatário.
- [ ] Executar reset; rodar separadamente `supabase test db --local` pela CLI versionada para `30_social_internal_schema_test.sql`, `40_constraints_test.sql` e `50_delete_behavior_test.sql`; executar DB lint. Commit `feat: add social and private operational schema`.

### Task 6: Aplicar RLS, grants, helpers e projeção pública

**Files:** migration `*_authorization.sql`; testes `60_rls_public_reads_test.sql`, `70_rls_profiles_test.sql`, `80_roles_controls_test.sql`, `90_private_surface_test.sql`.

**Interfaces:** produz acesso público mínimo, profile próprio e helpers de autorização; todos os fluxos futuros permanecem deny-by-default.

- [ ] Criar fixtures transacionais nos próprios testes com UUIDs fixos para user A, user B, moderator, platform_admin e suspended. Antes de cada operação RLS, usar:

```sql
set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}';
-- assertion pgTAP
reset role;
```

Para anon, `set local role anon` e claims vazias. Inserções de fixture em `auth.users`, profiles/controls/roles acontecem como `postgres` antes da troca de role e são revertidas no final.
- [ ] Escrever RED provando que `anon` lê cidades ativas e inativas/settings e não escreve; user A lê/edita o próprio perfil, não edita B; privado B não aparece; follow não altera privacidade; suspended não muta; usuário comum não lê/escreve roles/controls.
- [ ] Criar migration `authorization`. Habilitar RLS em todas as tabelas listadas no mapa. Conceder somente:
  - `cities`: `SELECT` para `anon,authenticated` com policy `cities_read_public USING (true)`; `is_active` controla elegibilidade de novas associações, não a leitura histórica;
  - `app_settings`: `SELECT` para `anon,authenticated` com policy `app_settings_read` usando o ID singleton;
  - `profiles`: grants de SELECT por colunas públicas a `anon`; SELECT das colunas do perfil a `authenticated`; UPDATE apenas de `username,full_name,avatar_url,bio,city_id,running_level,preferred_distance,pace_seconds_per_km,is_private,onboarding_completed` a `authenticated`;
  - policies separadas `profiles_read_public_anon`, `profiles_read_authenticated` e `profiles_update_own`: leitura pública exige `onboarding_completed`, `is_private=false` e conta alvo ativa; authenticated vê também a própria linha; follow não participa do predicado; update exige em `USING` e `WITH CHECK` `auth.uid()=id` e `private.current_account_is_active()`.
- [ ] Implementar os três helpers da seção 1.5 como `SECURITY DEFINER` pertencentes a `postgres`, `SET search_path=''`, referências totalmente qualificadas, revogar `EXECUTE` de `PUBLIC` e conceder apenas às roles declaradas. Nenhum helper aceita ator fornecido pelo cliente.
- [ ] Criar `profile_directory WITH (security_invoker=true)` e grants mínimos. Testar que colunas privadas/operacionais não podem ser selecionadas por anon e que a view não burla RLS.
- [ ] Para todas as demais tabelas `public`: `REVOKE ALL FROM anon,authenticated`, RLS ON, zero policies. Para `private`: revogar schema/tabelas/sequences/functions de `PUBLIC,anon,authenticated`, depois conceder somente `USAGE private` e `EXECUTE` nos helpers autorizados. Testar `has_table_privilege(...)=false` e tentativas reais com erro `42501`.
- [ ] Testar ausência de policy: authenticated não insere grupo/run/post/participação, não lê notification/report/audit/analytics e não atribui `platform_admin`/`moderator`. Fixtures de roles não alteram essa negação, pois os fluxos administrativos pertencem ao Gate 10.
- [ ] Executar todos os testes, `npm run db:lint` com warnings analisados e commit `feat: enforce database authorization boundaries`.

### Task 7: Fechar a suíte PostgreSQL e ensaiar reset limpo

**Files:** revisar todos os arquivos em `supabase/tests/database/`; nenhuma migration nova sem defeito reproduzido.

**Interfaces:** produz evidência completa de schema, seed, constraints, RLS, privacidade e exclusão.

- [ ] Contar assertions com `plan(N)` exato em cada arquivo; cada teste usa `BEGIN`, `finish()` e `ROLLBACK`, sem depender da ordem ou de dados deixados por outro teste.
- [ ] Rodar `npm run db:stop`; depois `npm run db:start`, `npm run db:reset`, `npm run db:test`, `npm run db:lint`. Esperado: reset aplica todas migrations e seed; todos arquivos pgTAP `ok`; lint sem erro. Warning de segurança precisa ser corrigido ou documentado com causa concreta, nunca ignorado globalmente.
- [ ] Repetir `npm run db:reset` e `npm run db:test` para provar idempotência. Executar seed manualmente uma segunda vez e confirmar contagens/IDs/configuração.
- [ ] Consultar catálogos para confirmar: todas as FKs têm ação esperada; todas tabelas `public/private` têm RLS; zero grants imprevistos a client roles; zero policy fora das quatro famílias autorizadas; `private` ausente de schemas da API.
- [ ] Verificar que fixtures não aparecem em `seed.sql` e não persistem após testes. Commit `test: verify database constraints and RLS` somente se esta Task acrescentar/corrigir testes; caso o HEAD já contenha toda a suíte correta, não criar commit vazio.

### Task 8: Adicionar scripts, tipos gerados e documentação local

**Files:** revisar `package.json`, criar `src/types/database.ts`, modificar `.gitignore` e `README.md`.

**Interfaces:** produz comandos estáveis usados por desenvolvedores e CI; Gate 2 importa `Database` de `src/types/database.ts`.

- [ ] Confirmar que os seis scripts adicionados na Task 1 permanecem explícitos e locais: start, stop, reset, test, lint e types. Não adicionar flags remotas nem wrappers ocultos.
- [ ] Rodar `npm run db:types`; conferir que o arquivo contém `Database['public']`, tabelas/views e nenhuma definição de `private`. Nunca editar o gerado manualmente.
- [ ] Rodar `npm run db:types`, calcular o hash SHA-256, rodar novamente e exigir o mesmo hash. Depois de adicionar o arquivo ao índice, uma terceira geração seguida de `git diff --exit-code -- src/types/database.ts` prova que o gerador não alterou o conteúdo staged.
- [ ] README documenta start/status/reset/test/lint/types/stop, migrations como fonte, seed sem fixtures, diferença `--local`/`--linked`, `private` fora da API, nenhuma integração Next/Supabase até Gate 2, runtime obrigatório e custo R$0. Não copiar catálogo inteiro nem registrar segredo/URL privada.
- [ ] Verificar `.gitignore`: `.env.local`, `.vercel`, `supabase/.temp`, `.branches` e `.local` ignorados; migration/config/seed/tests/types rastreáveis.
- [ ] Executar `npm run lint`, `npm run typecheck`, `npm run test`, `npm run build` sem `.env.local`, além de todos DB scripts. Commit `chore: add reproducible database workflow and types`.

### Task 9: Estender CI e validar o PR sem banco remoto

**Files:** modificar `.github/workflows/ci.yml`.

**Interfaces:** produz job `database` efêmero, sem secrets ou projeto remoto; Task 10 exige esse job verde.

- [ ] Preservar o job `quality`. Adicionar job `database` em `ubuntu-latest`, `timeout-minutes: 20`, `permissions: contents: read`, com checkout/setup Node, `npm ci`, verificação `docker info`, `npm run db:start`, `npm run db:reset`, `npm run db:test`, `npm run db:lint`, `npm run db:types`, `git diff --exit-code -- src/types/database.ts` e `npm run db:stop` em step `if: always()`.
- [ ] Não adicionar `SUPABASE_ACCESS_TOKEN`, project ref, database password, service role, publishable key ou qualquer environment de produção ao workflow.
- [ ] Reproduzir localmente a ordem do job desde instalação limpa quando o filesystem permitir; o GitHub executará `npm ci` sobre o HEAD e é a prova canônica multiplataforma.
- [ ] Verificar YAML, `git diff --check`, secret scan e commit `ci: validate Supabase migrations and RLS`.
- [ ] Push da branch, criar PR draft contra `main` e acompanhar os jobs `quality` e `database`. Corrigir causa raiz de qualquer falha com commit `fix:` específico. Somente CI verde permite provisionamento remoto.

### Task 10: Criar e validar um único projeto Supabase Free

**Files:** nenhuma credencial versionada; atualizar README apenas com project ref/region se isso for útil e não sensível.

**Interfaces:** produz projeto remoto `correhub` em `sa-east-1`, link local e schema equivalente às migrations; Gate 2 consumirá o projeto depois de planejamento próprio.

- [ ] Reconfirmar preço/cotas Free e que a organização escolhida está no plano Free. Verificar sessão por `npm exec --no -- supabase projects list --output-format json`. Se não autenticado, iniciar `supabase login`; usuário conclui somente OAuth/token inevitável.
- [ ] Executar `supabase orgs list --output-format json`. Se houver uma organização pessoal inequívoca, usá-la; se houver múltiplas elegíveis sem contexto suficiente, pedir somente a escolha da organização. Não criar organização nova sem necessidade.
- [ ] Inspecionar projetos existentes. Se já existir exatamente um projeto `correhub` Free, autorizado e compatível com este repositório, reutilizá-lo após provar que não contém dados a preservar; caso contrário, confirmar que será consumida apenas uma vaga Free e criar um único projeto. Não criar projeto alternativo para contornar pausa/cota.
- [ ] Gerar senha criptograficamente forte em memória, armazenar temporariamente apenas em variável de processo `SUPABASE_DB_PASSWORD` e nunca imprimi-la. Criar sem `--size`, garantindo Nano Free, em São Paulo:

```powershell
npm exec --no -- supabase projects create correhub `
  --org-id $OrgId `
  --db-password $env:SUPABASE_DB_PASSWORD `
  --region sa-east-1
```

Se a plataforma exigir 2FA/interação humana para o segredo, solicitar apenas essa etapa. Não habilitar high availability ou add-on.
- [ ] Aguardar status saudável via listagem/Management API da CLI sem imprimir chaves. Linkar: `npm exec --no -- supabase link --project-ref $ProjectRef --password $env:SUPABASE_DB_PASSWORD`; limpar a variável após sucesso e verificar que arquivos temporários/sensíveis estão ignorados.
- [ ] Executar `npm exec --no -- supabase db push --linked --dry-run --include-seed --skip-vault`; revisar migrations/seed listados. Depois executar o mesmo sem `--dry-run`. Nunca usar reset linked.
- [ ] Verificar `supabase migration list --linked`, `supabase db lint --linked --schema public,private --level warning --fail-on error` e queries remotas read-only por `supabase db query --linked`: cidade existe exatamente uma vez com os cinco valores corretos/ativa; singleton aponta ao UUID da cidade; nenhuma fixture; todas tabelas/RLS/grants esperados; nenhuma policy futura.
- [ ] Gerar tipos remotos para `.local/database.remote.ts` com `supabase gen types --linked --lang typescript --schema public`, comparar byte a byte com `src/types/database.ts` e remover o temporário. Divergência bloqueia conclusão e deve ser resolvida por migration, nunca por ajuste manual remoto.
- [ ] Fazer smoke da Data API sem revelar chave: capturar a publishable key de `supabase projects api-keys --project-ref $ProjectRef --output-format json` apenas em memória, solicitar `/rest/v1/cities` e `/rest/v1/app_settings` com status 200/dados esperados; provar que schema `private` retorna acesso negado e que `anon` não escreve. Não usar `--reveal`, não salvar chave e não configurar Vercel.
- [ ] Registrar evidência de plano Free, região, project ref, migration history, lint e smoke no PR/README sem senha/token/key. Commit `docs: record validated Supabase Free database` e push; esperar os dois jobs CI verdes novamente.

### Task 11: Auditoria final, merge e validação pós-merge

**Files:** corrigir somente defeitos encontrados; nenhuma feature de Gate 2+.

**Interfaces:** entrega Gate 1 em `main`, banco remoto equivalente e documentação executável.

- [ ] Rodar em ordem: `npm run db:start`, `npm run db:reset`, `npm run db:test`, `npm run db:lint`, `npm run db:types`, `git diff --exit-code -- src/types/database.ts`, `npm run lint`, `npm run typecheck`, `npm run test`, `npm run build`, `npm run db:stop`.
- [ ] Executar checklist completo de aceite abaixo; comparar linha a linha com seções 6–9, 20 e Gate 1 da seção 22 da spec. Repassar todas as FKs/ON DELETE, nulabilidade, estados, checks, grants, policies e schemas expostos.
- [ ] Secret scan apenas em arquivos rastreados; confirmar `.env.local`, `.vercel`, `supabase/.temp`, `.branches`, senha/token/key/service role não versionados. Confirmar que Vercel não recebeu env Supabase.
- [ ] Exigir revisão final independente do diff, PR draft com CI `quality` e `database` verdes, local reset/test verde, remoto equivalente e custo R$0. Resolver findings Critical/Important antes do merge.
- [ ] Tornar PR pronto e fazer merge com `gh pr merge --merge --delete-branch`, sem bypass. Atualizar `main` por `git pull --ff-only origin main`; exigir CI de `main` verde.
- [ ] Revalidar `migration list --linked`, tipos remoto/local, seed e smoke público após o merge. O deploy automático da Vercel pode ocorrer, mas não alterar env/configuração; smoke da landing existente garante ausência de regressão.
- [ ] `git status --short` final vazio e histórico com commits pequenos. Documentar CLI, Postgres local/remoto, project ref/region, testes, CI, segurança, ausência de Gate 2 e custo R$0.

## Identidades e testes RLS

UUIDs de fixture são fixos apenas dentro dos arquivos pgTAP e sempre revertidos:

| Ator | UUID de teste | Controle/role |
| --- | --- | --- |
| user A | `aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa` | active, profile público |
| user B | `bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb` | active, profile privado |
| moderator | `cccccccc-cccc-4ccc-8ccc-cccccccccccc` | active + moderator |
| platform_admin | `dddddddd-dddd-4ddd-8ddd-dddddddddddd` | active + platform_admin |
| suspended | `eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee` | suspended |

Cada teste que precisa desses atores cria registros em `auth.users`, `profiles` e `account_controls` dentro da própria transação. Nenhum helper de teste, claim especial ou bypass é instalado por migration/seed. O teste usa o mesmo `auth.uid()` que policies reais usam.

## CI database job previsto

```yaml
database:
  runs-on: ubuntu-latest
  timeout-minutes: 20
  steps:
    - uses: actions/checkout@v7
    - uses: actions/setup-node@v7
      with:
        node-version-file: .nvmrc
        cache: npm
    - run: npm ci
    - run: docker info
    - run: npm run db:start
    - run: npm run db:reset
    - run: npm run db:test
    - run: npm run db:lint
    - run: npm run db:types
    - run: git diff --exit-code -- src/types/database.ts
    - if: always()
      run: npm run db:stop
```

O job não usa produção, secrets ou Supabase remoto. Uma única inicialização local atende reset, pgTAP, lint e tipos, reduzindo minutos do GitHub Free.

## Human authorization boundaries

| Momento | Condição inevitável | Ação mínima humana | Retomada do agente |
| --- | --- | --- | --- |
| Runtime local | Instalador exige elevação, aceite de licença ou reboot | Autorizar elevação/licença gratuita elegível ou reiniciar quando solicitado | Confirmar runtime/daemon e continuar `supabase start`. |
| Supabase login | `projects list` informa sessão ausente/expirada | Concluir OAuth/token no fluxo iniciado pelo agente | Listar projetos/orgs e continuar. |
| Organização | Há múltiplas organizações Free elegíveis sem escolha inequívoca | Informar qual organização autorizada usar | Criar exatamente um projeto nela. |
| 2FA/segredo | Plataforma exige interação humana para 2FA ou confirmação de senha | Concluir somente a confirmação exibida | Agente linka, aplica e valida migrations. |

Não pedir ao usuário para instalar manualmente por comandos, executar SQL, migrations, seed, testes, link ou push.

## Critérios de aceite e evidência exigida

- [ ] `supabase init` versionado corretamente; `.temp/.branches` ignorados.
- [ ] Runtime Docker-compatible e stack local saudáveis.
- [ ] Migrations reproduzíveis do zero e `db reset` repetido com sucesso.
- [ ] Seed idempotente; São Lourenço da Mata existe exatamente com `BR`, `PE`, slug, timezone e ativa.
- [ ] `app_settings.launch_city_id` aponta ao UUID determinístico da cidade.
- [ ] Todas as entidades da seção 7 existem no schema decidido, sem tabela futura omitida.
- [ ] FKs, nulabilidade e `ON DELETE` conferidos por catálogo e teste físico.
- [ ] Constraints de username, conteúdo, estados, datas, distâncias, pace, capacidade, pares, owner e ocorrência testadas.
- [ ] Índices essenciais presentes; nenhum contador persistido ou índice prematuro.
- [ ] RLS habilitada em todas as tabelas `public` e `private`.
- [ ] Grants mínimos e explícitos; ausência de policy/grant nega features futuras.
- [ ] `account_controls`, roles, reports, auditoria, analytics e estruturas internas não acessíveis por client roles/Data API.
- [ ] Username lowercase 3–30, regex, unique concorrente e reserved list protegidos no banco.
- [ ] `anon` não escreve profile; A não edita B; follow não abre privado; suspended não muta.
- [ ] Usuário não lê/altera controls/roles e não se torna moderator/admin.
- [ ] Seed de produção sem usuários, grupos, corridas, posts ou fixtures.
- [ ] Todos os arquivos pgTAP verdes, isolados e revertidos.
- [ ] DB lint local/remoto sem problema crítico ignorado.
- [ ] `src/types/database.ts` gerado, determinístico e igual ao remoto.
- [ ] CI `quality` e `database` verdes no PR e em `main`.
- [ ] Exatamente um projeto remoto Supabase Free, `sa-east-1`, saudável e linkado.
- [ ] Migration history local/remota equivalente e seed remoto verificado.
- [ ] Data API permite apenas leituras públicas planejadas e nega `private`/escritas anon.
- [ ] App continua lint/typecheck/test/build sem credenciais Supabase.
- [ ] Nenhum segredo versionado, impresso ou enviado à Vercel.
- [ ] Nenhuma feature de Gate 2+ implementada.
- [ ] Custo obrigatório **R$ 0**.

## Fora do escopo explícito

Gate 1 não entrega Google OAuth, login UI, callback, middleware/proxy de sessão, criação automática de profile ao autenticar, onboarding UI, descoberta de pessoas, follows funcionais, solicitação/aprovação/transferência de grupo funcional, criação/recorrência/cancelamento de corrida funcional, participação/capacidade/agenda funcional, feed, upload/Storage, notificações funcionais, admin UI, moderação funcional, analytics UI ou SEO novo. Tabelas e constraints existem para que esses Gates partam de uma base segura; grants, policies e RPCs de cada comportamento chegam junto do Gate proprietário.

## Commits planejados

1. `chore: initialize reproducible Supabase workspace`
2. `feat: establish PostgreSQL security foundation`
3. `feat: add identity geography and launch seed`
4. `feat: define group and running domain schema`
5. `feat: add social and private operational schema`
6. `feat: enforce database authorization boundaries`
7. `test: verify database constraints and RLS` — somente se Task 7 produzir alteração real.
8. `chore: add reproducible database workflow and types`
9. `ci: validate Supabase migrations and RLS`
10. `docs: record validated Supabase Free database`

Commits `fix:` adicionais somente respondem a defeito reproduzido em reset, pgTAP, lint, CI ou remoto.

## Referências verificadas para a execução

- Supabase local workflow: <https://supabase.com/docs/guides/local-development/cli-workflows>
- Database migrations: <https://supabase.com/docs/guides/local-development/database-migrations>
- Database testing/pgTAP: <https://supabase.com/docs/guides/database/testing>
- Seeding: <https://supabase.com/docs/guides/local-development/seeding-your-database>
- RLS, grants e views invoker: <https://supabase.com/docs/guides/database/postgres/row-level-security>
- Custom schemas/Data API: <https://supabase.com/docs/guides/api/using-custom-schemas>
- Breaking change de grants explícitos: <https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically>
- Regiões: <https://supabase.com/docs/guides/platform/regions>
- Plano Free/cotas: <https://supabase.com/docs/guides/platform/billing-on-supabase>

## Self-review obrigatório antes de executar

O executor relê integralmente a spec e compara este plano linha a linha com as seções 6–9 e 20 e com o Gate 1 da seção 22. Deve revisar todas as FKs, ações de exclusão, nulabilidade, estados, checks, grants, RLS, schemas expostos, helpers definer, seed, idempotência, testes, CI, remoto, segredos, build sem env e custo. Uma varredura por marcadores de incompletude deve retornar vazia. Nenhuma Task deste plano está autorizada até a revisão humana deste arquivo.
