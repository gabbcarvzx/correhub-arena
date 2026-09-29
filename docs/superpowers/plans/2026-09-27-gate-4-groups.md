# CorreHub Gate 4 — Groups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. For every user-facing UI task, also use `$ui-ux` and `$frontend-production-shadcn` according to `AGENTS.md`.

**Goal:** entregar o domínio completo de grupos do Gate 4 com solicitação, aprovação independente e atômica, membership, hierarquia, ownership transfer, follows e interface administrativa mínima, sem antecipar corridas.

**Architecture:** O PostgreSQL continua sendo a autoridade: tabelas base permanecem sem DML livre e operações com mais de um efeito passam por RPCs transacionais estreitas, com identidade, conta, papel e estado revalidados no banco. Leituras usam projeções/RPCs sanitizadas para separar grupo público, solicitação do owner, roster contextual e revisão administrativa; Server Actions apenas validam input, chamam esses contratos e traduzem erros. A interface Next.js mantém cada objeto no seu contexto e usa Storage privado mediado por servidor para avatar/capa, sem transformar o Gate em busca ampla, corridas ou painel administrativo completo.

**Tech Stack:** Next.js 16.3.5 App Router, React 19.3.0, TypeScript 5.9.3 strict, Tailwind CSS 4.3.3, componentes shadcn/ui incorporados ao repositório, React Hook Form 7.88.0, Zod 4.6.5, Supabase PostgreSQL/Auth/Storage/RLS, `@supabase/supabase-js` 2.117.2, `@supabase/ssr` 0.12.7, Supabase CLI 2.117.0, Vitest 5.0.1, Testing Library 16.3.3, pgTAP e Playwright Chromium 1.63.0. Para mídia, `sharp` será dependência direta server-only; Radix Alert Dialog, CVA, `clsx`, `tailwind-merge` e Lucide serão adicionados somente se a auditoria da Task 8 confirmar ausência de equivalente local, sempre com versão exata no lockfile.

**Spec:** `docs/superpowers/specs/2026-09-19-correhub-mvp-design.md`

## Global Constraints

- Baseline confirmada em 27/09/2026: `main`/`origin/main` em `757e1b6313e09616a01a330a479315e897f059eb`, dez migrations, 26 tabelas, Supabase `svvthxrixrnrrgosydtg`, Next 16.3.5 e Gate 3 integrado. As dez migrations existentes são imutáveis.
- Branch de execução: `feature/gate-4-groups`, criada em worktree isolado; ledger `.superpowers/sdd/2026-09-27-gate-4-groups/progress.md` fica fora do produto e nunca contém segredos.
- Implementar somente solicitação, decisão, perfil/gestão de grupo, memberships, hierarquia, transferência, follows, efeitos persistentes, mídia do grupo e fila administrativa mínima. Não criar corrida, série, agenda, feed, post, central de notificações, analytics UI, denúncias ou painel completo.
- `community` e `professional` têm as mesmas permissões e custo. Não criar billing, entitlement, assinatura ou integração financeira.
- Conta ativa e onboarding completo são revalidados no banco em toda mutação humana; JWT válido de conta suspensa não concede poder.
- Ator, `created_by`, `owner_user_id`, papel, status, decisão e timestamps nunca vêm como autoridade do payload. Server Actions recebem `unknown`/`FormData`; RPCs derivam o ator de `auth.uid()`.
- Base tables `groups` e `group_members` não recebem INSERT/UPDATE/DELETE de clientes. Mutação ocorre somente por RPC de propósito único. `group_follows` pode usar INSERT/DELETE sob RLS porque é relação simples; trigger confiável persiste seu evento.
- Nenhuma contagem `members_count`/`followers_count` é persistida. Agregações, quando exibidas, são calculadas no contrato autorizado e paginadas.
- Dados privados não são escondidos no React. `rejection_reason`, papéis, memberships e identidade mínima passam por contratos distintos.
- Grupos `pending`/`rejected` não entram em leitura pública. Grupo `suspended` não aceita gestão, join ou follow novo; público recebe indisponibilidade genérica, enquanto vínculos autorizados preservam histórico.
- Owner designado existe desde o pedido como `owner/pending`; grupos `approved`/`suspended` preservam exatamente um `owner/active` coerente com `groups.owner_user_id`.
- Seguir grupo nunca cria membership, pedido, papel, acesso `members_only`, participação ou autorização operacional.
- Perfis privados no roster usam somente identidade mínima do Gate 3: UUID técnico apenas para a operação, username, nome e avatar genérico. Não retornar bio, cidade pessoal, nível, distância, pace ou grafo.
- Mídia usa bucket privado `group-media`, referências canônicas e URLs assinadas de até 60 segundos. Nenhum segredo, URL assinada persistida ou upload direto de browser é permitido.
- Fixtures existem somente em pgTAP/Playwright local com rollback/cleanup. Seed e remoto não recebem grupos, membros, follows ou admins fictícios.
- Rotas personalizadas, fila admin e páginas de gestão são dinâmicas e `no-store`; nenhuma resposta de A pode ser servida a B.
- Investimento obrigatório **R$ 0**. Usar Supabase Free, Vercel Hobby elegível, PostgreSQL, Storage incluído e dependências open source; nenhum upgrade, domínio, fila ou serviço externo.
- A execução futura é contínua. Git, migrations, testes, commits, push, PR, CI, deploy e merge normais são pré-autorizados pelo prompt de execução; somente login/OAuth/2FA/CAPTCHA/UAC inevitável pode interromper.
- No Windows, reutilizar o shell atual e CLIs diretas; não abrir CMD/PowerShell adicional. Browser externo somente para autenticação ou verificação visual real.

## Frontend Quality Workflow

Para Tasks 8–14 e qualquer correção visual:

1. carregar `$ui-ux`;
2. analisar cognição do produto, jornada, hierarquia, copy, acessibilidade e estados da superfície;
3. carregar `$frontend-production-shadcn`;
4. implementar com os tokens CorreHub e componentes locais;
5. abrir a página real e verificar desktop/mobile em 360, 390, 430, 768, 1024 e 1440 px, incluindo teclado, foco, overflow, 44×44 e estados relevantes;
6. carregar `$ui-ux` novamente como quality gate;
7. corrigir todos os findings relevantes anti-template, anti-AI, mobile e acessibilidade;
8. somente então concluir testes, review e commit da Task.

**Frontend Thinking Gate:** CorreHub é uma comunidade local de corrida. Corredores querem solicitar, acompanhar, encontrar, seguir e entrar; organizadores querem cuidar de pessoas e responsabilidade; platform admins querem decidir pedidos com evidência. As superfícies são fluxo de criação, página de objeto, workbench contextual e fila operacional. O temperamento é esportivo/social, energético e simples; referências: Shopify Polaris para fluxos/estados, GitHub Primer para listas densas e Stripe para ações de alto risco. Usar português humano (`Em análise`, `Entrada pendente`, `Organizador`), nunca códigos (`pending`, `owner_user_id`, `RPC`). Evitar hero de ferramenta, card wall, tabela editável, copy autoexplicativa, badges excessivos e dashboard genérico.

**Arquitetura visual:** `/grupos/solicitar` é formulário progressivo curto; `/grupos/meus` é lista por estado com próxima ação; `/grupos/[slug]` prioriza identidade, cidade, propósito e CTA contextual; gestão usa navegação local simples e listas de pessoas; `/admin/grupos` usa fila compacta e detalhe separado. Alertas de risco usam `AlertDialog` acessível; no mobile, tabela vira lista de revisão com ação próxima ao item.

## Review Focus

1. platform admin aprovando solicitação própria ou da qual é owner;
2. member/admin promovendo a si ou outro usuário além da hierarquia;
3. gestor de um grupo administrando outro grupo;
4. dois owners ativos ou owner divergente de `groups.owner_user_id`;
5. grupo aprovado/suspenso sem owner ativo;
6. JWT antigo de conta suspensa mutando domínio;
7. blocked voltando, lendo conteúdo restrito ou interagindo;
8. pending/rejected vazando ao público, cache, metadata ou mídia;
9. `rejection_reason` vazando fora de owner/platform admin;
10. follow confundido com membership ou autorização;
11. corrida entre transferências/aceites deixando owner incoerente;
12. transferência expirada aceita ou destinatário inelegível;
13. perfil privado vazando via roster/admin de grupo;
14. fila/admin Action autorizada apenas por botão oculto;
15. `SECURITY DEFINER` genérico, `search_path` inseguro ou EXECUTE amplo;
16. cliente falsificando audit, notification, activity ou analytics;
17. cache compartilhado vazando relação, decisão ou papel;
18. mass assignment de `status`, `owner_user_id`, `role`, `approved_by`, `approved_at` ou autoria;
19. suspensão incompleta deixando join/follow/gestão ou corridas futuras ativas;
20. segredo Supabase server-side ou URL assinada entrando no browser, Git ou logs.

## Domain State Machines

### Group

| Estado atual | Operação | Próximo estado | Ator | Efeitos atômicos |
| --- | --- | --- | --- | --- |
| ausência | solicitar | `pending` | runner ativo/completo | grupo + `owner/pending` + rate limit + `group_requested` analytics |
| `pending` | aprovar | `approved` | platform_admin independente | decisão, owner `active`, audit, notification, analytics e primeiro `group_joined` |
| `pending` | rejeitar | `rejected` | platform_admin independente | motivo privado + audit + notification |
| `rejected` | editar | `rejected` | owner designado | somente campos permitidos; decisão preservada |
| `rejected` | reenviar | `pending` | owner designado ativo | limpar motivo/decisão; owner continua `pending` |
| `approved` | suspender | `suspended` | moderator ou platform_admin | timestamp, audit, pausar séries, cancelar corridas futuras e criar notification job |
| `suspended` | restaurar | `approved` | platform_admin | audit; não reabrir séries/corridas |

`pending` e `rejected` não podem ser apagados pelo cliente. Slug pode mudar apenas nesses estados; após aprovação fica imutável. `approved_by/approved_at` são preservados durante suspensão/restauração.

### Membership

| Estado atual | Operação | Próximo estado | Regra |
| --- | --- | --- | --- |
| ausência | join em `open` aprovado | `member/active` | ator ativo/completo, não bloqueado |
| ausência | join em `approval_required` aprovado | `member/pending` | pedido idempotente |
| `pending` | repetir join | `pending` | sem nova linha/efeito |
| `pending` | aprovar | `member/active` | admin/owner do mesmo grupo; notification + primeiro `group_joined` |
| `pending` | rejeitar | ausência | admin/owner; remove o pedido |
| `pending` ou `active member` | bloquear | `blocked` | admin/owner; cancela participações futuras previstas pela spec |
| `active admin` | bloquear | `blocked` | owner após rebaixamento explícito; admin não bloqueia admin |
| `active member/admin` | sair | ausência | próprio ator; owner proibido; cancelar futuras `members_only` |
| `blocked` | join/rejoin | `blocked` | sempre negado; Gate 4 não inventa `unblock` |
| `active member` | promover | `active admin` | somente owner |
| `active admin` | rebaixar | `active member` | somente owner |

Mudança de `join_policy` nunca converte pedidos existentes. Reentrada após saída pode ativar vínculo novo, mas `domain_event_receipts` impede novo `group_joined` social.

### Owner transfer

| Estado | Operação | Resultado |
| --- | --- | --- |
| ausência | owner inicia para member/admin ativo elegível | `pending`, expira em `created_at + interval '7 days'` |
| `pending`, vigente | destinatário aceita | `accepted`; troca atômica de papéis e `owner_user_id` |
| `pending`, vigente | owner cancela | `cancelled` |
| `pending`, vencida | leitura/início/aceite | efetivamente `expired`; aceite falha e uma nova transferência pode ser criada após materializar expiração |
| `pending` | destinatário/owner/papel muda ou conta suspende | aceite falha após revalidação; owner permanece |

Não substituir silenciosamente transferência pendente. O owner cancela ou aguarda expiração. Custódia por platform_admin em exclusão de conta continua compatível com a tabela, mas o fluxo de exclusão/admin completo fica no Gate 10.

## Authorization Matrix

Legenda: **sim** permitido sob estado válido; **próprio** somente recurso/vínculo do ator; **gestor** admin/owner do mesmo grupo; **não** negado; **histórico** leitura sanitizada sem poder operacional.

| Ator | read approved | read pending/rejected | edit | request | approve/reject | resubmit | join/leave | approve/reject member | block | promote/demote | initiate/accept transfer | follow/unfollow |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| visitor | sim público | não | não | login | não | não | não | não | não | não | não | login/não |
| authenticated runner ativo/completo | sim | próprio pedido | não | sim | não | próprio | join/próprio leave | não | não | não | aceitar se destinatário | sim próprio |
| pending member | sim | não | não | sim | não | não | repetir/próprio leave do pedido | não | não | não | não | sim próprio |
| active member | sim | não | não | sim | não | não | próprio leave | não | não | não | aceitar se destinatário | sim próprio |
| group admin | sim | não | approved do mesmo grupo | sim | não | não | próprio leave | membros comuns do mesmo grupo | member/pending do mesmo grupo | não | aceitar se destinatário | sim próprio |
| group owner | sim | próprio pending/rejected; approved | estados permitidos do próprio grupo | sim | não | próprio | não pode sair | membros comuns | após rebaixar admin; nunca self | sim, mesmo grupo | iniciar; não autoaceitar | sim próprio |
| moderator | sim | não | não | sim | não | não | como runner | não | não | não | aceitar se destinatário | sim; pode suspender via RPC sem UI Gate 4 |
| platform_admin independente | sim | fila completa | não por papel global | sim | sim | não | como runner | não por papel global | não por papel global | não | aceitar se destinatário; custódia fica Gate 10 | sim; pode restaurar via RPC |
| platform_admin solicitante/owner | sim | próprio + fila | como owner | sim | **não decide o próprio** | próprio | conforme papel de grupo | conforme papel de grupo | conforme papel de grupo | somente como owner | conforme papel de grupo | sim próprio |
| suspended user | público somente como visitante | não | não | não | não | não | não | não | não | não | não | não |

Leitura da fila não concede decisão própria. `moderator` pode suspender, mas não aprovar, rejeitar ou restaurar. Papel global nunca cria papel dentro do grupo.

## Visibility Matrix

| Group status / viewer | visitor | runner sem vínculo | owner designado | active member | admin/owner ativo | moderator | platform_admin |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `pending` | `not_found` | `not_found` | conteúdo + “Em análise”, sem gestão | `not_found` | não aplicável | `not_found` | revisão, sem mídia privada desnecessária |
| `approved` | campos públicos | campos públicos | público + gestão | público + roster mínimo | público + gestão/roster | público | público |
| `rejected` | `not_found` | `not_found` | conteúdo + motivo + editar/reenviar | `not_found` | não aplicável | `not_found` | revisão/histórico da decisão |
| `suspended` | indisponível genérico, sem conteúdo | indisponível genérico | histórico sanitizado, sem gestão | histórico sanitizado | histórico/roster, sem gestão | contexto de suspensão | contexto e restauração |

`rejection_reason`, auditoria, transfers e pedidos de membership nunca entram na projeção pública. Mídia de pending/rejected é legível somente pelo owner e pelo reviewer estritamente necessário; mídia de suspended não é emitida ao público.

## Role Matrix

| Operação dentro do grupo | member | admin | owner |
| --- | --- | --- | --- |
| editar grupo aprovado | não | sim | sim |
| ver roster ativo mínimo | sim | sim | sim |
| ver pending/blocked | não | sim | sim |
| aprovar/rejeitar member pending | não | sim | sim |
| bloquear member | não | sim | sim |
| gerir admin | não | não | promover/rebaixar |
| alterar owner | não | não | iniciar transferência aceita pelo destinatário |
| sair | sim | sim | não |
| criar corridas | Gate 5 | Gate 5 | Gate 5 |

Admin não atua sobre outro admin nem owner. Owner não pode ser bloqueado, rebaixado sem transferência ou removido. Membership nunca amplia dados pessoais além da identidade mínima contextual.

## Transaction Boundaries

| Operação | Locks/revalidações | Escritas no mesmo commit | Idempotência/conflito |
| --- | --- | --- | --- |
| request | conta/profile/cidade; rate bucket; slug unique | group + owner/pending + analytics | 5/dia; slug `23505` vira conflict |
| approve | `groups FOR UPDATE`; admin atual; independência; owner row | approved fields + owner active + audit + notification + analytics + receipt/activity | segundo decisor recebe state_changed; uma decisão |
| reject | `groups FOR UPDATE`; admin atual; independência | rejected + motivo + audit + notification | retry não duplica; nova rejeição só após resubmit |
| resubmit | group + owner row lock | pending + limpar motivo/decisão | rejected apenas |
| suspend | group lock; moderator/admin atual | suspended + pause series + cancel future runs + audit + notification job | segundo suspend sem efeitos extras |
| restore | group lock; platform_admin | approved + audit | não reabre corrida/série |
| join | group + membership row/key lock | membership + receipt/activity se ativa | repetição retorna estado atual; blocked nega |
| membership decision/block/leave | group/member locks; papel atual | membership + notification/activity/cancelamentos futuros aplicáveis | estado revalidado; sem dupla decisão |
| promote/demote | group + actor/target rows | um papel | estado já desejado é sucesso controlado; hierarquia rígida |
| initiate transfer | group + owner + target + pending transfer | expirar vencida + nova pending | uma pending por grupo |
| accept transfer | transfer + group + dois memberships | accepted + troca dos dois roles + owner_user_id | exatamente um aceite; constraint diferida confirma owner |
| follow | PK + policy | group_follow + analytics via trigger | `23505` tratado como following=true |
| media finalize | upload row + group + permissão atual | objeto validado + canonical path + `ready` | hash/path alvo; falha remove órfão |

## Routes

| Rota | Acesso | Responsabilidade |
| --- | --- | --- |
| `/grupos/solicitar` | active + complete | formulário de solicitação; `solicitar` é slug reservado |
| `/grupos/meus` | active + complete | pedidos e memberships agrupados por próxima ação; `meus` reservado |
| `/grupos/[slug]` | público condicionado ao estado | página canônica; CTA seguir/entrar; owner vê pending/rejected pelo mesmo slug |
| `/grupos/[slug]/configuracoes` | owner pending/rejected; admin/owner approved | editar campos permitidos e mídia; suspended é read-only |
| `/grupos/[slug]/membros` | membro/gestor conforme contrato | roster mínimo, requests e controles hierárquicos |
| `/grupos/[slug]/transferencia` | owner/destinatário | iniciar, cancelar e aceitar transferência |
| `/admin/grupos` | platform_admin | fila mínima pending, filtros de estado estritos e vazio útil |
| `/admin/grupos/[id]` | platform_admin | revisar conteúdo, decisão, motivo e estado final |
| `/api/group-media` | sessão + autorização do alvo | upload/delete/read assinado; nunca recebe caminho livre |

Não criar `/groups/search`, descoberta ampla, rotas de corridas, feed ou central de notificações. Metadata pública existe somente para `approved`; demais estados recebem `noindex` e conteúdo sanitizado.

## File Map

| Caminho | Operação | Responsabilidade |
| --- | --- | --- |
| `AGENTS.md` | já criado no planejamento | governança permanente de frontend |
| `supabase/migrations/*_gate4_group_requests_visibility.sql` | criar | request, slugs reservados, leitura sanitizada, my groups, rate limit |
| `supabase/migrations/*_gate4_group_review.sql` | criar | approve/reject/resubmit, suspend/restore, audit/notif/analytics |
| `supabase/migrations/*_gate4_memberships_hierarchy.sql` | criar | join, decisões, block, leave, promote/demote, roster mínimo |
| `supabase/migrations/*_gate4_owner_transfers.sql` | criar | iniciar/cancelar/expirar/aceitar transferências |
| `supabase/migrations/*_gate4_group_follows_events.sql` | criar | RLS follows, analytics e independência de membership |
| `supabase/migrations/*_gate4_group_media.sql` | criar | bucket privado, autorização/finalização de mídia, negação direta |
| `supabase/tests/database/130_group_requests_visibility_test.sql` | criar | request/visibilidade/slug/rate |
| `supabase/tests/database/140_group_review_test.sql` | criar | decisão independente, audit, notification, suspensão |
| `supabase/tests/database/150_group_memberships_hierarchy_test.sql` | criar | lifecycle, hierarchy, privacy e efeitos futuros mínimos |
| `supabase/tests/database/160_group_owner_transfers_test.sql` | criar | aceite, expiração, revalidação e owner único |
| `supabase/tests/database/170_group_follows_events_test.sql` | criar | follow, membership separation e eventos |
| `supabase/tests/database/180_group_concurrency_test.sql` | criar | sessões `dblink` concorrentes reais |
| `supabase/tests/database/190_group_media_test.sql` | criar | bucket, autorização e grants Storage |
| `src/types/database.ts` | regenerar | tipos de migrations/RPCs Gate 4 |
| `src/lib/groups/{types,cursor,queries,errors}.ts` | criar | contratos, paginação, DAL server-only e erros seguros |
| `src/lib/validations/group.ts` | criar | request/edit/review/membership/transfer schemas e labels PT-BR |
| `src/lib/groups/actions.ts` | criar | Actions finas para RPCs e revalidation |
| `src/lib/supabase/admin.ts` | criar | cliente secret server-only exclusivo de mídia |
| `src/lib/media/group-media.ts` | criar | validação Sharp, caminhos fixos e signed URLs |
| `src/app/api/group-media/route.ts` | criar | transporte autenticado de mídia com `no-store` |
| `src/components/ui/{button,input,textarea,label,alert-dialog}.tsx` | criar se ausentes | primitives shadcn adaptadas aos tokens CorreHub |
| `src/components/groups/*` | criar | forms, state banner, group header, membership/follow e roster |
| `src/app/grupos/**` | criar | rotas de solicitante, público e gestão |
| `src/app/admin/grupos/**` | criar | fila/detalhe mínimos de aprovação |
| `tests/e2e/groups.spec.ts` | criar | jornadas Gate 4 locais |
| `tests/e2e/support/local-auth.ts` | modificar | fixtures locais de roles/grupos e cleanup |
| `scripts/run-auth-e2e.mjs` e `scripts/auth-e2e-env.mjs` | modificar | fornecer secret local somente ao processo Next de teste de mídia |
| `supabase/config.toml`, `package.json`, `package-lock.json`, `.env.example` | modificar | Storage local, dependências exatas e `SUPABASE_SECRET_KEY=` vazio |
| `.github/workflows/ci.yml`, `README.md` | modificar se necessário | Gate 4 no job local único e documentação operacional factual |

## Database Changes

### Migration 1 — requests and visibility

- Criar helper privado `current_account_is_group_ready()` (active + onboarding), `group_slug_is_reserved(text)` para `solicitar`/`meus` e consumo atômico do bucket `group_request` com limite 5 por dia.
- Criar `public.request_group(name,slug,description,city_id,type,join_policy)` como `SECURITY DEFINER`: normalizar/validar, exigir cidade ativa, inserir `groups pending`, `group_members owner/pending` e `private.analytics_events(group_requested)`.
- Criar `public.update_group_profile(group_id uuid, name text, slug text, description text, city_id uuid, group_type text, join_policy text)` e `public.resubmit_group(group_id uuid)` com allowlist de campos; slug mutável apenas pending/rejected, status/owner/decisão nunca em payload.
- Criar `public.get_group_by_slug(target_slug text)`, `public.list_my_groups(after_updated_at timestamptz, after_id uuid, page_size integer)` e `public.get_current_group_relation(target_group_id uuid)` com shapes sanitizados. Conceder SELECT somente nas colunas públicas necessárias e policies de leitura por status/ator; nenhuma coluna `rejection_reason` em grant comum.

### Migration 2 — review and moderation state

- Criar `public.list_group_review_queue(after_created_at timestamptz, after_id uuid, page_size integer)` e `public.get_group_review(target_group_id uuid)` restritas a platform_admin.
- Criar `public.approve_group_request(uuid)`, `reject_group_request(uuid,text)`, `suspend_group(uuid,text)` e `restore_group(uuid,text)`; todas `SECURITY DEFINER`, `search_path=''`, owner `postgres`, revoke PUBLIC/anon e grant authenticated.
- Aprovação bloqueia group e owner row, proíbe `created_by/owner_user_id=auth.uid()`, ativa owner, insere audit, notification dedupe, analytics `group_approved`, receipt/activity `group_joined` e deixa trigger diferido provar consistência.
- Rejeição mantém owner/pending e usa ID do audit como parte da dedupe notification. Motivo 3–1000, privado.
- Suspensão aceita moderator/platform_admin, pausa `run_series status='active'`, cancela `runs scheduled` futuras preenchendo `cancelled_at/reason`, cria audit e um `notification_job`; restauração é platform_admin e não reabre nada.

### Migration 3 — membership and hierarchy

- Criar predicates privados `current_user_group_role`, `is_active_group_manager`, `group_member_is_active` sem aceitar ator personificável.
- Criar RPCs `join_group`, `approve_group_member`, `reject_group_member_request`, `block_group_member`, `leave_group`, `promote_group_admin`, `demote_group_admin`.
- Criar `list_group_members(group_id,direction,cursor,page_size)` com modos fixos `active`, `pending`, `blocked`; retorno combina membership e identidade mínima, nunca profile completo privado.
- Primeira ativação insere `domain_event_receipts(group_joined, group:user)`, `activity_events group_joined` e notification quando request foi aprovado. Saída/bloqueio aplicam os cancelamentos futuros definidos pela spec sem expor UI de corridas.

### Migration 4 — ownership transfer

- Reusar `private.group_owner_transfers`; não criar tabela duplicada.
- Criar `initiate_group_owner_transfer(group_id,to_user_id)`, `cancel_group_owner_transfer(transfer_id)`, `get_group_owner_transfer(group_id)` e `accept_group_owner_transfer(transfer_id)`.
- `expires_at` é exatamente `created_at + interval '7 days'`. Leitura e qualquer nova tentativa materializam pendências vencidas como `expired`.
- Aceite bloqueia transfer/group/memberships; exige destinatário atual, conta ativa, target active member/admin, from ainda owner, grupo approved e prazo vigente; troca roles, atualiza owner e aceita numa transação.

### Migration 5 — group follows and domain events

- Grants `SELECT/INSERT(user_id,group_id)/DELETE` para authenticated; policies: SELECT próprio, INSERT `user_id=auth.uid()` + group approved + caller group-ready, DELETE próprio mesmo se grupo deixou de approved.
- Trigger privado após INSERT persiste `private.analytics_events(event_name='group_followed')` com chave estável e `ON CONFLICT DO NOTHING`; nenhum activity feed é criado por follow.
- Nenhuma policy consulta `group_members` para conceder follow e nenhuma policy de membership consulta `group_follows`.

### Migration 6 — private group media

- Inserir bucket `group-media` com `public=false`, limite 600 KB e MIME `image/webp`. Não criar policy de escrita/leitura direta para anon/authenticated.
- Criar `authorize_group_media_upload(group_id,kind,hash,size)`, `finalize_group_media_upload(upload_id)` e `authorize_group_media_read(group_id,kind)`; `kind` apenas `avatar|cover`, caminho calculado `{group_id}/{kind}.webp`.
- Pending/rejected: owner; approved: admin/owner; suspended: sem escrita. Leitura: público approved, owner/reviewer pending/rejected, membros/gestores suspended conforme histórico.
- `avatar_url/cover_url` armazenam caminho canônico somente após `media_uploads.status='ready'`. Falha/revogação remove objeto e marca failed; signed URL não é persistida.

Todos os definers usam `SET search_path=''`, referências qualificadas, `auth.uid()` interno, role/account atual, revoke `PUBLIC,anon`, grant mínimo e testes de abuso. Índices existentes cobrem cidade/status, memberships nos dois sentidos, follows e transfer status/expiry; qualquer índice novo exige query real + `EXPLAIN (ANALYZE, BUFFERS)`, com candidato apenas para fila `groups(status,created_at,id)` se o plano provar scan inadequado.

## Interfaces Produced

```ts
type GroupStatus = "pending" | "approved" | "rejected" | "suspended";
type GroupType = "community" | "professional";
type JoinPolicy = "open" | "approval_required";
type GroupRole = "member" | "admin" | "owner";
type MembershipStatus = "pending" | "active" | "blocked";
type GroupView = "public" | "requester" | "member" | "manager" | "reviewer" | "suspended";
type GroupCursor = { name: string; id: string };

type GroupActionResult<T = undefined> =
  | { ok: true; data: T }
  | { ok: false; code: "unauthenticated" | "forbidden" | "not_found" | "validation_error" | "conflict" | "rate_limited" | "state_changed" | "expired" | "temporary_error"; message: string; fieldErrors?: Record<string,string> };
```

DAL: `getGroupBySlug`, `listMyGroups`, `listGroupMembers`, `listGroupReviewQueue`, `getGroupReview`, `getGroupTransfer`. Actions: request/edit/resubmit/approve/reject/suspend/restore, join/approveMember/rejectMember/block/leave, promote/demote, initiate/cancel/accept transfer, follow/unfollow e media. Nenhuma Action aceita ator, status final, role final ou caminho Storage.

## Interfaces Consumed

- `getCurrentAccountState()` e clientes SSR Gate 2 para sessão; RLS/RPC decide autorização final.
- `public.profiles`, `private.account_controls`, `private.platform_roles` e helpers de conta atuais.
- Projeção mínima Gate 3 como contrato de identidade contextual; não duplicar lógica de privacidade em componentes.
- `cities`/`app_settings` para cidades ativas e launch city; nenhum nome geográfico fixo.
- `groups`, `group_members`, `group_follows`, `group_owner_transfers`, `activity_events`, `notifications`, `admin_audit_logs`, `analytics_events`, `notification_jobs`, `media_uploads`, `rate_limit_buckets`, `domain_event_receipts`.
- `run_series`, `runs`, `run_participations` somente para efeitos obrigatórios de suspensão/saída/bloqueio; nenhuma criação/edição de corrida é exposta.
- `sanitizeInternalReturnTo` para login a partir de join/follow; `revalidatePath` somente após sucesso confirmado.

## Test Strategy

- **pgTAP:** sete arquivos Gate 4, atores anon/runner/pending/member/admin/owner/cross-group/moderator/platform_admin/self-reviewer/suspended. Cobrir todos os 50 cenários mínimos do brief, grants, RLS, função owner/search_path e ausência de contadores.
- **Concorrência real:** `180_group_concurrency_test.sql` usa `dblink` em sessões independentes para approval, member decision/block, owner acceptance/promotion e duplicate follow. Duas chamadas sequenciais não contam como prova.
- **Vitest:** schemas, slug/reservas, cursores, mapping de DAL, error mapping, roles/status presentation, Action payload/mass assignment, media validation.
- **Testing Library:** request, pending, rejected/resubmit, public/suspended, join states, follow, roster, hierarchy, transfer e admin review; accessible names, disabled/loading, erro recuperável e `AlertDialog`.
- **Playwright local:** request → pending → independent approval; self-approval denial; open join; approval-required + gestor; hierarchy; transfer accepted; follow≠membership; block; suspended JWT. Fixtures locais são apagadas.
- **Visual:** navegador real em 360/390/430/768/1024/1440, screenshots de estados essenciais e revisão `$ui-ux` final. Sem tabela horizontal no mobile.
- **Storage:** assinatura real, dimensão/tamanho/MIME, path tampering, direct API denial, revogação entre authorize/finalize, signed URL expirada/privada e secret ausente do bundle.
- **Regressão:** todos os 200 Vitest/Testing Library, 388 pgTAP e 14 Playwright existentes continuam; números finais serão registrados pela execução, sem fixá-los artificialmente.
- **CI:** job `quality` permanece; job `database` usa uma stack local, inclui Storage, reset → pgTAP → lint/types → Chromium Auth+Gate3+Gate4 → stop. Nenhum Google real, Supabase remoto ou secret de produção.

## Tasks

### Task 1: Abrir branch, ledger e preservar baseline

**Objective:** iniciar Gate 4 isolado e provar que nenhuma migration antiga mudou.

**Files:** adicionar este plano e `AGENTS.md`; criar apenas ledger ignorado.

**Preconditions:** `main`/`origin/main=757e1b6`, worktree limpo, dez migrations.

- [ ] Carregar `superpowers:executing-plans` e `superpowers:using-git-worktrees`; criar `.worktrees/gate-4-groups` na branch `feature/gate-4-groups`.
- [ ] Registrar SHA-256 das dez migrations, versions reais do package e baseline Git no ledger.
- [ ] Rodar `npm ci`, `npm run lint`, `npm run typecheck`, `npm run test`, `npm run build`; confirmar baseline sem alterar banco.
- [ ] Revisar diff: somente plano/AGENTS; `git diff --check`; nenhum segredo.
- [ ] Commit: `docs: establish Gate 4 execution and frontend governance`.

**Initial command:** `npm ci && npm run lint && npm run typecheck && npm run test && npm run build`.

**Expected:** baseline Gate 3 verde; qualquer falha bloqueia a branch antes do primeiro SQL.

**Completion evidence:** branch isolada parte do Gate 3 verde, hashes registrados e governança visual versionada.

### Task 2: Implementar request e leitura sanitizada de grupos

**Objective:** criar grupo pending e owner/pending atomicamente, sem exposição pública.

**Files:** migration requests/visibility; `130_group_requests_visibility_test.sql`.

**Preconditions:** hashes Gate 0–3 preservados; stack local ativa.

- [ ] Escrever RED para request, owner/pending, cidade ativa, tipos/policy, slug normalizado/reservado/duplicado, rate 5/dia e payload sem ator/status.
- [ ] Escrever RED de leitura: anon não vê pending/rejected; owner vê próprio; platform_admin vê para revisão; rejection reason não aparece na projeção comum.
- [ ] Executar arquivo pgTAP específico e confirmar falhas por funções/policies ausentes.
- [ ] Criar migration 1 com helpers, grants/policies, request/update/resubmit e read models descritos.
- [ ] Executar GREEN específico, `npm run db:lint` e testes históricos `20`, `40`, `90`.
- [ ] Revisar definer/search_path/grants, `EXPLAIN` da fila inicial e nenhum acesso Gate 5.
- [ ] Commit: `feat: add secure group requests and visibility`.

**RED command:** `npm exec --no -- supabase test db --local supabase/tests/database/130_group_requests_visibility_test.sql`.

**Expected RED:** funções/policies ausentes; o failure deve citar o primeiro contrato Gate 4, não erro de fixture.

**GREEN command:** repetir o arquivo, depois `npm exec --no -- supabase test db --local supabase/tests/database/20_group_run_schema_test.sql` e `npm run db:lint`.

**Expected:** pedido nunca fica sem owner designado e só atores autorizados enxergam estados não públicos.

### Task 3: Implementar review, decisão e suspensão transacionais

**Objective:** permitir decisão independente e estados administrativos com efeitos atômicos.

**Files:** migration review; `140_group_review_test.sql`.

**Preconditions:** Task 2 verde.

- [ ] Escrever RED para user/moderator negados, platform_admin permitido, solicitante admin negado e reviewer de outro grupo permitido.
- [ ] Escrever RED de approve/reject: locks, owner active, exatamente um owner, audit append-only, notification dedupe, analytics e rollback forçado.
- [ ] Escrever RED de suspend/restore: papéis, séries pausadas, runs futuras canceladas, histórico preservado e restauração sem reabrir.
- [ ] Implementar migration 2 e respostas `state_changed` sem SQL bruto.
- [ ] Executar GREEN específico, regressão de owner constraints e DB lint.
- [ ] Inspecionar metadata de audit: somente ator, ação, alvo, motivo/estado mínimo; sem email/conteúdo integral.
- [ ] Commit: `feat: add independent atomic group review`.

**RED command:** `npm exec --no -- supabase test db --local supabase/tests/database/140_group_review_test.sql`.

**Expected RED:** review RPCs não existem; fixtures pending da Task 2 funcionam.

**GREEN command:** repetir `140`, depois `20`, `40`, `90` e `npm run db:lint`.

**Expected:** decisão concorrente não divide efeitos e autoaprovação é impossível no banco.

### Task 4: Implementar membership lifecycle e hierarquia

**Objective:** entregar join, pedidos, roster, block, leave e papéis sem escalada.

**Files:** migration memberships/hierarchy; `150_group_memberships_hierarchy_test.sql`.

**Preconditions:** grupo approved produzido pela RPC real.

- [ ] Escrever RED para open/approval_required, repetição, reject remove pending, block preserva row e mudança de policy não autoaprova.
- [ ] Escrever RED de hierarquia: admin gere member comum, não admin/owner; owner promove/rebaixa; cross-group negado; owner não sai/não bloqueia.
- [ ] Escrever RED de conta/group suspended e de cancelamentos futuros obrigatórios sem liberar criação de corrida.
- [ ] Escrever RED do roster: própria relação, active member mínimo, manager pending/blocked e nenhum dado privado completo.
- [ ] Implementar migration 3 com locks por group/member e receipts/notifications/activity.
- [ ] Executar GREEN, DB lint e regressão Gate 3 de profile privacy.
- [ ] Commit: `feat: enforce group membership hierarchy`.

**RED command:** `npm exec --no -- supabase test db --local supabase/tests/database/150_group_memberships_hierarchy_test.sql`.

**Expected RED:** join/management RPCs ausentes; leitura sanitizada anterior continua verde.

**GREEN command:** repetir `150`, depois `110_profile_visibility_test.sql`, `120_user_follows_test.sql` e `npm run db:lint`.

**Expected:** lifecycle é idempotente, hierarquia é de banco e roster não enfraquece privacidade.

### Task 5: Implementar ownership transfer com aceite

**Objective:** trocar responsabilidade sem instante persistido com zero/dois owners.

**Files:** migration transfers; `160_group_owner_transfers_test.sql`.

**Preconditions:** exactly-one-owner e hierarchy verdes.

- [ ] Escrever RED para target ausente/pending/blocked/suspended, self, grupo não approved e caller não owner.
- [ ] Escrever RED para prazo exato de sete dias, cancelamento owner, expiração e uma pending por grupo.
- [ ] Escrever RED para aceite apenas pelo target e revalidação de owner, roles, conta e prazo.
- [ ] Escrever RED que target member/admin troca papel com owner anterior e trigger diferido confirma coerência.
- [ ] Implementar migration 4 com ordem de updates compatível com índice único e locks.
- [ ] Executar GREEN, owner constraints e DB lint.
- [ ] Commit: `feat: add accepted group ownership transfers`.

**RED command:** `npm exec --no -- supabase test db --local supabase/tests/database/160_group_owner_transfers_test.sql`.

**Expected RED:** transfer RPCs ausentes; a tabela privada existente permanece inacessível ao cliente.

**GREEN command:** repetir `160`, depois `20_group_run_schema_test.sql`, `150_group_memberships_hierarchy_test.sql` e `npm run db:lint`.

**Expected:** transferência é explícita, expirável, concorrente e atômica.

### Task 6: Autorizar group follows sem confundir membership

**Objective:** seguir/deixar de seguir apenas grupos approved, preservando separação de conceitos.

**Files:** migration follows/events; `170_group_follows_events_test.sql`; atualizar `90_private_surface_test.sql` apenas para novas policies esperadas.

**Preconditions:** helpers de conta/grupo verdes.

- [ ] Escrever RED para anon, suspended, pending/rejected/suspended group, duplicate e ator arbitrário.
- [ ] Escrever RED: follow não cria member/request/acesso; membership não cria follow; unfollow não remove membership; leave não remove follow.
- [ ] Escrever RED do evento `group_followed` deduplicado e impossibilidade de cliente inserir analytics.
- [ ] Implementar migration 5, grants/policies e trigger estreito.
- [ ] Executar GREEN, private surface e DB lint.
- [ ] Commit: `feat: authorize independent group follows`.

**RED command:** `npm exec --no -- supabase test db --local supabase/tests/database/170_group_follows_events_test.sql`.

**Expected RED:** `group_follows` continua sem grants/policies; assertions de independência falham pelo contrato ainda fechado.

**GREEN command:** repetir `170`, depois `90_private_surface_test.sql`, `120_user_follows_test.sql` e `npm run db:lint`.

**Expected:** follow é relação própria, reversível e sem autoridade de grupo.

### Task 7: Provar concorrência e segurança adversarial do banco

**Objective:** validar linearização das operações críticas em sessões reais.

**Files:** `180_group_concurrency_test.sql`; ajustes SQL somente se defeito reproduzido.

**Preconditions:** migrations 1–5 verdes.

- [ ] Criar RED com `dblink` para duas aprovações, approve-vs-block, dois accept transfers, promotion concorrente e duplicate follow.
- [ ] Exigir uma única decisão/audit/notification, final blocked quando block conclui, um owner e uma follow row.
- [ ] Testar mass assignment direto, grants de colunas, EXECUTE PUBLIC/anon, stale JWT e cross-group em todas RPCs.
- [ ] Corrigir apenas causa raiz reproduzida; nova migration corretiva se migration anterior já tiver sido aplicada fora da branch local.
- [ ] Rodar todos pgTAP, reset limpo e DB lint.
- [ ] Commit: `test: verify concurrent group transitions`.

**RED command:** `npm exec --no -- supabase test db --local supabase/tests/database/180_group_concurrency_test.sql`.

**Expected RED:** ao menos um interleaving viola o resultado declarado ou falta o harness `dblink`; não aceitar teste sequencial como RED.

**GREEN command:** repetir `180`, depois `npm run db:reset && npm run db:test && npm run db:lint`.

**Expected:** invariantes sobrevivem a interleavings reais, não apenas chamadas sequenciais.

### Task 8: Regenerar types e criar contratos server-side

**Objective:** disponibilizar DAL, schemas, Actions e primitives de UI sem duplicar autorização.

**Files:** generated types; `src/lib/groups/*`, validation/actions/tests; package files; components UI estritamente necessários.

**Preconditions:** schema Gate 4 de domínio estável.

- [ ] Carregar `$ui-ux`, registrar arquitetura das jornadas, carregar `$frontend-production-shadcn` e auditar componentes/dependências existentes.
- [ ] Escrever RED para schemas de slug/textos/enums/motivo/cursor/UUID e rejeição de campos extras.
- [ ] Escrever RED do DAL para shapes public/requester/member/manager/reviewer e ausência de motivo/profile privado indevido.
- [ ] Escrever RED das Actions para sessão, suspended, erro conhecido, state_changed, mass assignment e revalidation pós-sucesso.
- [ ] Instalar com `--save-exact` somente dependências justificadas ausentes; inspecionar scripts nativos antes de permitir `sharp`.
- [ ] Implementar DAL `server-only`, Actions finas, error mapper e primitives shadcn adaptadas aos tokens.
- [ ] Gerar types duas vezes; segunda execução não produz diff adicional. Rodar unit tests, lint e typecheck.
- [ ] Revisar bundle: nenhum secret/admin client em Client Component.
- [ ] Commit: `feat: add typed group domain services`.

**RED command:** `npm run test -- src/lib/validations/group.test.ts src/lib/groups/cursor.test.ts src/lib/groups/queries.test.ts src/lib/groups/actions.test.ts`.

**Expected RED:** módulos/contratos novos ausentes; testes existentes continuam carregando.

**GREEN command:** repetir o subset, `npm run db:types` duas vezes, `npm run lint` e `npm run typecheck`.

**Expected:** UI recebe modelos sanitizados e nenhum contrato TypeScript concede autoridade.

### Task 9: Implementar pipeline privado de group media

**Objective:** upload e leitura de avatar/capa revogáveis sem bucket público.

**Files:** migration media/test; admin client; media module; route; config/env/scripts/testes.

**Preconditions:** secret key local disponível somente no processo server; Storage API local habilitada.

- [ ] Escrever RED pgTAP para bucket privado, ausência de policy/grant direto, autorização por estado/papel e canonical path.
- [ ] Escrever RED unit/route para JPEG/PNG/WebP válidos, SVG/GIF/assinatura falsa, dimensões, tamanho, path tampering, missing secret e revogação antes de finalize.
- [ ] Implementar migration 6 e cliente admin separado `server-only` com `persistSession/autoRefreshToken/detectSessionInUrl=false`.
- [ ] Implementar compressão client WebP; servidor decodifica, remove metadata e reencoda via Sharp: avatar ≤250 KB/512², cover ≤600 KB/lado 1600, body ≤1 MB.
- [ ] Implementar signed URLs ≤60 s e `Cache-Control: private, no-store` para contexto restrito; nenhuma URL assinada em DB/log.
- [ ] Testar delete/substituição, órfão/falha e direct Storage API denial.
- [ ] Rodar Storage local, testes afetados, secret/bundle scan, lint, typecheck e build.
- [ ] Commit: `feat: secure private group media`.

**RED command:** `npm run test -- src/lib/media/group-media.test.ts src/app/api/group-media/route.test.ts && npm exec --no -- supabase test db --local supabase/tests/database/190_group_media_test.sql`.

**Expected RED:** bucket/RPC/route ausentes; nenhum fallback deve aceitar bytes sem validação.

**GREEN command:** repetir ambos, testar bypass direto contra Storage local e rodar `npm run lint && npm run typecheck && npm run build`.

**Expected:** somente bytes validados chegam ao caminho calculado e acesso acompanha estado/papel atual.

### Task 10: Construir solicitação e acompanhamento do organizador

**Objective:** runner solicita e acompanha pending/rejected sem aprender estados internos.

**Files:** `/grupos/solicitar`, `/grupos/meus`, state components e testes.

**Preconditions:** Tasks 8–9 verdes.

- [ ] Carregar `$ui-ux`; produzir jornada e estados; carregar `$frontend-production-shadcn`.
- [ ] Escrever RED de formulário: nome, slug assistido/editável, descrição, cidade ativa, tipo, política, erros ligados aos campos e submit único.
- [ ] Escrever RED de meus grupos: empty útil, Em análise, Rejeitado com motivo privado/ação, Aprovado e Suspenso.
- [ ] Implementar sem hero/card wall: formulário enxuto e lista orientada à próxima ação; `professional` sem copy de cobrança.
- [ ] Implementar edit/resubmit no mesmo grupo e mídia após ID existente, sem duplicar solicitação.
- [ ] Verificar navegador real em seis larguras, teclado/foco/overflow/loading/error/session expired.
- [ ] Recarregar `$ui-ux`, corrigir findings e rodar component tests/lint/typecheck/build.
- [ ] Commit: `feat: add organizer group request journey`.

**RED command:** `npm run test -- src/app/grupos/solicitar src/app/grupos/meus src/components/groups/group-request-form.test.tsx`.

**Expected RED:** rotas/componentes ausentes; testes descrevem nomes acessíveis e jornada, não markup interno.

**GREEN command:** repetir o subset e rodar `npm run lint && npm run typecheck && npm run build` após visual QA.

**Expected:** solicitante entende análise, decisão e recuperação sem ver códigos técnicos.

### Task 11: Construir página pública, join e follow

**Objective:** apresentar approved com CTAs corretos e estados sem confundir follow/membership.

**Files:** `/grupos/[slug]`, components join/follow/header/status e testes.

**Preconditions:** leitura pública e Actions verdes.

- [ ] Executar workflow completo de frontend skills.
- [ ] Escrever RED para approved público, pending/rejected owner, suspended genérico e inexistente.
- [ ] Escrever RED para visitor→login returnTo, open join active, approval pending, blocked, leave e state_changed.
- [ ] Escrever RED para follow/following independente; copy nunca sugere acesso de membro.
- [ ] Implementar metadata somente approved e `noindex` nos estados restritos; rota `force-dynamic` por estado personalizado.
- [ ] Verificar seis viewports, touch 44×44, reload e nenhum dado Gate 5.
- [ ] Rodar tests/lint/typecheck/build e revisão `$ui-ux` final.
- [ ] Commit: `feat: add group page join and follow flows`.

**RED command:** `npm run test -- src/app/grupos/[slug] src/components/groups/group-membership-action.test.tsx src/components/groups/group-follow-button.test.tsx`.

**Expected RED:** página/CTAs ausentes; approved/pending/rejected/suspended são casos distintos.

**GREEN command:** repetir o subset e rodar `npm run lint && npm run typecheck && npm run build` após visual QA.

**Expected:** grupo público é útil, enquanto status e relações permanecem inequívocos.

### Task 12: Construir gestão de membros e ownership

**Objective:** oferecer roster e ações proporcionais à hierarquia.

**Files:** configurações, membros, transferência, components/dialogs e testes.

**Preconditions:** hierarchy/transfer DB verdes.

- [ ] Executar workflow completo de frontend skills.
- [ ] Escrever RED de roster active/pending/blocked, identidade privada mínima e controles por member/admin/owner.
- [ ] Escrever RED para approve/reject/block, promote/demote, leave e concorrência alterada; nenhuma Action aceita actor role.
- [ ] Escrever RED de transfer: target elegível, resumo de 7 dias, cancelamento, aceite explícito e expired.
- [ ] Implementar navegação local por grupo; mobile usa listas, não tabela comprimida.
- [ ] Usar AlertDialog para block/demote/transfer/leave de admin; foco retorna ao acionador e estado não depende de cor.
- [ ] Integrar edição/mídia por estados permitidos; suspended é histórico read-only.
- [ ] Verificar visualmente seis larguras e todos os estados; revisão `$ui-ux` final.
- [ ] Rodar tests/lint/typecheck/build.
- [ ] Commit: `feat: add group member and ownership management`.

**RED command:** `npm run test -- src/app/grupos/[slug]/configuracoes src/app/grupos/[slug]/membros src/app/grupos/[slug]/transferencia src/components/groups/group-member-list.test.tsx`.

**Expected RED:** superfícies e controles por papel ausentes; private roster assertion permanece estrita.

**GREEN command:** repetir o subset e rodar `npm run lint && npm run typecheck && npm run build` após visual QA.

**Expected:** cada papel vê apenas ações reais e operações perigosas mostram impacto antes do commit.

### Task 13: Construir interface administrativa mínima de aprovação

**Objective:** platform_admin revisa e decide pedidos; moderator/solicitante não burla autorização.

**Files:** `/admin/grupos`, `/admin/grupos/[id]`, components/actions/tests.

**Preconditions:** review RPC verde e conta platform_admin fixture disponível localmente.

- [ ] Executar workflow completo de frontend skills com referência Enterprise Ops, sem dashboard amplo.
- [ ] Escrever RED para platform_admin, moderator, runner, self-reviewer e sessão expirada.
- [ ] Escrever RED de fila loading/empty/error e detalhe com dados necessários, sem email/profile privado/reason fora de contexto.
- [ ] Escrever RED de approve e reject reason 3–1000, dupla submissão e state_changed.
- [ ] Implementar lista compacta + detalhe; desktop pode usar linhas, mobile usa blocos de decisão; sem analytics/denúncias/roles UI.
- [ ] Usar AlertDialog em rejeição, exibir consequência e estado final auditável.
- [ ] Verificar browser/seis larguras/teclado/foco; revisar com `$ui-ux` e corrigir findings.
- [ ] Rodar tests/lint/typecheck/build.
- [ ] Commit: `feat: add minimal group approval workspace`.

**RED command:** `npm run test -- src/app/admin/grupos src/components/groups/group-review.test.tsx`.

**Expected RED:** queue/detail/decision UI ausentes; runner/moderator fixtures devem continuar negadas.

**GREEN command:** repetir o subset e rodar `npm run lint && npm run typecheck && npm run build` após visual QA.

**Expected:** fila mínima cumpre Gate 4 e autorização continua independente da UI.

### Task 14: Cobrir jornadas E2E, visual e CI

**Objective:** provar integração real de Auth, RLS, RPC, Storage e UI sem produção falsa.

**Files:** `groups.spec.ts`, fixture/scripts, CI e README.

**Preconditions:** todas as Tasks funcionais verdes.

- [ ] Estender harness local-only para roles, grupos e memberships; recusar URL não local e limpar todas identities/objects.
- [ ] E2E request/pending/independent approval e self-approval denial.
- [ ] E2E open join, approval_required + manager approval, hierarchy e block/rejoin denial.
- [ ] E2E owner promote/demote e transfer accepted/expired.
- [ ] E2E follow≠membership, reload/unfollow e suspended JWT denial.
- [ ] E2E group media válido/inválido e direct bypass denied, sem secret no browser.
- [ ] Capturar screenshots determinísticas desktop/mobile de request, group, members e admin com empty/error/risk dialog.
- [ ] Rodar `npm run test:auth` duas vezes, toda pgTAP e confirmar zero fixtures/objetos residuais.
- [ ] Ajustar CI no job database único e README sem copiar spec nem registrar segredo.
- [ ] Executar review `$ui-ux` final das screenshots e corrigir findings antes do commit.
- [ ] Commit: `test: cover group domain journeys`.

**RED command:** `npm run test:auth` após adicionar `tests/e2e/groups.spec.ts` e antes de completar fixtures/rotas Gate 4.

**Expected RED:** novas jornadas falham antes das fixtures/rotas finais; não aceitar bypass ou mock de banco como substituto.

**GREEN command:** `npm run test:auth` duas vezes, `npm run db:test`, `npm run db:lint` e visual screenshots review.

**Expected:** jornadas críticas passam em Chromium contra Supabase local real, inclusive privacidade e concorrência.

### Task 15: Auditar, aplicar remoto, PR, deploy e finalizar

**Objective:** integrar Gate 4 somente após equivalência local/CI/remoto e revisão independente.

**Files:** apenas correções reproduzidas e documentação factual necessária.

**Preconditions:** Tasks 1–14 commitadas e worktree sem alterações inesperadas.

- [ ] Carregar `superpowers:verification-before-completion`, `requesting-code-review` e `finishing-a-development-branch`.
- [ ] Executar auditoria limpa: `npm ci`, db start/reset/test/lint/types duas vezes, Vitest, Auth/Gate3/Gate4 Playwright, lint, typecheck, build e db stop.
- [ ] Confirmar hashes das dez migrations antigas; revisar novas migrations, RLS/grants/owners/search_path/storage e nenhum Gate 5.
- [ ] Secret scan de tracked/diff/build/logs para Google secret, Supabase access/secret key, DB password, token/cookie e signed URL.
- [ ] Fresh-context review dos 20 Review Focus, CSRF/origin, cache, mass assignment, mídia e mobile screenshots; corrigir Critical/Important.
- [ ] Push, PR draft e aguardar quality/database/Vercel do HEAD; corrigir causa raiz e repetir somente verificações afetadas.
- [ ] Configurar Vercel `SUPABASE_SECRET_KEY` somente server-side em Preview/Production pelo mecanismo seguro; confirmar ausência no browser/build. Nenhuma outra env nova.
- [ ] Comparar migration history, rodar `db push --linked --dry-run`, aplicar somente Gate 4 ao ref `svvthxrixrnrrgosydtg` e validar migrations/RLS/functions/bucket/types sem drift.
- [ ] Não criar grupo/member/follow fake remoto. Smoke preview/produção usa páginas públicas/estados não destrutivos; conta real somente se já houver dado apropriado e sem PII no relatório.
- [ ] Marcar PR ready, exigir CI final, merge normal sem bypass e atualizar `main` com `pull --ff-only`.
- [ ] Confirmar CI main, Vercel Ready e HTTP 200 em home, grupos conhecidos/estados seguros e admin auth guard; não fabricar domínio para smoke.
- [ ] Confirmar projeto Free, Hobby, custo R$ 0, Git limpo, `origin/main=HEAD`, Gate 5 ausente e registrar evidências no ledger.

**Verification command:** executar integralmente o bloco `Final Verification`, depois os quatro comandos remotos deliberados e consultas read-only de equivalência.

**Expected:** zero failure, zero diff de types, migration history local/remoto igual, CI/deploy Ready e nenhum segredo/findings Critical/Important.

**Expected:** Gate 4 reproduzível, seguro e integrado, sem dados falsos ou ampliação de escopo.

## Final Verification

```powershell
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

Remote deliberado somente após local, review e CI verdes:

```powershell
npm exec --no -- supabase migration list --linked
npm exec --no -- supabase db push --linked --dry-run
npm exec --no -- supabase db push --linked
node scripts/generate-database-types.mjs --linked --output "$env:TEMP/correhub-gate4-remote-types.ts"
```

- [ ] Request produz exatamente um group pending + owner/pending e respeita 5/dia.
- [ ] Pending/rejected/motivo não vazam; approved é público; suspended é indisponível ao público.
- [ ] Somente platform_admin independente aprova/rejeita; moderator e self-reviewer falham.
- [ ] Aprovação é atômica, ativa owner, preserva exatamente um owner e persiste audit/notification/analytics/activity sem duplicar.
- [ ] Rejeição preserva grupo e resubmit reutiliza o mesmo ID.
- [ ] `community` e `professional` funcionam sem diferença de autorização, billing ou cobrança.
- [ ] Open/approval_required, request idempotente, approve/reject/block/leave e hierarchy passam.
- [ ] Blocked não reentra; owner não sai; admin não eleva privilege nem administra outro grupo.
- [ ] Transfer exige aceite vigente e elegibilidade, troca papéis atomicamente e mantém owner único.
- [ ] Follow só em approved, não cria membership/acesso e unfollow não remove membership.
- [ ] Perfil privado não vaza em roster; suspended account/group não muta.
- [ ] Admin UI mínima lista, revisa, aprova e rejeita com motivo sob autorização server/database.
- [ ] Testes concorrentes reais de approval, membership e transfer têm estado final único e coerente.
- [ ] Mídia é privada, validada, revogável e sem secret/client upload direto.
- [ ] Nenhum counter persistido, grupo/corrida fake remoto ou feature Gate 5.
- [ ] pgTAP, concorrência, Vitest, Testing Library, Playwright, visual QA, reset, lint DB, types, lint, typecheck, build e secret scan passam.
- [ ] CI PR/main, Supabase remoto e Vercel produção estão verdes; custo R$ 0.

## Commits Planned

1. `docs: establish Gate 4 execution and frontend governance`
2. `feat: add secure group requests and visibility`
3. `feat: add independent atomic group review`
4. `feat: enforce group membership hierarchy`
5. `feat: add accepted group ownership transfers`
6. `feat: authorize independent group follows`
7. `test: verify concurrent group transitions`
8. `feat: add typed group domain services`
9. `feat: secure private group media`
10. `feat: add organizer group request journey`
11. `feat: add group page join and follow flows`
12. `feat: add group member and ownership management`
13. `feat: add minimal group approval workspace`
14. `test: cover group domain journeys`

`fix:` adicional existe somente para defeito reproduzido. Task 15 não cria commit vazio nem relatório versionado sem fato estável.

## Human Authorization Boundaries

- Nenhuma interação humana é esperada para branch, migrations locais, testes, Storage local, commits, PR, CI ou merge.
- Se Supabase/GitHub/Vercel expirarem, o agente inicia o login oficial e o humano conclui somente OAuth/2FA/CAPTCHA.
- Configurar a secret key server-side pode exigir sessão autenticada no provedor; o valor nunca é pedido em chat, impresso ou salvo no ledger.
- Smoke autenticado pode exigir consentimento Google; o agente abre o fluxo e continua após a interação mínima.
- Nenhuma boundary autoriza cobrança, plano pago, wildcard de segurança ou criação de outro projeto.

## Self-review Record

- O plano foi comparado com as seções 4, 5.3, 6, 7.3–7.5, 9, 10, 13.2, 14, 15, 16.3, 17, 20, 22 e 24 da spec.
- Self-approval, owner único, hierarchy, transfer, memberships, block, follows, privacy Gate 3, suspended accounts, audit, notifications/events/analytics, concurrency, multi-city, cache e admin UI têm contrato e teste proprietário.
- Group media foi incluída porque a seção 14 atribui `group-media` a owner pending/rejected e admin/owner approved; usa bucket privado e secret key moderna exclusivamente server-side.
- Suspensão/restauração entram no banco porque são invariantes do grupo; a UI completa de moderação permanece Gate 10. Efeitos mínimos em tabelas de corrida preservam o contrato sem criar fluxo Gate 5.
- Não há busca geral de grupos (Gate 7), corrida (Gate 5), feed/posts (Gate 8), central de notificações (Gate 9) ou painel completo (Gate 10).
- Não há marcador normativo pendente, migration antiga editada, contador persistido, serviço pago ou dependência de conversa externa.
