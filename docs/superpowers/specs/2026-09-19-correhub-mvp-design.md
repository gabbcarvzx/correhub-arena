# CorreHub — especificação oficial de produto e arquitetura do MVP

**Versão:** 1.0 · **Data:** 19 de setembro de 2026  
**Estado:** especificação concluída para revisão do responsável pelo produto; implementação não autorizada nesta etapa.  
**Mercado inicial:** São Lourenço da Mata, Pernambuco, Brasil.  
**Investimento obrigatório inicial:** R$ 0.

Este documento é a fonte de verdade do MVP após sua aprovação. Reúne requisitos de produto, contratos de dados, limites de autorização, decisões de arquitetura e critérios de aceite. Outro agente deve conseguir elaborar planos por Gate a partir dele, sem consultar a conversa original. Mudanças de escopo ou contratos devem atualizar esta especificação antes da implementação correspondente. Os Gates terão planos próprios; este documento não é um plano de execução nem cria infraestrutura.

“Deve” indica requisito obrigatório. “Futuro” e “fora do MVP” não autorizam implementação. Decisões adicionais adotadas para fechar ambiguidades estão identificadas na seção 24 e fazem parte da revisão desta versão.

## 1. Resumo executivo

O CorreHub será **o lugar que alguém abre quando quer correr em São Lourenço da Mata**. Combina grupos, agenda semanal, confirmação de participação e relações sociais locais. A corrida é a unidade central de descoberta e retorno; o feed apoia o encontro presencial.

O ciclo principal é: **descobrir corrida → confirmar participação → participar → conhecer grupo e corredores → seguir pessoas e grupos → voltar na semana seguinte**. Páginas públicas permitem aquisição por WhatsApp, Instagram, mecanismos de busca e QR Codes. Conta é exigida no momento da ação, não para consultar informações públicas.

O MVP usa um monólito modular Next.js com Supabase como banco, autenticação e armazenamento. Segurança deve existir no PostgreSQL e nas políticas de acesso, independentemente da interface. A operação começa em uma cidade, mas todas as relações geográficas são modeladas para expansão.

## 2. Objetivos

- Permitir encontrar rapidamente onde, quando e com quem correr nesta semana.
- Transformar descoberta em confirmações reais e retorno semanal.
- Dar aos organizadores gestão simples de grupos, membros, corridas e treinos recorrentes.
- Formar uma comunidade local com perfis, relações de seguir, posts, curtidas e comentários.
- Permitir acesso público útil e compartilhável, com privacidade coerente para conteúdo restrito.
- Construir uma base segura e verificável para multi-cidade e futura monetização B2B.
- Validar o produto sem investimento obrigatório em serviços, domínio ou APIs.

## 3. Não objetivos

O MVP não será aplicativo de rastreamento esportivo, marketplace completo, mensageria instantânea, plataforma de pagamentos, sistema médico ou gerenciador de provas com cronometragem. Não pretende competir por abrangência nacional no lançamento nem exigir que o corredor pague pelo núcleo de uso. Otimizações complexas só entram após medições. O inventário completo de exclusões está na seção 25.

## 4. Personas e papéis

| Persona/papel | Necessidade e permissões |
| --- | --- |
| Visitante | Ver corridas públicas, grupos aprovados, informações públicas e descoberta básica sem conta. |
| Corredor autenticado | Criar perfil e username, informar nível/distância/pace opcional, descobrir e seguir pessoas/grupos, solicitar entrada, confirmar participação, publicar, curtir, comentar e consultar agenda. |
| Organizador | É também corredor. Solicita grupo; quando admin/owner ativo de grupo aprovado, gerencia membros, cria corridas/séries e publica pelo grupo. Não existe role global de organizador. |
| `member` | Membro ativo de um grupo; pode acessar conteúdo `members_only`, sem poderes de gestão. |
| `admin` do grupo | Gerencia membros comuns, corridas, séries, perfil e publicações do próprio grupo. Não transfere propriedade nem promove administradores. |
| `owner` do grupo | Tem poderes de admin, promove/rebaixa admins e transfere propriedade de forma atômica. |
| `moderator` da plataforma | Analisa denúncias, modera usuários/conteúdo e suspende grupos; consulta somente auditoria operacional pertinente. Não aprova grupos nem concede roles. |
| `platform_admin` | Aprova/rejeita grupos, suspende/restaura grupos e usuários, modera conteúdo, consulta auditoria e métricas administrativas. |

Roles da plataforma ficam em `platform_roles`, separados de `profiles`. Nenhuma role é inferida de e-mail, username, metadata editável, tipo de grupo ou propriedade de grupo.

## 5. Jornada principal e fluxos

### 5.1 Aquisição e participação

1. Visitante abre link público de uma corrida ou escolhe sua cidade na descoberta.
2. Vê grupo, data, horário, ponto de encontro, distância, nível, vagas e status.
3. Seleciona **Eu vou correr**. Sem sessão, inicia Google Login preservando apenas um caminho interno seguro de retorno.
4. Se necessário, conclui onboarding; retorna à corrida com a intenção preservada.
5. Confirma explicitamente a ação na página. O servidor revalida elegibilidade e vagas. A autenticação sozinha não cria participação.
6. A interface mostra **Presença confirmada**, opção de cancelar e inclusão na agenda.
7. Após o encontro, encontra grupo e corredores e pode seguir/interagir. O produto incentiva a próxima corrida.

“Presença confirmada” representa intenção (`going`), não prova de comparecimento. O MVP não atribui presença física automaticamente.

### 5.2 Onboarding

Google → perfil mínimo idempotente → escolha de username, nome, cidade, nível e distância preferida → informações opcionais de avatar, bio e pace → conclusão → Home ou retorno seguro original. A cidade inicial vem do banco. Não solicitar endereço residencial nem geolocalização. Perfil público é o padrão; a escolha de privacidade é explicada e editável.

### 5.3 Organizador

Solicitar grupo → acompanhar análise → receber decisão interna → administrar grupo aprovado → publicar corrida única ou série semanal → gerir membros e participantes. Rejeição informa motivo ao solicitante e permite editar e reenviar a mesma solicitação.

### 5.4 Estados obrigatórios de interface

Cada fluxo deve prever carregamento, vazio com ação útil, sucesso, erro recuperável, ausência de permissão, sessão expirada, item removido, corrida lotada/cancelada e grupo suspenso. Erros de corrida concorrente devem refletir o estado confirmado pelo banco, sem sucesso otimista enganoso. Repetir uma operação não cria duplicatas.

## 6. Arquitetura geral

### 6.1 Stack e fronteiras

| Camada | Decisão |
| --- | --- |
| Aplicação | Next.js 16, App Router, TypeScript estrito, React compatível com a versão estável escolhida. |
| Interface | Tailwind CSS v4, shadcn/ui como base acessível, Lucide Icons, tokens semânticos próprios. |
| Formulários | React Hook Form e Zod; contratos reaproveitados entre cliente e servidor quando apropriado. |
| Dados e identidade | Supabase PostgreSQL, Auth com Google, Storage e RLS; clientes `supabase-js` e `@supabase/ssr`. |
| Mutação | Server Actions/Route Handlers finos; regras sensíveis em transações/RPC PostgreSQL autorizadas. |
| Testes | Vitest, Testing Library e integração com PostgreSQL/Supabase local; Playwright nos fluxos críticos de navegador. |
| Entrega futura | Git/GitHub, CI, Vercel Hobby somente para uso pessoal e validação não comercial compatíveis com seus termos. |

Adotar versões corrigidas e compatíveis dentro da stack aprovada, fixar dependências e versionar lockfile no Gate 0. Não usar Prisma, Auth.js ou Redux. Estado remoto permanece no servidor; estado local simples usa recursos do React e parâmetros de URL.

Separar módulos de identidade, cidades, grupos, corridas, participação, social, notificações, moderação e analytics. Cada módulo expõe operações pequenas e contratos de entrada/saída. Componentes não contêm regras de autorização. Camada de dados centraliza consultas tipadas, paginação e tratamento de erros; sem abstração genérica de repositório sem necessidade.

Server Components atendem leitura inicial e SEO; Client Components ficam em interações. Conteúdo privado e respostas com sessão não podem entrar em cache público. Listas públicas podem ter cache curto, com invalidação por alterações relevantes. Autorização sempre é reavaliada no banco, inclusive em chamadas diretas à Data API.

### 6.2 Operação de dados

Migrations versionadas são a única fonte de mudanças persistentes de schema/policies. Tipos TypeScript são gerados a partir do banco. Não corrigir produção manualmente sem registrar migration equivalente. Seeds de produção contêm cidade e configurações necessárias; fixtures sintéticas existem somente em testes e desenvolvimento identificados.

Não existe um backend separado no MVP. Jobs simples de banco executam recorrência e manutenção em lotes. Não exigir Redis, filas externas, Realtime, serviço de mapas ou motor de busca. Busca textual inicial usa PostgreSQL, paginação por cursor e índices medidos.

### 6.3 Multi-cidade

`cities` tem país, estado, slug e fuso. Perfis, grupos, corridas e séries referenciam `city_id`. Corridas podem ocorrer fora da cidade-sede do grupo; sua cidade é explícita e a série gera ocorrências na sua própria cidade. Posts de grupo herdam contexto da cidade do grupo; posts pessoais usam a cidade atual do autor na descoberta local. Eventos analíticos guardam o contexto geográfico no momento do evento.

Navegação usa cidade selecionada, depois cidade do perfil, depois configuração `launch_city_id`. Não inserir o nome da cidade em regras/componentes. A hierarquia Brasil → Pernambuco → municípios é representada por `country_code`, `state_code` e registros de cidades, sem tabelas de países/estados desnecessárias no MVP. Recife, Camaragibe, Jaboatão e outras cidades poderão ser ativadas por cadastro, sem mudança de schema.

### 6.4 Contratos transversais

UUIDs identificam entidades. Instantes usam `timestamptz` em UTC; apresentação e semanas usam fuso IANA da cidade, inicialmente `America/Recife`. Distâncias são inteiros em metros e pace em segundos/km. `created_at` e `updated_at` são controlados no banco. IDs de autor/ator vêm da identidade validada, nunca de confiança no payload.

Erros de domínio devem distinguir `unauthenticated`, `forbidden`, `not_found`, `validation_error`, `conflict`, `full`, `rate_limited` e falha temporária. Recursos restritos podem responder como não encontrados para evitar enumeração. Não devolver erros SQL internos. Operações com efeitos secundários usam chave de deduplicação e transação.

## 7. Modelo conceitual de dados

### 7.1 Convenções e limites

Chaves estrangeiras reais são obrigatórias nas relações diretas. Pares únicos usam constraint no PostgreSQL. Enums/checks limitam estados. Campos obrigatórios possuem `NOT NULL`; regras críticas não dependem apenas de Zod. Exclusões em cascata ficam limitadas a relações descartáveis, sem apagar histórico de corrida ou auditoria.

Limites de produto iniciais: nome de pessoa 2–80 caracteres; bio até 300; nome de grupo 3–100; descrição de grupo até 2.000; título de corrida 3–120; descrição de corrida até 5.000; local 3–300; post 1–2.000; comentário 1–1.000. Texto é normalizado e não pode ser só espaços. Post pode ter imagem, mas exige texto no MVP. `distance_meters` entre 100 e 100.000; pace opcional entre 120 e 1.800 segundos/km; capacidade nula significa sem limite e, quando definida, inteiro entre 1 e 10.000. Esses limites são decisões de produto revisáveis, não recomendações de treino.

### 7.2 Identidade e geografia

| Entidade | Campos e invariantes |
| --- | --- |
| `cities` | `id`, `name`, `country_code` (inicial `BR`), `state_code`, `slug`, `timezone`, `is_active`; único `(country_code, state_code, slug)`. |
| `app_settings` | Registro de configuração com `launch_city_id`; leitura pública apenas dessa configuração, escrita administrativa. |
| `profiles` | `id` UUID ligado a `auth.users.id`, `username`, `full_name`, `avatar_url`, `bio`, `city_id`, `running_level`, `preferred_distance`, `pace_seconds_per_km` opcional, `is_private=false`, `onboarding_completed=false`, `created_at`, `updated_at`. Campos de onboarding podem estar ausentes só enquanto incompleto. |
| `account_controls` | `user_id`, `status` (`active`, `suspended`, `deleted`), motivo interno, timestamps; tabela privada controlada pela administração. Verificada nas mutações e visibilidade. |
| `platform_roles` | `user_id`, `role` (`platform_admin`, `moderator`), `granted_by`, `created_at`; único `(user_id, role)`, sem escrita de clientes. |
| `reserved_usernames` | Username reservado como chave; mantido por migration, sem escrita pelo usuário. |

Seed obrigatório de cidade: `São Lourenço da Mata`, `BR`, `PE`, `sao-lourenco-da-mata`, `America/Recife`, `is_active=true`. `launch_city_id` aponta para esse registro por seed idempotente. Cidade inativa não aceita novo onboarding, grupo ou corrida; histórico existente continua acessível conforme permissões.

Username é lowercase, 3–30 caracteres, regex `^[a-z0-9_]{3,30}$`, único inclusive sob concorrência. A reserva é validada no banco. Lista mínima: `admin`, `administrator`, `correhub`, `login`, `signup`, `register`, `api`, `settings`, `support`, `help`; incluir também os segmentos institucionais efetivamente adotados. Alteração de username é permitida com as mesmas validações, sem histórico de aliases no MVP; IDs mantêm relações e links internos.

`running_level`: `beginner`, `intermediate`, `advanced`; corrida também aceita `all_levels`. `preferred_distance`: `up_to_5k`, `5k_to_10k`, `10k_to_21k`, `over_21k`, `flexible`. Interface usa rótulos em português. Perfil não guarda e-mail do Google; identidade e e-mail permanecem no Auth.

### 7.3 Grupos e corridas

| Entidade | Campos e invariantes |
| --- | --- |
| `groups` | `id`, `slug` único, `name`, `description`, `city_id`, `type` (`community`, `professional`), `join_policy` (`open`, `approval_required`), `status` (`pending`, `approved`, `rejected`, `suspended`), `created_by`, `owner_user_id`, `avatar_url`, `cover_url`, `approved_by`, `approved_at`, `rejection_reason`, `suspended_at`, `created_at`, `updated_at`. Metadados internos da análise não integram projeção pública. |
| `group_members` | `group_id`, `user_id`, `role` (`member`, `admin`, `owner`), `status` (`active`, `pending`, `blocked`), `joined_at`, `updated_at`; único `(group_id, user_id)`. Um único owner por grupo, coerente com `groups.owner_user_id`. |
| `group_follows` | `user_id`, `group_id`, `created_at`; único `(user_id, group_id)`. Seguir não equivale a ser membro. |
| `run_series` | `id`, `group_id`, `city_id`, `title`, `description`, `weekday` ISO 1–7, `local_start_time`, `meeting_offset_minutes`, `timezone`, `starts_on`, `ends_on` opcional, `location_text`, `distance_meters`, `level`, `visibility`, `max_participants`, `status` (`active`, `paused`, `ended`), `created_by`, `generated_through`, timestamps. Uma frequência semanal e um dia por série. |
| `runs` | `id`, `group_id`, `city_id`, `series_id` opcional, `occurrence_date` opcional, `title`, `description`, `starts_at`, `meeting_time`, `location_text`, `distance_meters`, `level`, `visibility` (`public`, `members_only`), `max_participants`, `status` (`scheduled`, `cancelled`, `completed`), `created_by`, `cancelled_at`, `cancellation_reason`, `created_at`, `updated_at`. |
| `run_participations` | `id`, `run_id`, `user_id`, `status` (`going`, `attended`, `no_show`, `cancelled`), `joined_at`, `updated_at`; `UNIQUE(run_id, user_id)`. `id` preserva a referência histórica após anonimização. |

`meeting_time` é instante completo opcional, exibido como horário de encontro, entre duas horas antes de `starts_at` e o próprio início. A série armazena deslocamento de 0–120 minutos para calculá-lo. Evento único tem `series_id` e `occurrence_date` nulos. Ocorrência recorrente tem ambos presentes, `UNIQUE(series_id, occurrence_date)`, e deve pertencer ao grupo da série. `occurrence_date` preserva a data nominal mesmo se o horário da ocorrência for excepcionalmente alterado.

### 7.4 Social e operação

| Entidade | Campos e invariantes |
| --- | --- |
| `user_follows` | `follower_id`, `followed_id`, `created_at`; par único, `follower_id <> followed_id`. |
| `posts` | `id`, `author_user_id`, `group_id` opcional, `body`, `image_url` opcional, `visibility` (`public`, `members_only`, `private`), `created_at`, `updated_at`, `deleted_at`. Pessoal aceita `public/private`; grupo aceita `public/members_only`. |
| `post_likes` | `post_id`, `user_id`, `created_at`; único `(post_id, user_id)`. |
| `comments` | `id`, `post_id`, `user_id`, `body`, `created_at`, `updated_at`, `deleted_at`. Sem `parent_id` ou replies. |
| `activity_events` | `id`, `actor_user_id`, `group_id` opcional, `event_type`, `entity_type`, `entity_id`, `metadata` JSONB, `dedupe_key` única, `created_at`. Tipos MVP: `run_created`, `run_joined`, `group_joined`. |
| `notifications` | `id`, `recipient_user_id`, `actor_user_id` opcional, `type`, referência ao alvo, `dedupe_key`, `read_at`, `created_at`; único `(recipient_user_id, dedupe_key)`. Sem texto privado duplicado. |
| `reports` | `id`, `reporter_user_id`, `target_type` (`user`, `post`, `comment`, `group`), `target_id`, `reason`, `details`, `status` (`open`, `in_review`, `resolved`, `dismissed`), `assigned_to`, `resolution`, timestamps. |
| `admin_audit_logs` | `id`, `actor_user_id` opcional para processos operacionais, `action`, `target_type`, `target_id`, `metadata`, `created_at`; somente append por operação confiável. |
| `analytics_events` | `id`, `event_name`, `user_id` opcional, `anonymous_session_id` opcional, `city_id` opcional, `entity_type/id` opcionais, `properties` JSONB validado, `event_key`, `created_at`; escrita controlada, sem leitura pública. |

Referências polimórficas de denúncias, atividades e notificações são validadas pela operação de inserção: tipo permitido, alvo existente e acessível. Eventos não concedem acesso ao alvo. Denúncias/auditoria mantêm somente evidência mínima quando o alvo é removido. Não usar JSONB para esconder relações centrais ou payloads arbitrários.

Tabelas internas de apoio, sem acesso direto de clientes: `notification_jobs` (evento, destinatários por cursor, deduplicação, tentativas e estado), `media_uploads` (dono, alvo, caminho, hash, tamanho, expiração e estado), `rate_limit_buckets` (usuário, ação, janela e consumo), `group_owner_transfers` (grupo, owner atual, destinatário, aceite, expiração e estado) e `domain_event_receipts` (tipo, chave de negócio e primeiro processamento). Recibos mínimos de deduplicação permanecem enquanto a entidade existe, separados do conteúdo de feed/analytics que expira; isso impede reentradas gerarem novos eventos após a limpeza de 90 dias. Todos seguem RLS/GRANT restritos e limpeza definida pela finalidade.

### 7.5 Índices e consultas

Prever índices em FKs usadas nas policies e consultas: perfis por cidade/username; grupos por cidade/status; membros por usuário/status e grupo/role/status; corridas por cidade/visibilidade/status/início e grupo/início; séries por status; participações por usuário/status e corrida/status; follows nos dois sentidos; posts por autor/data e grupo/data; comentários por post/data; atividades por ator/data e grupo/data; notificações por destinatário/data/leitura; denúncias por status/data. Índices parciais podem excluir conteúdo apagado. Confirmar planos de execução antes de acrescentar índices extras.

Não persistir `followers_count`, `members_count`, `participants_count` ou `likes_count` no MVP. Contagens são agregações limitadas ao contexto autorizado. Uma RPC estreita pode devolver somente total de vagas/confirmados sem revelar linhas individuais.

## 8. Autenticação

Google OAuth através do Supabase Auth é o único provedor habilitado no lançamento. Usar somente escopos básicos de identidade, sem acesso a contatos, Drive ou localização. E-mail/senha é extensão futura da mesma identidade Supabase; não criar autenticação paralela.

Usar fluxo OAuth/PKCE com callback e lista exata de URLs permitidas por ambiente. `returnTo` aceita apenas caminhos locais autorizados, impedindo redirecionamento aberto. Criação de perfil deve ser idempotente por `auth.users.id`; username só é reivindicado no onboarding. Se a criação falhar, login pode ser retomado sem duplicar conta. Metadata do Google é sugestão de nome/avatar, nunca autorização.

SSR usa clientes distintos para browser e servidor e cookies por requisição via `@supabase/ssr`. A documentação atual orienta validar identidade com `getClaims()` e usar `getUser()` quando for necessária consulta atual ao Auth; `getSession()` isolado não autoriza operações. O mecanismo de renovação de sessão deve seguir a integração Next.js vigente e ser testado em reload, expiração e múltiplas abas. [Referência oficial SSR](https://supabase.com/docs/guides/auth/server-side/creating-a-client?queryGroups=framework&framework=nextjs).

Usuário sem onboarding só pode concluir/editar seu perfil inicial, sair e consultar conteúdo público. Mutações sociais exigem onboarding completo e conta ativa. Suspensão é consultada no banco, sem esperar refresh de claims. Logout limpa sessão; não colocar tokens em logs, URLs, analytics ou armazenamento adicional manual.

## 9. Autorização e RLS

### 9.1 Princípios

RLS é obrigatória em todas as tabelas expostas. `GRANT` permite a operação na tabela e policies limitam linhas; ambos precisam estar corretos. Aplicar negação por padrão. Toda mutação valida identidade, conta ativa, propriedade/papel e transição de estado. `UPDATE` deve combinar `USING` e `WITH CHECK`; impedir troca arbitrária de IDs, autoria, grupo e papéis por grants de coluna, triggers e/ou RPC exclusiva. [RLS do Supabase](https://supabase.com/docs/guides/database/postgres/row-level-security).

Não presumir que RLS oculta colunas. Projeções públicas de perfil/grupo devem expor somente campos autorizados por grants de coluna e views com `security_invoker`, ou por funções de leitura estreitas explicitamente revisadas. Revogar acesso à tabela inteira quando necessário. Views que executam com privilégios do proprietário não podem virar atalhos de vazamento. Dados operacionais sensíveis ficam em schema privado com privilégios mínimos.

### 9.2 Matriz mínima

| Recurso | Leitura | Escrita |
| --- | --- | --- |
| Cidades/configuração pública | Todos; cidades inativas só como referência histórica | Administração por operação controlada |
| Perfil público completo e ativo | Todos | Próprio usuário nos campos permitidos |
| Perfil privado | Próprio usuário; projeção mínima para relações autorizadas descritas abaixo | Próprio usuário |
| Roles/controles de conta | Apenas helpers internos; administração no escopo necessário | Processo administrativo restrito; sem mutação livre pela API |
| Grupo aprovado | Todos, campos públicos | Admin/owner ativo; status de aprovação só plataforma |
| Grupo pendente/rejeitado | Solicitante/owner e platform_admin | Solicitante edita conteúdo, platform_admin decide |
| Grupo suspenso | Gestores/membros para histórico e administração; público vê indisponível | Somente moderação/restauração e saída/cancelamento permitidos |
| Membros | Própria relação; gestores veem roster; membros ativos veem identidades mínimas do grupo | Entrada/saída e gestão por RPC, respeitando hierarquia |
| Corrida pública de grupo aprovado | Todos | Admin/owner ativo do grupo |
| Corrida `members_only` | Membros ativos e gestores do grupo | Admin/owner ativo; nenhum seguidor recebe acesso por seguir |
| Participação | Própria; gestores da corrida; demais conforme seção 12 | Própria intenção por RPC; presença real indisponível no MVP |
| Follows | Próprias relações; listas de perfis públicos apenas para autenticados | Próprio ator, par válido |
| Posts | Público ativo ou membro ativo do grupo; pessoal privado só autor | Autor pessoal ou gestor atual do grupo |
| Likes/comentários | Somente se o post for legível; autor suspenso/removido é ocultado | Próprio ator, post acessível; moderação pode ocultar |
| Atividades | Reavaliar alvo, ator, grupo e privacidade em cada leitura | Apenas operações de domínio |
| Notificações | Apenas destinatário | Criação pelo sistema; destinatário só marca leitura |
| Denúncias | Apenas plataforma no escopo de moderação | Autenticado envia por RPC; administração trata |
| Auditoria | Platform_admin; moderator apenas ações operacionais de moderação | Inserção por operações administrativas, nunca edição pelo cliente |
| Analytics | Agregados para platform_admin | Eventos de domínio e endpoint validado, sem insert arbitrário |

Acesso administrativo a conteúdo privado é excepcional: moderator/platform_admin podem consultar evidência vinculada a denúncia ou caso de suporte/moderação, por operação específica auditada; não recebem feed irrestrito de perfis privados. Corridas/posts de grupo suspenso saem da descoberta e do acesso público; gestores e membros ativos conservam leitura histórica interna. Participantes sem esse vínculo conservam apenas comprovante mínimo na própria agenda. Notificações de corridas restritas são geradas somente para membros ativos, mesmo que outros usuários sigam o grupo.

### 9.3 Privacidade de perfil

`is_private` não implementa solicitação de seguidores no MVP. Seguir não libera dados privados. Perfil privado fica fora da descoberta de corredores e exibe a terceiros somente username/nome de exibição e avatar genérico em cartão mínimo, sem bio, cidade, nível, pace, posts pessoais, agenda ou grafo social. O próprio usuário vê seu perfil completo. Não exibir o avatar enviado em perfil privado.

Relações contextuais legítimas podem mostrar identidade mínima: gestores veem nome/username do inscrito para organizar a corrida; membros veem nome/username no roster interno. Comentários e curtidas voluntários em posts acessíveis preservam essa identidade mínima, com aviso de que perfil privado não torna uma interação pública anônima. Posts publicados como grupo seguem a visibilidade do grupo, independentemente da privacidade do autor responsável.

Ao tornar o perfil privado, todos os posts pessoais passam a ter visibilidade efetiva privada, mesmo se gravados como `public`; eventos pessoais deixam de aparecer para terceiros. Torná-lo público novamente não republica automaticamente posts antes privados: a transição para privado também atualiza suas visibilidades para `private`. Autorização de mídia acompanha a mesma regra.

### 9.4 RPC e transações

RPCs obrigatórias para aprovação de grupo, alteração de papéis/propriedade, entrada/aprovação/bloqueio de membro, confirmação/cancelamento de participação, geração de ocorrências, cancelamento de corrida/série e moderação com auditoria. Criação de post/evento/notificação que compartilha invariantes deve ser atômica ou usar pendência persistida com execução idempotente.

Preferir `SECURITY INVOKER`. Quando `SECURITY DEFINER` for necessário, usar `search_path` explícito e restrito, nomes qualificados, validação de `auth.uid()` e papel atual, execução revogada de `PUBLIC`/`anon`, grants mínimos e argumentos validados. Helpers privilegiados ficam em schema não exposto; wrappers expostos têm contrato mínimo e revisão específica. Evitar recursão de policies de membros/roles por helpers de predicado estreitos. Funções de job são privadas, executáveis só pelo papel de agendamento: não usam identidade humana fictícia nem exceção genérica para `auth.uid() IS NULL`.

### 9.5 Testes de autorização obrigatórios

Usar identidades reais distintas no banco de teste: visitante, corredor A/B, membro, admin/owner de outro grupo, admin/owner correto, moderator, platform_admin e conta suspensa. Devem falhar chamadas diretas à API/RPC que tentem: editar perfil alheio; aprovar próprio grupo; membro criar corrida; não membro ler/entrar em `members_only`; elevar role; publicar como grupo sem gestão; ler denúncias; modificar participação alheia; marcar a si como `attended`; acessar mídia privada; mudar autor/grupo/owner por update; reutilizar JWT após suspensão para mutar. Testar caminhos permitidos e revogação de acesso após saída, bloqueio e suspensão.

## 10. Grupos

Solicitação cria grupo `pending`, com criador como `owner_user_id` designado e relação `owner/pending`. Isso garante um responsável desde a criação, sem poder operacional antes da aprovação. Apenas `platform_admin` pode aprovar/rejeitar. Mesmo um platform_admin não pode aprovar solicitação da qual seja criador ou owner; exige outro administrador.

Aprovação executa, na mesma transação e sob bloqueio da linha: validar pendência e administrador independente; atualizar `status=approved`, `approved_by`, `approved_at`; ativar criador como owner; registrar auditoria e notificação deduplicada. Falha em qualquer passo reverte tudo. Grupos aprovados ou suspensos devem conservar exatamente um owner ativo no vínculo, embora a suspensão desabilite seus poderes operacionais.

Rejeição preserva pedido e motivo privado. Reenvio muda `rejected → pending`; somente nova aprovação ativa o grupo. Suspensão `approved → suspended` pausa séries, cancela corridas futuras agendadas com motivo e notifica afetados, preservando histórico. Restauração `suspended → approved` não reabre corridas nem séries automaticamente. Ações em lote são transacionais no tamanho inicial e devem respeitar limites; aumento de escala exige desenho de processamento antes de relaxar atomicidade.

Entrada em grupo `open` cria `member/active`; em `approval_required`, cria `member/pending`. Pedidos repetidos são idempotentes. Gestores aprovam/rejeitam membros comuns; rejeição remove a solicitação pendente, e bloqueio conserva `blocked`. Bloqueado não pode voltar sozinho. Mudança da política de entrada não aprova automaticamente pedidos existentes.

Saída de membro comum/admin remove vínculo e cancela suas participações futuras em corridas `members_only`; corridas públicas permanecem confirmadas salvo bloqueio explícito no grupo. Bloqueio no grupo cancela todas as participações futuras desse usuário no grupo, impede novas inscrições/interações e entrada, mas não promete ocultar páginas públicas que qualquer visitante vê. Um vínculo bloqueado nunca permite acesso restrito.

Somente owner promove/rebaixa admins. Admin não altera owner ou outro admin. Transferência exige destinatário já membro ativo, conta ativa e aceite explícito no fluxo; a operação troca os dois papéis e `owner_user_id` numa transação. Owner não sai, não é bloqueado e não exclui conta antes de transferir responsabilidade; em abandono, platform_admin executa transferência auditada para membro que aceitou. Grupo aprovado não é apagado pelo cliente.

Transferências ficam pendentes por até sete dias e são aceitas pelo destinatário autenticado; a operação revalida owner e papéis atuais antes de concluir. Se não houver sucessor e o owner solicitar exclusão, um platform_admin real assume custódia com aceite registrado, mediante vínculo ativo criado na mesma transação, e suspende o grupo até haver organizador. Isso não autoriza atraso indefinido na exclusão da conta nem uso de usuário fictício. A regra de custódia também resolve solicitações pendentes/rejeitadas abandonadas, mantendo-as indisponíveis ao público.

Seguir grupo é independente: não exige ser membro nem cria inscrição em corridas. Só grupos aprovados aceitam novos follows. Tipos `community/professional` existem desde o banco e não mudam permissões nem geram cobrança no MVP.

## 11. Corridas e recorrência

### 11.1 Corridas oficiais

Somente admin/owner ativo de grupo aprovado e conta ativa cria corridas e séries. Não há corrida pessoal avulsa fora de grupo. Novas corridas devem começar no futuro. `public` é legível sem conta; `members_only` exige vínculo ativo para leitura e inscrição. Seguir um grupo não basta.

Transições: `scheduled → cancelled` por gestor/plataforma; `scheduled → completed` por gestor após `starts_at`. `cancelled` e `completed` são terminais no MVP. Passar do horário retira a corrida da agenda futura, mas não prova realização nem altera presenças. Corrida concluída continua no histórico.

Não oferecer exclusão física de corridas na aplicação, mesmo sem participantes. Cancelamento preserva registros, motivo e participações; estas continuam com estado anterior, mas não contam como confirmação válida quando a corrida está cancelada. Notificar confirmados. Agenda mostra cancelamento claramente.

Título/descrição/local/horário podem ser corrigidos pelo gestor antes do início, com aviso interno aos confirmados quando houver mudança de local, dia ou horário. Grupo, série e autoria são imutáveis. Visibilidade pode mudar antes do início somente sem participações não canceladas; com participantes, cancelar e recriar. Redução de capacidade nunca pode ficar abaixo do total que ocupa vagas. Corrida iniciada só admite conclusão/cancelamento e correções administrativas auditadas.

### 11.2 Recorrência semanal

O MVP suporta uma ocorrência por semana, por dia e hora local, data inicial obrigatória (padrão: hoje na cidade) e término opcional. Exemplo: um grupo cria série de terça-feira, 19h, 5 km. Mais de um dia exige séries separadas; não implementar linguagem completa RRULE.

Ao criar/retomar série, gerar ocorrências futuras dos próximos **28 dias**, respeitando `starts_on/ends_on`. Um job diário no PostgreSQL usando Supabase Cron/`pg_cron` estende a janela. A capacidade nativa agenda SQL no banco, sem contratar scheduler externo. [Supabase Cron](https://supabase.com/docs/guides/cron).

Geração deve ser idempotente por `(series_id, occurrence_date)`, bloquear série durante o lote e avançar `generated_through` só após sucesso. Não gerar passado, duplicar notificações ou recriar ocorrência cancelada. Registrar horário da última execução/erro para operação. Se o projeto gratuito estiver pausado, após retomada executar reposição por operação administrativa idempotente; calendário já materializado não depende de uma chamada pública gerar dados.

Fuso da série é copiado da cidade na criação. Converter dia/hora local para UTC por ocorrência, sem somar 168 horas cegamente. Em eventual horário inexistente por mudança de fuso, deslocar para o primeiro instante válido seguinte; em ambiguidade, usar a primeira ocorrência cronológica. Exibir horário final; testar essas regras mesmo que a cidade inicial não aplique horário de verão.

### 11.3 Edições e exceções

- **Só esta corrida:** editar a ocorrência concreta; não mudar a série e não alterar a chave nominal `occurrence_date`.
- **Modelo da série:** alterações de título/local/distância/capacidade/visibilidade afetam somente ocorrências ainda não materializadas. Interface informa o primeiro período afetado; ocorrências existentes têm edição individual.
- **Mudar dia, hora ou fuso recorrente:** encerrar a série e criar outra; o fluxo permite cancelar as ocorrências futuras antigas antes de confirmar, evitando sobreposição silenciosa.
- **Pausar:** interrompe geração; corridas já publicadas continuam válidas. **Retomar:** gera somente futuro dentro da janela.
- **Encerrar:** impede novas ocorrências; gestor escolhe explicitamente manter as já publicadas ou cancelá-las em lote, com confirmação do conjunto afetado.
- **Cancelar uma ocorrência:** mantém a linha cancelada e a chave única, sem alterar a série.

Toda corrida é uma cópia concreta dos atributos da série; páginas, inscrições e histórico nunca dependem de expandir uma regra em tempo de leitura. Notificações de novas ocorrências são agrupadas para evitar uma notificação por semana gerada no mesmo lote.

## 12. Participações e agenda

`UNIQUE(run_id, user_id)` representa uma relação por corredor/corrida. Primeira confirmação cria `going`; cancelamento muda para `cancelled`; reconfirmação antes do início reutiliza a linha e preserva `joined_at` original. `updated_at` registra a transição mais recente. Repetir confirmação/cancelamento não produz novo efeito social ou analítico.

RPC de confirmação bloqueia a linha de `runs`, valida `scheduled`, início futuro, grupo aprovado, conta/onboarding, ausência de bloqueio no grupo e, se restrita, vínculo ativo. Conta vagas ocupadas por `going` e `attended`; `no_show/cancelled` não ocupam. Todas as operações que alterem vagas ou capacidade adotam o mesmo bloqueio. Se a última vaga for disputada, somente uma confirmação vence. Sem fila de espera no MVP.

O próprio corredor pode cancelar antes do início. Após o início, sua participação é histórica e não pode ser reescrita por ele. O MVP não disponibiliza marcação de `attended/no_show` para ninguém na interface ou API de cliente; esses estados estão reservados no modelo para fluxo futuro de responsáveis autorizados, com auditoria e autorização próprias. Não tratar `going` como comparecimento físico.

Visitantes veem somente total agregado e vagas em corridas públicas. Autenticados com acesso à corrida podem ver nome/username/avatar de participantes com perfil público e conta ativa; perfis privados entram no total sem identificação nessa lista. Gestores do grupo veem roster operacional com identidade mínima de todos, incluindo perfis privados. Cada corredor vê a própria participação e histórico. Não expor e-mail, pace ou agenda pessoal através do roster.

Agenda pessoal separa próximas confirmadas, histórico e canceladas; todas as datas usam fuso indicado. Agenda pública semanal filtra cidade e mostra somente corridas legíveis. Participante que perdeu acesso a corrida restrita vê na própria agenda apenas comprovante mínimo de cancelamento, sem local ou novos detalhes restritos; esse comprovante vem de projeção autorizada específica. Não exigir integração com calendários externos.

## 13. Rede social, feed e notificações

### 13.1 Relações e publicações

Seguir pessoas é unilateral, idempotente e reversível. Não permitir seguir a si, conta suspensa ou conta excluída. Seguir não confirma presença nem dá acesso a perfil privado. Listas de relações de perfis privados não são públicas.

Post pessoal mostra autor; post de grupo mostra grupo como emissor e mantém `author_user_id` para responsabilidade interna. Somente gestores atuais do grupo criam/editam/removem publicações em nome dele; perder o papel revoga essas permissões mesmo para o autor original. Curtir e comentar exige conta ativa, onboarding e acesso atual ao post. Likes têm par único; comentários não têm replies.

Autor pode editar/remover seu post pessoal/comentário; gestores podem remover comentários nas publicações do próprio grupo; plataforma pode ocultar conteúdo mediante ação auditada. Exclusão é lógica por `deleted_at`; filhos de post removido deixam de ser legíveis e de aceitar interação. Conteúdo é texto simples, sem HTML arbitrário. Links são tratados com protocolos permitidos e sem execução de scripts.

### 13.2 Feed híbrido

Home prioriza corrida e grupos antes da comunidade. Feed mescla posts e atividades autorizadas em ordem cronológica decrescente, com cursor estável `(created_at, kind, id)`. Fontes: pessoas seguidas, grupos seguidos ou com vínculo ativo, mais conteúdo público da cidade selecionada para descoberta. Não duplicar item que pertença a múltiplas fontes; limitar página a 20 itens e paginar.

Gerar `run_created` uma vez por corrida, `run_joined` na primeira confirmação e `group_joined` na primeira ativação do vínculo. Reentradas/reconfirmações não geram spam. Eventos deixam de aparecer se a participação for cancelada, o vínculo removido, o ator ficar privado/suspenso ou o alvo se tornar ilegível. `run_joined` só é distribuído a seguidores do ator; não anunciar cada inscrição a toda a cidade. `group_joined` segue a mesma regra. Ocorrências da mesma série geradas juntas são agrupadas visualmente.

Não gerar atividades por curtida, comentário, edição ou cada mudança de cadastro. `achievement_unlocked` é futuro. Metadata contém somente identificadores e informações mínimas; textos/localizações são consultados na entidade sob autorização atual. Não criar cópia pública permanente de dados que possam se tornar privados.

### 13.3 Notificações internas

MVP inclui: novo seguidor; grupo aprovado/rejeitado; pedido de membro aprovado; corrida nova em grupo seguido ou do qual participa; cancelamento/alteração relevante de corrida confirmada. Relevância não inclui toda corrida da cidade. Deduplicar destinatário que segue e participa do mesmo grupo; não notificar o próprio ator.

Notificações individuais de aprovação/novo seguidor são persistidas na transação. Distribuição para grupos/participantes cria `notification_jobs` na mesma transação de domínio; consumidor SQL nativo roda a cada minuto e processa até 100 destinatários por lote, com cursor, tentativas e deduplicação. Um lote de geração de série produz resumo por grupo, não uma notificação por ocorrência. O job prioriza cancelamentos e alterações próximas, com meta de entrega em até cinco minutos enquanto o serviço está disponível. Falha na entrega não desfaz confirmação válida; fila atrasada e erros ficam visíveis à operação administrativa. Isso usa a capacidade nativa de agendamento, sem filas externas.

Destinatário pode listar e marcar lida, nunca alterar remetente/tipo/alvo. Abrir notificação revalida acesso; alvo indisponível exibe aviso genérico sem detalhes antigos. Atualizar ao abrir a central e ao recuperar foco, sem requisito de Realtime. Sem e-mail transacional de produto, push, SMS ou WhatsApp API no MVP.

## 14. Storage

### 14.1 Buckets e caminhos

Todos os buckets são privados para preservar revogação de visibilidade; conteúdo público recebe entrega autorizada por endpoint ou URL assinada curta emitida após verificar acesso. URL conhecida não deve se tornar permissão permanente. Em buckets públicos, a leitura do objeto público não depende das policies de leitura; por isso não são usados para mídia que possa se tornar privada. [Controle de acesso do Storage](https://supabase.com/docs/guides/storage/security/access-control).

| Bucket | Chave interna | Escrita |
| --- | --- | --- |
| `avatars` | `{user_id}/avatar.webp` | Próprio usuário ativo |
| `group-media` | `{group_id}/avatar.webp`, `{group_id}/cover.webp` | Owner solicitante enquanto pendente/rejeitado; admin/owner ativo quando aprovado |
| `post-media` | `{user_id}/{post_id}.webp` | Autor autenticado, post existente e permissão atual de publicação |

Os caminhos completos conceituais são `avatars/{user_id}/avatar.webp`, `group-media/{group_id}/avatar.webp`, `group-media/{group_id}/cover.webp` e `post-media/{user_id}/{post_id}.webp`. O nome do bucket não é repetido na chave. `avatar_url/image_url/cover_url` guardam referência canônica de mídia controlada, nunca URL assinada expirada ou URL externa arbitrária. Avatar Google é sugestão; importação deve passar pela mesma validação ou usar avatar padrão.

Policies de leitura de `storage.objects` verificam bucket, caminho completo e visibilidade atual da entidade. Policies negam INSERT/UPDATE/DELETE diretos a `anon` e `authenticated`; gravação/remoção passa exclusivamente pelo endpoint validado descrito abaixo. Gestores de grupo podem solicitar remoção de imagem de post do grupo, mas não sobrescrever arbitrariamente objetos de outro autor. Um post admite no máximo um objeto ativo. A tabela indica quem pode solicitar cada operação, não um grant de upload direto.

### 14.2 Validação e entrega

Cliente converte JPEG/PNG/WebP para WebP e remove metadados; rejeitar SVG, GIF animado e outros formatos. Meta: avatar 100–250 KB; post 300–600 KB. Limites obrigatórios de saída: avatar 250 KB e até 512×512; post 600 KB e lado maior 1.600 px; capa 600 KB e lado maior 1.600 px. Arquivo original no navegador até 8 MB e 24 megapixels; somente a saída comprimida é enviada ao endpoint, com limite de corpo de 1 MB. Se não for possível comprimir, pedir imagem menor, sem publicar arquivo acima do limite.

Verificação de cliente não é fronteira de segurança. Upload passa por endpoint autenticado que valida tamanho, assinatura real, dimensões e decodificação, remove metadados e normaliza WebP em biblioteca open source. Primeiro, uma operação com sessão do usuário e regras do banco autoriza o alvo e cria `media_uploads`; o servidor então usa cliente privilegiado isolado exclusivamente para enviar os bytes já validados ao caminho calculado. Finalização revalida permissão atual, vincula a referência e muda para `ready`; se a autorização tiver sido revogada, o objeto é removido e não é publicado. A mídia só é legível quando a tentativa correspondente estiver `ready`; substituição fica temporariamente indisponível durante finalização, sem expor bytes pendentes.

Essa escrita de Storage é uma exceção explícita ao uso preferencial de RLS: service role ignora RLS, portanto o endpoint deve validar identidade e permissão de forma completa, nunca aceitar bucket/caminho livre, nem repassar chave ou URL de upload ao browser. Não criar janela de upload direto por autorização baseada apenas em usuário/caminho, que permitiria corrida contra a validação. Testar bypass direto, troca de alvo, revogação durante upload e falha de finalização. Todas as leituras e mutações normais de domínio continuam com sessão/RLS.

Upload e linha PostgreSQL não formam uma transação distribuída. Criar registro interno `media_uploads` com dono, alvo, caminho, estado (`pending`, `ready`, `failed`) e expiração; tornar referência visível somente após validação/finalização. Limpeza diária remove pendências/órfãos com mais de 24 horas, sem excluir mídia ainda referenciada. Guardar tamanho/hash para operação e evitar reprocessamento desnecessário.

URLs assinadas expiram em até 60 segundos para mídia restrita, sem cache compartilhado; mídia pública pode ter cache de até 60 segundos. Troca de privacidade/revogação bloqueia novas emissões imediatamente, mas uma URL já emitida pode funcionar até expirar. Essa limitação deve ser documentada; não prometer revogar cópias já baixadas. Não incluir mídia privada em Open Graph, sitemaps ou otimizadores de imagem com cache público.

## 15. Administração e moderação

Área administrativa protegida oferece fila de grupos, denúncias, suspensão/restauração, remoção lógica de conteúdo, auditoria e métricas no escopo do papel. Um moderator não recebe poderes de platform_admin pelo acesso à mesma interface. Aprovação de grupo próprio permanece proibida.

Denúncias só podem ser criadas por usuário autenticado e ativo contra alvo acessível. Motivos: spam, assédio, conteúdo inadequado, informação enganosa, outro; detalhes até 1.000 caracteres. Uma denúncia aberta por autor/alvo evita spam repetido. Envio retorna comprovante simples sem liberar SELECT na tabela. Autor denunciado, dono de grupo e organizador não veem denunciante ou dados da denúncia. Não suspender automaticamente por contagem de denúncias.

Auditar aprovação/rejeição/suspensão/restauração, moderação, transferência administrativa de owner, concessão/revogação de role, correção histórica e exclusão de conta. Registrar ator, ação, alvo, motivo, estado anterior/posterior mínimo e timestamp do banco. Logs são imutáveis para clientes; não guardar tokens, e-mail, conteúdo integral ou dados pessoais excessivos em metadata.

Bootstrap do primeiro platform_admin ocorre em procedimento privilegiado versionado e documentado, vinculado a UUID de conta real autenticada, nunca por username ou cadastro inicial automático. Gestão de roles não terá painel de autoatribuição: concessão/revogação usa procedimento operacional auditado, com acesso restrito ao operador do projeto. Administrador não usa service role no navegador.

Suspensão de conta bloqueia mutações e oculta perfil/posts pessoais/atividades; cancela confirmações futuras e impede geração de séries cujo responsável esteja suspenso até outro gestor ativo assumir. Um owner suspenso mantém vínculo para preservar integridade, mas perde poderes; plataforma organiza transferência aceita, sem deixar grupo sem responsável. Posts de grupo legítimos não são removidos automaticamente por suspensão de seu autor técnico.

## 16. Analytics e métricas

### 16.1 North Star

**Participações confirmadas em corridas por semana.** Definição operacional: número de participações com estado `going` ou `attended`, em corridas não canceladas cujo `starts_at` esteja naquela semana local, de segunda 00h até a próxima segunda 00h, no fuso da cidade da corrida. Cada linha representa um par único `(run_id, user_id)`; após anonimização, seu `id` preserva a contagem sem identificar a pessoa. Canceladas e `no_show` não contam. Reconfirmar não aumenta o total. Enquanto presença real estiver desativada, a métrica mede intenção, nunca comparecimento.

Apresentar semana futura/atual como número em evolução. Para semanas encerradas, calcular com estados disponíveis e indicar data de extração; correções administrativas podem revisar histórico. Indicador separado “novas confirmações realizadas na semana” usa o instante do evento e não substitui a North Star. Métricas por cidade usam cidade da corrida; mudanças no perfil não reclassificam participações históricas.

### 16.2 Métricas secundárias

| Métrica | Definição inicial |
| --- | --- |
| Usuários ativos semanais | Usuários distintos com visita autenticada (`app_opened`, no máximo uma por dia) ou ação de domínio na semana. |
| Corridas criadas | Corridas distintas criadas no período, separando únicas e materializadas de série. |
| Grupos ativos | Grupos aprovados com ao menos uma corrida não cancelada ocorrendo na semana. |
| Participações | Pares únicos por estado e cidade; não confundir intenção com presença real. |
| Novos usuários | Contas com `signup_completed` no período; onboarding é funil separado. |
| Visitante → cadastro | Sessões anônimas elegíveis com cadastro na mesma sessão / sessões anônimas com descoberta ou corrida pública. |
| Corrida → participação | Usuários/sessões distintos que confirmam a corrida em até 7 dias após vê-la / usuários/sessões distintos que a visualizaram; separar medição autenticada de amostra anônima consentida. |
| Retorno em 7 dias | Novos usuários que voltam em sessão autenticada em outro dia entre D+1 e D+7 / coorte com janela completa. |
| Compartilhamentos | Acionamentos do compartilhamento; não afirmar envio efetivo ou entrega no WhatsApp. |

### 16.3 Eventos e integridade

Contrato obrigatório de eventos, emitidos junto com cada módulo e consolidados em análises no Gate 12: `signup_completed`, `onboarding_completed`, `group_requested`, `group_approved`, `group_joined`, `group_followed`, `run_created`, `run_joined`, `run_cancelled`, `user_followed`, `post_created`, `post_liked`, `share_clicked`. Adicionar somente instrumentação necessária ao funil: `app_opened`, `discovery_viewed`, `run_viewed`, `run_participation_cancelled`.

`run_cancelled` significa cancelamento da corrida, não da participação. `run_joined` é a primeira confirmação de um par; reconfirmação atualiza estado, sem novo evento desse tipo. Eventos de domínio são emitidos pelo servidor/banco após sucesso, na mesma transação quando possível. Eventos de navegação/compartilhamento entram por endpoint com schema, allowlist, limites e deduplicação. Cliente não pode falsificar `group_approved` ou participação pela telemetria.

Payload mínimo: nome, horário do banco, identificador de entidade, cidade contextual, ator quando necessário e chave do evento. Não coletar conteúdo de post, e-mail, GPS, IP persistente ou user agent integral. Métricas públicas não são necessárias; apenas administração acessa agregados.

Não exigir plataforma analítica paga. Usar tabela interna e consultas agregadas. Eventos brutos de uso: retenção de 90 dias, depois excluir identificadores e conservar apenas agregados mensais sem segmentos com menos de cinco usuários. Navegação anônima usa identificador de sessão aleatório de primeira parte somente após opção explícita de medição; recusar não prejudica uso. Denominadores anônimos são uma amostra e devem ser rotulados. Dados operacionais essenciais de confirmação e segurança têm finalidade distinta e não dependem desse opt-in.

## 17. UX e design system

### 17.1 Identidade e tokens

Mobile first com viewport prioritário de **390 px**; validar 360, 430, 768, 1024 e 1440 px. Identidade esportiva, social, urbana, energética e simples: fundo claro, grafite, verde-lima, tipografia forte e cards limpos. Distância, horário e participantes têm hierarquia visível. Não adotar aparência genérica de dashboard SaaS.

| Token semântico | Valor inicial | Uso |
| --- | --- | --- |
| `primary` | `#B7F34A` | Ação principal e assinatura |
| `primary-hover` | `#8ED120` | Interação da ação principal |
| `foreground` / `on-primary` | `#151515` | Texto e texto sobre verde |
| `background` | `#F8F9F7` | Fundo da aplicação |
| `surface` | `#FFFFFF` | Cards e superfícies |
| `muted` | `#70756D` | Texto secundário, sujeito a contraste |
| `border` | `#E4E7E1` | Separação visual |

Hexadecimais ficam na definição central de tokens, nunca espalhados em componentes. Tokens adicionais de erro, aviso, sucesso, foco e disabled são definidos no Gate 0 com contraste verificado. Não usar texto branco pequeno sobre verde-lima. Tipografia começa com fontes de sistema sem custo/licença externa obrigatória. Escala de espaçamento de 4 px, raios e sombras consistentes; shadcn/ui recebe a identidade do CorreHub.

### 17.2 Navegação e páginas

Mobile: **Início · Descobrir · + · Agenda · Perfil**. Botão central abre ações permitidas: publicar para corredor; criar corrida/série também para gestor; solicitar grupo como ação secundária. Visitante que tenta uma ação entra no fluxo de login. Desktop adapta a navegação com os mesmos nomes e hierarquia.

Home: (1) próxima corrida confirmada, ou sugestão local quando não houver; (2) corridas da semana; (3) grupos; (4) comunidade/feed. CTA principal **Eu vou correr**, estado **Presença confirmada**. Textos como “Grupo lotado” não substituem “Corrida lotada”: capacidade pertence à corrida.

Descobrir oferece corridas, grupos e corredores, com cidade persistida na URL, busca textual e filtros básicos: data, distância e nível para corridas; tipo para grupos. Exibir somente resultados autorizados. Ordenação: próximas corridas por início, grupos por nome, corredores públicos por username; sem ranking opaco no MVP.

Páginas obrigatórias: Home, descoberta, agenda, perfil/edição, grupo/membros/gestão, corrida/participação, criação/edição de série, post e comentários, notificações, login/callback/onboarding, configurações/privacidade, solicitação de grupo, administração, termos e privacidade.

### 17.3 Acessibilidade e qualidade

Alvos de toque de pelo menos 44×44 px, rótulos acessíveis em ícones, navegação por teclado, foco visível, hierarquia semântica, contraste WCAG AA, feedback sem depender só de cor, respeito a movimento reduzido e zoom de texto. Validar contraste calculado: a paleta é direção inicial e pode exigir ajuste no token secundário. Imagens têm descrição adequada; não inserir texto essencial apenas na imagem.

Datas em português brasileiro, distância em km com unidades claras, pace em min/km e horário local com indicação de fuso quando necessário. Sem rolagem horizontal acidental. Testar rede lenta e falhas de upload; botões bloqueiam submissão duplicada e permitem retomada segura.

## 18. SEO, compartilhamento e crescimento

Rotas públicas propostas: `/br/pe/sao-lourenco-da-mata` (segmentos derivados da cidade), `/grupos/{slug}`, `/corridas/{id}/{slug}`, `/u/{username}`. ID é identidade estável da corrida; slug de título pode mudar e redirecionar para URL canônica. Rotas de cidades usam país/estado para evitar colisões; slug de grupo é globalmente único.

Renderizar informações públicas no servidor, com title, description, canonical e Open Graph específicos; metadata privada nunca deriva de leitura privilegiada. Perfis privados/incompletos, corridas restritas, notificações, agenda pessoal, configurações, administração e resultados combinatórios de filtros recebem `noindex` e ficam fora do sitemap. `robots.txt` não substitui autorização. Sitemap contém somente cidades ativas, grupos aprovados, corridas públicas e perfis públicos completos/ativos elegíveis. Corridas públicas canceladas permanecem com aviso e metadata atualizada.

Compartilhamento usa Web Share API quando disponível, link WhatsApp comum e copiar link como fallback. Não usa API paga nem automatiza mensagens. Compartilhar corrida restrita não expõe descrição/local em preview; destinatário deve autenticar-se e ser membro. Open Graph pode usar imagem institucional com texto público renderizado localmente; nenhuma API de geração paga é requisito.

Aquisição inicial por 3–5 grupos reais, organizadores como multiplicadores, WhatsApp, Instagram, páginas públicas, SEO e QR Codes gerados com biblioteca gratuita. Antes de abrir ao público: 5–10 corridas futuras reais e conteúdo autorizado pelos responsáveis. Sem usuários falsos, inscrições simuladas ou atividade fabricada em produção. Não disparar mensagens a terceiros sem autorização explícita do responsável pelo projeto.

## 19. Estratégia financeira futura

O núcleo do corredor permanece gratuito: descobrir, seguir, participar, agenda e comunidade. Ordem prioritária de monetização futura: (1) patrocínio local; (2) destaque comercial identificado; (3) grupos profissionais/CorreHub Pro; (4) eventos pagos e comissão em fase posterior.

Clientes potenciais: assessorias, academias, lojas esportivas, fisioterapeutas, nutricionistas, organizadores e marcas. `groups.type=professional` prepara segmentação, sem plano, cobrança, vantagens ou permissões pagas no MVP. Não implementar billing, checkout, assinaturas, comissões ou gestão de anúncios nesta etapa de produto.

Não vender dados pessoais. Métricas comerciais futuras usam agregação com proteção contra reidentificação. Patrocínio e publicidade devem ser identificáveis; qualquer ativação comercial exige revisão de hospedagem e termos antes de operar.

## 20. Segurança, privacidade e engenharia

### 20.1 Defesa em camadas

RLS, constraints PostgreSQL, Zod, autenticação validada e autorização server-side são complementares. Verificação na interface melhora UX, mas nunca concede acesso. Testes devem chamar Data API/RPC/Storage diretamente para detectar bypass.

Chave publicável do Supabase pode estar no cliente; service role/secret key nunca. É proibido criar `NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY` ou qualquer segredo com prefixo `NEXT_PUBLIC_`. Preferir sessão do usuário e RLS. Capacidades privilegiadas ficam isoladas em módulos `server-only`, com imports e bundle inspecionados; não usar service role como solução geral para policies incorretas.

Segredos de Google, banco, jobs e Supabase ficam nas configurações protegidas do ambiente, fora de Git/logs. Manter exemplo de variáveis com nomes e descrições sem valores reais na implementação futura. Separar desenvolvimento local, preview e produção; previews não recebem segredos/dados de produção por padrão. Revisar dependências, lockfile e alertas de segurança.

Validar origem/CSRF de mutações baseadas em cookies, redirects, URLs de mídia, tamanho de payload e conteúdo. Usar consultas parametrizadas, escaping e política de conteúdo restritiva compatível com a aplicação. Não confiar em `user_metadata` para papéis; consultar tabelas atuais. Recursos privados nunca podem vazar em prefetch, logs, cache compartilhado, sitemap, busca, contagens de entidades inacessíveis ou notificações.

Limites iniciais no banco/endpoint, sem serviço externo: cinco solicitações de grupo por usuário/dia; dez denúncias/dia; dez posts/hora; sessenta comentários/hora; vinte uploads/hora; trinta transições de participação/minuto; sessenta ações de seguir/curtir por minuto. Tabela interna `rate_limit_buckets` com chave por usuário/ação/janela, incremento atômico e limpeza diária. Chamadas diretas passam pelos mesmos contratos; não basta limitar o Route Handler. Repetição idempotente não multiplica efeitos. Limites podem ser ajustados por evidência, com registro.

### 20.2 Dados mínimos, retenção e exclusão

Não coletar CPF, RG, endereço residencial, GPS contínuo, documentos ou dados sensíveis excessivos. Cidade, nível e pace são informações de perfil; não inferir saúde ou aptidão. Texto livre e imagens recebem orientação para não publicar dados de terceiros sem necessidade. Mostrar termos e aviso de privacidade claros antes do lançamento, com finalidades, visibilidade, retenção e canal de atendimento.

Usuário solicita exclusão pela aplicação. Operação privilegiada revoga sessões, bloqueia conta em `account_controls`, remove roles/follows, cancela inscrições futuras, apaga mídia e conteúdo pessoal e anonimiza identidade em até 30 dias. Tokens residuais não recuperam poderes porque as regras consultam estado da conta. Histórico operacional conserva somente referências pseudonimizadas estritamente necessárias; não manter nome/e-mail em metadata. Owner primeiro transfere grupo, inclusive com auxílio administrativo, preservando continuidade e o direito à remoção dos dados pessoais.

Após exclusão no Auth, `profiles` pode ser removido; FKs históricas de autoria/participação usam `ON DELETE SET NULL` com identificador técnico de registro independente quando necessário. Enquanto usuário existe, participações mantêm `UNIQUE(run_id, user_id)`; registros anonimizados não podem ser reutilizados por uma nova conta. Não usar cascade de `auth.users` para apagar corridas, grupos ou auditoria. O Gate 1 deve materializar essas regras explicitamente.

Campos de autoria histórica (`created_by`, `approved_by`, `author_user_id`, ator de auditoria e usuário de participação) aceitam nulo apenas por anonimização privilegiada; são obrigatórios na criação humana. `owner_user_id` nunca fica nulo, pois é transferido antes. Remover mídia do autor excluído também limpa referências em posts de grupo preservados, sem apagar o texto institucional. A verificação de conta exige registro existente e `active`; ausência de `account_controls` ou de profile nega mutação, inclusive com token antigo. Recibos analíticos/sociais vinculados à pessoa são removidos ou desidentificados nessa operação.

Retenção operacional inicial: notificações 90 dias; atividades de feed 90 dias; conteúdo removido logicamente até 30 dias antes da purga; denúncias encerradas e auditoria 12 meses; eventos analíticos brutos 90 dias; relatórios agregados sem identificadores podem permanecer. Denúncias abertas preservam evidência mínima com revisão administrativa mensal, sem retenção ilimitada por inércia. Controles de retenção ficam em jobs documentados. Exportação simples dos dados do próprio usuário é atendida por operação administrativa autenticada no MVP, sem exigir painel complexo.

### 20.3 Verificação e continuidade

YAGNI, DRY, TDD para regras de domínio e segurança, arquivos focados, funções pequenas e boundaries claros. Cada Gate futuro deve ter testes e commits frequentes; nenhuma feature gigante em uma única entrega. Fixtures de teste não entram em produção.

Ao final de cada fase aplicável: `npm run lint`, `npm run typecheck`, `npm run test`, `npm run build`, além de testes de integração/RLS e Playwright pertinentes. Lint é comando próprio; não presumir execução implícita pelo build do Next.js 16. [Notas oficiais do Next.js 16](https://nextjs.org/blog/next-16).

Integração deve cobrir constraints, concorrência na última vaga, idempotência de aprovação/recorrência, limites, revogação de permissões, mídia e exclusão. Testes de UI cobrem estados e acessibilidade. Fluxos E2E críticos: visitante → login → onboarding → confirmação; organizador → aprovação → série; usuário sem papel tentando operação restrita. OAuth real recebe smoke test com conta real autorizada; testes automatizados usam ambiente isolado, sem bypass implantado em produção.

CI futura verifica alterações antes de merge; migrations são ensaiadas em banco local limpo e em upgrade a partir do estado anterior. Testar restauração de backup antes do beta. Não presumir backup gerenciado no plano gratuito: exportar banco e inventário/objetos de Storage para destino privado já disponível, com criptografia e retenção de sete cópias diárias e quatro semanais, dentro das cotas. Nunca colocar backup de dados pessoais em GitHub. Meta inicial operacional: RPO 24h e restauração ensaiada em até um dia útil, sem prometer SLA de serviços gratuitos.

## 21. Restrições de custo e operação autônoma

### 21.1 Orçamento inicial

**R$ 0 obrigatório**: ferramentas open source, ambiente local, GitHub gratuito dentro das cotas, Supabase Free e Vercel Hobby para desenvolvimento/validação pessoal não comercial permitidos. Usar subdomínio fornecido pela hospedagem; domínio próprio é opcional futuro. Google Login não depende de SMS ou provedor de e-mail transacional de produto.

Na consulta de 19/09/2026, Supabase Free informa 500 MB de banco, 1 GB de arquivos, 50 mil usuários ativos mensais, 5 GB de egress e 5 GB de egress em cache; projetos gratuitos podem pausar após uma semana de inatividade e há limite de dois projetos ativos. Esses valores são referência operacional, não garantia contratual permanente; reconferir antes do provisionamento e lançamento. [Planos do Supabase](https://supabase.com/pricing).

Vercel Hobby é gratuito, mas restrito a uso pessoal não comercial. Ausência de cobrança ao corredor não comprova elegibilidade: a finalidade comercial do projeto também precisa ser avaliada. Antes de beta público ou patrocínio, verificar termos aplicáveis; se o uso não for elegível, manter validação local/não comercial ou escolher hospedagem gratuita compatível com o mesmo app. Não aprovar cobrança ou upgrade silenciosamente e não prometer lançamento comercial ilimitado a custo zero. [Hobby](https://vercel.com/docs/plans/hobby) e [regras de uso](https://vercel.com/docs/limits/fair-use-guidelines).

### 21.2 Controles de consumo

Um projeto remoto gratuito inicialmente e desenvolvimento/testes locais evitam depender de ambientes pagos. CI usa cotas gratuitas e banco efêmero; esgotamento suspende jobs opcionais ou usa execução local, sem comprar minutos. Não criar múltiplos projetos para contornar limites. Não usar rotinas artificiais para impedir pausa do provedor.

Revisar semanalmente banco, Storage, egress, funções e cotas de CI/hospedagem. Alertas operacionais em 70% e 85%; em 90%, suspender novos uploads não essenciais e reduzir telemetria/limpar expirados, preservando leitura e participação enquanto disponíveis. Se a cota impedir operação, comunicar indisponibilidade e limitar expansão. Upgrade exige decisão expressa do responsável; não é requisito inicial.

Comprimir mídia, paginar, limitar janelas de recorrência, evitar polling constante e não manter contadores duplicados. Sem APIs pagas, SMS, WhatsApp API paga, Google Maps pago, analytics pago obrigatório ou transformações de imagem pagas. Local de encontro é texto; link externo comum de mapa pode ser informado sem API e sem rastreamento.

### 21.3 Autonomia nas próximas fases

Após aprovação e planejamento de cada fase, o agente executará, quando tecnicamente possível, Git, GitHub, branches, commits, pushes, Supabase/CLI, migrations, RLS, Storage, Auth, Vercel, deploy, variáveis de ambiente, testes, CI, documentação e verificações pós-deploy. Não pedir que o usuário faça comandos, arquivos ou organização executáveis pelo agente.

Intervenção humana fica limitada a login, OAuth, CAPTCHA, códigos enviados ao usuário, consentimento explícito, autorização de conta ou segredo indisponível. Informar somente a ação mínima necessária e continuar após sua conclusão. Restrições técnicas de permissão do ambiente também devem ser explicitadas, sem contorná-las. A autonomia não autoriza despesa, mensagens a terceiros ou mudanças de escopo não aprovadas. Nesta etapa, criar apenas esta especificação e parar para revisão.

## 22. Roadmap dos Gates

Cada Gate futuro exige plano próprio, escopo pequeno, critérios verificáveis e evidências registradas. A ordem organiza entrega; segurança, acessibilidade e observabilidade mínima acompanham o módulo desde sua criação, não começam apenas no Gate 14. Nenhum beta externo deve anteceder os Gates administrativos e de segurança.

| Gate | Escopo | Saída verificável mínima |
| --- | --- | --- |
| 0 — Fundação | Repositório, versões, estrutura modular, scripts, tokens, CI e convenções | Lint/typecheck/test/build funcionando; segredos ausentes; documento aprovado antes de código. |
| 1 — Banco base | Cidades/seed, perfis, roles, controles, schema de domínio, constraints e RLS iniciais | Migrations reproduzíveis; seed idempotente; negação por padrão e papéis testados. |
| 2 — Auth + onboarding | Google, callback, SSR, perfil e username | Sessão em reload/expiração; retorno seguro; colisões/reservas e onboarding testados. |
| 3 — Perfis/social básico | Perfil/privacidade, descoberta básica de pessoas e follows | Sem auto-follow; privado não vaza; edição alheia negada. |
| 4 — Grupos | Pedido, aprovação, gestão, tipos, entrada, owner e follows | Aprovação atômica independente; transferência e hierarquia testadas. Interface administrativa mínima de aprovação já existe aqui. |
| 5 — Corridas e recorrência | Corridas únicas, séries, geração, edição e cancelamento | Janela de 28 dias; job idempotente; fuso, exceções e autorização verificados. |
| 6 — Participações e agenda | Confirmação, cancelamento, capacidade e histórico | Última vaga concorrente segura; `attended` negado; acesso restrito e agenda testados. |
| 7 — Descobrir | Busca/filtros por cidade, grupos/corridas/corredores | Resultados autorizados, paginados, úteis sem conta e sem strings geográficas fixas. |
| 8 — Feed | Posts, mídia, likes, comentários e atividades | Uma imagem, soft delete, privacidade e deduplicação; corridas continuam antes do feed. |
| 9 — Notificações | Central, leitura, fan-out/deduplicação | Destinatário isolado; cancelamentos e resumos de séries; alvo revalidado. |
| 10 — Admin/moderação | Painel completo, denúncias, suspensão, auditoria e atendimento de dados | Papéis separados; denúncias privadas; ações auditadas; exclusão exercitada. |
| 11 — SEO/compartilhamento | Metadata, OG, sitemap, robots, links e QR | Público indexável, restrito ausente de previews e sitemap; compartilhamento em mobile. |
| 12 — Analytics | Eventos, funis, métricas e retenção | North Star reproduzível, sem duplicação e sem dados excessivos; limites de amostra explicados. |
| 13 — Polimento | Responsividade, linguagem, acessibilidade, desempenho e estados | Viewports definidos sem quebra; fluxos críticos acessíveis; mídia/rede lenta tratadas. |
| 14 — Auditoria de segurança | RLS/RPC/Storage, segredos, abuse, cache, migrations e backup | Matriz completa aprovada; nenhuma vulnerabilidade crítica/alta conhecida sem correção; restauração ensaiada. |
| 15 — Pré-lançamento | Dados reais, organizadores, documentação operacional, custos e termos | 3–5 grupos, 5–10 corridas futuras; termos de hospedagem compatíveis; sem usuários falsos. |
| 16 — Beta | Uso real controlado, observação e correções | Duas semanas de jornada completa; incidentes críticos resolvidos; métricas e consumo registrados. |
| 17 — Lançamento São Lourenço | Abertura local, divulgação autorizada e acompanhamento | Smoke tests públicos/autenticados, oferta real atualizada, suporte e revisão semanal ativos. |

Infraestrutura de persistência dos eventos/notificações é criada junto com os módulos que originam efeitos, mesmo que interface e análises completas cheguem nos Gates 9/12. Não descartar acontecimentos anteriores por adiar instrumentação. Cada Gate aplicável executa os quatro comandos de qualidade e testes adicionais; falha impede declarar conclusão.

## 23. Critérios de sucesso

### 23.1 Aceite funcional e técnico do MVP

- Visitante consegue descobrir e compartilhar corrida pública sem cadastro; ações pessoais exigem autenticação.
- Corredor consegue completar o ciclo de descoberta, confirmação, agenda e retorno, inclusive após expiração de sessão.
- Organizador real consegue operar grupo aprovado e série semanal sem intervenção técnica recorrente.
- Nenhum papel acessa ou altera recurso fora da matriz; cenários negativos da seção 9 passam por testes diretos.
- Histórico resiste a cancelamentos, suspensão, alterações de série e exclusão de conta.
- Cidade adicional é cadastrável sem refatorar componentes ou regras de domínio.
- As larguras de referência, teclado, estados vazios/erro e contraste são verificados.
- Custo obrigatório permanece zero durante desenvolvimento e validação elegíveis; não há dependência funcional de serviço pago.

### 23.2 Aceite de prontidão local

Ter 3–5 grupos reais aprovados, 5–10 corridas futuras reais, organizadores ativos e conteúdo autêntico. Todos os grupos conhecem como cancelar corrida e atualizar local/horário. Termos/privacidade, atendimento, moderação, backup, restauração e verificação pós-deploy estão operacionais. Nenhum bloqueio crítico de segurança, acesso ou integridade permanece.

### 23.3 Validação de produto

Observar North Star semanal por pelo menos quatro semanas após beta/lançamento, juntamente com retorno em sete dias e atividade dos grupos. Evidência inicial de valor: confirmações reais em semanas consecutivas e corredores que retornam para confirmar outra corrida. Não inventar metas numéricas de usuários/receita sem baseline. Quantificar o primeiro ciclo real e propor metas posteriores como decisão de produto registrada; isso não bloqueia a implementação dos indicadores definidos.

## 24. Riscos e decisões arquiteturais consolidadas

| Questão/risco | Decisão e consequência |
| --- | --- |
| Arquitetura completa versus custo/complexidade | Escolher monólito modular Next.js + Supabase. Backend próprio separado e microserviços acrescentariam operação sem resolver necessidade inicial. Acesso direto irrestrito do browser não atende invariantes transacionais. |
| Lançamento local versus expansão | Cidade inicial é seed/configuração; relacionamentos e URLs já suportam país, estado e município. Não criar catálogo nacional completo agora. |
| Grupo sempre com owner versus owner ativo só na aprovação | Criador é owner designado com vínculo pendente desde o pedido; aprovação ativa o vínculo. Grupo aprovado/suspenso conserva exatamente um owner ativo. |
| Administrador também pode ser solicitante | Aprovar o próprio grupo é proibido inclusive para platform_admin; outro administrador independente decide. Não criar exceção de bootstrap para esse caso. |
| Perfil privado versus seguir unilateralmente | Seguir nunca libera privacidade. Dados pessoais privados são visíveis ao próprio usuário; identidade mínima contextual permanece para organização/interação. Não adicionar solicitações de seguidores ao MVP. |
| Páginas públicas versus mídia revogável | Buckets privados e entrega autorizada; URLs assinadas com vida curta têm janela residual explícita. Não prometer revogação de arquivo já baixado. |
| Compressão client-side versus segurança real | Cliente melhora consumo; servidor valida/normaliza e finaliza upload por autorização restrita, evitando confiar só em MIME ou extensão. |
| Recorrência no MVP versus serviços pagos | Série semanal simples, ocorrências de 28 dias e job SQL nativo, com reposição idempotente após falha/pausa. Sem RRULE completo. |
| Editar série versus preservar inscrições | Modelo afeta somente ocorrências não materializadas; edições já publicadas são explícitas. Troca de dia/hora encerra/cria série e trata antigas sem apagá-las. |
| Confirmação versus presença real | `going` é intenção; `attended/no_show` existem no modelo mas não têm fluxo de escrita de cliente no MVP. North Star não mede presença física. |
| Limite de vagas versus chamadas concorrentes | Lock na corrida e RPC única para transições/capacidade; constraint de par evita duplicação. |
| Feed social versus produto orientado a correr | Home prioriza agenda/corridas; atividades restritas por contexto, agrupadas e deduplicadas. |
| Moderação tardia no roadmap | Autorização e aprovação mínima chegam com os módulos; Gate 10 consolida painel. Beta só após auditoria. |
| Instrumentação tardia versus perda de fatos | Contratos/eventos persistentes entram com operações; Gate 12 entrega análises e funis completos. |
| R$ 0 versus monetização comercial | Gratuidade inicial é restrita às cotas e termos. Hobby não é garantia de hospedagem comercial gratuita; reavaliar antes de exploração comercial e da abertura pública. |
| Free tier versus disponibilidade/backup | Não prometer SLA nem retenção automática; documentar pausa, monitorar consumo e ensaiar backup/restauração em recursos existentes. |
| Exclusão de conta versus histórico/owner | Transferir responsabilidade, remover identidade e mídia, preservar somente referência histórica anonimizada; FKs não apagam domínio em cascata. |
| Regras financeiras/de privacidade mutáveis | Esta especificação fixa comportamento de produto e cita fontes técnicas verificadas; termos e avisos reais são revisados antes do lançamento, sem prometer conformidade legal apenas por ter RLS. |

Decisões como frequência semanal simples, privacidade sem aprovação de seguidores, limites de conteúdo, janela de 28 dias, retenção e escopo de moderator foram acrescentadas para tornar o documento executável. São escolhas desta proposta para aprovação, não fatos que dependem de uma futura conversa para serem definidos.

## 25. Itens explicitamente fora do MVP

- Prisma, Auth.js, Redux e backend separado sem necessidade demonstrada.
- Billing, planos pagos, checkout, comissões, ingressos, divisão de pagamentos e cobrança de grupos profissionais.
- Operação comercial de patrocínios/destaques/CorreHub Pro; apenas preparação conceitual e tipo de grupo.
- E-mail/senha, outros provedores de login, SMS, WhatsApp API, notificações push e campanhas automatizadas.
- Google Maps pago, navegação curva a curva, GPS contínuo, gravação de treinos, rotas/GPX, integração com relógios/Strava e cálculo de pace medido.
- Marcação de presença real/check-in, QR de presença, `attended/no_show` por cliente, ranking, medalhas e `achievement_unlocked`.
- Amizade bilateral, aprovação de seguidores, mensagens privadas, chat de grupo, stories, vídeos, múltiplas imagens e replies em árvore.
- Recorrência arbitrária/RRULE completo, lista de espera, reservas temporárias e inscrições de acompanhantes.
- Aplicativos nativos, funcionamento offline completo, integrações de calendário e motor de recomendação por machine learning.
- APIs/analytics obrigatoriamente pagos, Redis, filas externas, Elasticsearch e microserviços.
- Contadores persistidos prematuros de seguidores, membros, participantes e likes.
- CPF, RG, documentos, endereço residencial, dados de saúde, venda de dados pessoais e usuários fictícios em produção.
- Expansão operacional simultânea para várias cidades; a arquitetura permite expansão, o lançamento continua local.

## 26. Referências e controle de revisão

Fontes oficiais consultadas em 19/09/2026 sustentam limites externos e integração; decisões de produto são desta especificação. Documentação online pode mudar e deve ser reconferida no Gate correspondente.

- [Next.js 16](https://nextjs.org/blog/next-16): versão principal e mudanças de ferramentas.
- [Supabase SSR](https://supabase.com/docs/guides/auth/server-side/creating-a-client?queryGroups=framework&framework=nextjs): integração de sessão e validação de identidade.
- [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security): acesso por linha e relação com papéis.
- [Supabase Storage](https://supabase.com/docs/guides/storage/security/access-control): controle de objetos e operações.
- [Supabase Cron](https://supabase.com/docs/guides/cron): jobs SQL nativos.
- [Supabase Free](https://supabase.com/pricing): cotas e pausa por inatividade.
- [Supabase changelog](https://supabase.com/changelog): consulta de mudanças; o índice `.md` não respondeu nesta pesquisa, sendo usada a página oficial.
- [Vercel Hobby](https://vercel.com/docs/plans/hobby) e [Fair Use](https://vercel.com/docs/limits/fair-use-guidelines): restrição de uso pessoal não comercial.

### Autoverificação desta versão

Revisão integral realizada nesta versão: requisitos centrais presentes; regras de privacidade, owner, recorrência, exclusão e mídia conciliadas; recursos futuros isolados; investimento obrigatório inicial R$ 0; stack sem Prisma/Auth.js/Redux; RLS e testes de autorização centrais; multi-cidade no modelo; Gates 0–17 preservados; ausência de marcadores de conteúdo pendente. Nenhum código de produto, infraestrutura ou serviço foi criado nesta etapa. Comandos de teste de aplicação não se aplicam a esta entrega exclusivamente documental.

**Próximo passo permitido:** revisão e aprovação desta especificação pelo responsável pelo produto. Somente depois elaborar o plano do Gate autorizado. A entrega deste documento não autoriza inicializar Next.js, criar banco/Supabase/GitHub, executar deploy ou implementar features.
