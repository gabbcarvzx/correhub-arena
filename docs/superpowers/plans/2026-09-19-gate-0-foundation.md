# CorreHub Gate 0 — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** estabelecer uma fundação reproduzível, testada e implantável do CorreHub sem implementar features de domínio.

**Architecture:** Um único projeto Next.js 16 com App Router hospeda uma página institucional mínima, tokens semânticos e testes de componente. A organização começa pelos arquivos com responsabilidade real; módulos de domínio e integração com Supabase entram nos Gates correspondentes. GitHub Actions valida os mesmos comandos locais; a Vercel valida primeiro a branch em preview, depois conecta o Git e publica `main` para validação não comercial, sem banco ou credenciais de produção.

**Tech Stack:** Next.js 16, React estável compatível, TypeScript strict, Tailwind CSS v4, ESLint, Vitest, Testing Library, jsdom, npm, Git, GitHub Actions, Supabase CLI e Vercel CLI. shadcn/ui, Lucide, Zod, React Hook Form, `@supabase/supabase-js`, `@supabase/ssr` e Playwright continuam escolhas aprovadas para quando houver componente ou fluxo que os use; não são dependências instaladas neste Gate.

**Spec:** `docs/superpowers/specs/2026-09-19-correhub-mvp-design.md`

## Global Constraints

- A especificação aprovada é a fonte de verdade. Este Gate não cria `cities`, seed, schema, migrations, RLS, Auth, Storage, grupos, corridas, feed, analytics ou outras features dos Gates 1–17.
- Investimento obrigatório **R$ 0**. Sem plano pago, domínio comprado, API paga, add-on, upgrade automático ou segredo de produção em CI.
- Next.js **16**, App Router, TypeScript **strict**, Tailwind CSS **v4**; React estável suportado pela versão efetivamente escolhida de Next.js.
- Paleta inicial: `primary #B7F34A`, `primary-hover #8ED120`, `foreground #151515`, `on-primary #151515`, `background #F8F9F7`, `surface #FFFFFF`, `muted #70756D`, `border #E4E7E1`. Valores vivem somente na definição central de tokens.
- Tokens adicionais `destructive`, `success`, `warning`, `focus`, `disabled` recebem valores durante a execução após cálculo WCAG AA para as combinações de texto/fundo efetivamente usadas.
- Superfície visual simples, mobile first; verificar 360, 390, 430, 768, 1024 e 1440 px. Sem corrida, usuário, grupo ou feed fictício.
- Não usar Prisma, Auth.js ou Redux. Não adicionar contador, serviço, abstração ou diretório de domínio antecipadamente.
- `.env.local` fica fora do Git. `.env.example` não contém valores reais. Jamais criar `NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY`; nenhuma chave privilegiada recebe prefixo `NEXT_PUBLIC_`.
- Git simples: `main`, `feature/...`, `fix/...`, commits pequenos e convencionais. A branch de trabalho deste Gate é `feature/gate-0-foundation`.
- Vercel Hobby somente se o uso de desenvolvimento/validação não comercial for elegível nos termos vigentes. Reavaliar antes de operação comercial; nunca interpretar preview como licença para monetizar.
- Os Gates posteriores terão planos próprios. TDD vale para comportamento; configurações são verificadas por comandos reais. Não inventar testes que apenas repitam a configuração.
- Conduzir execução técnica autonomamente. Intervenção humana apenas para login, OAuth, CAPTCHA, código, consentimento/autorização de conta ou segredo realmente indisponível.

## Review Focus

1. **Versão fora da especificação:** resolver explicitamente `next@16`, rejeitar candidato de outra major/pré-lançamento e registrar Node/React/peers; Task 2 verifica `npm ls` e lockfile.
2. **Build inadvertidamente dependente de Supabase:** com nenhum `.env.local`, `npm run build` e `npm ci` devem passar; Tasks 2, 8 e 11 exercitam isso.
3. **Vazamento de segredo:** `.env.local` deve ser ignorado e um arquivo de ensaio com marcador não pode ser staged; Task 6 verifica `git check-ignore` e `git ls-files` antes do push.
4. **Falso positivo de qualidade:** o teste deve falhar sem a marca/status e passar após a página real; Tasks 4 e 11 executam o teste e os quatro gates de comando.
5. **Preview incorreto ou inacessível:** URL deve servir a landing correspondente à branch, retornar 200 e conter CorreHub, sem erro crítico; Task 10 faz smoke test e Task 11 revalida a versão final.

## Mapa de arquivos previsto

O executor inspeciona a saída de `create-next-app` antes de editar. Este plano escolhe `src/`; se o scaffold produzir `app/` na raiz ou nomes de config diferentes, adaptar os comandos e registrar a correspondência no README, preservando uma única árvore de rotas. Não manter arquivos de exemplo sem função.

| Caminho | Responsabilidade / Task |
| --- | --- |
| `docs/superpowers/specs/2026-09-19-correhub-mvp-design.md` | Fonte aprovada; preservada sem alteração; Tasks 1 e 11. |
| `docs/superpowers/plans/2026-09-19-gate-0-foundation.md` | Este plano; não duplicar no README; Tasks 1 e 11. |
| `.gitignore` | Artefatos Next, Node, testes, `.env*`, `.vercel`, `.local`, exceção explícita `.env.example`; Tasks 1 e 6. |
| `.npmrc`, `.nvmrc` | `save-exact=true`; versão Node LTS escolhida; Task 2. |
| `package.json`, `package-lock.json` | Scripts, versões exatas e instalação reproduzível; Tasks 2, 3, 4 e 7. |
| `tsconfig.json`, `next-env.d.ts`, `next.config.ts`, `postcss.config.mjs` | TypeScript, tipos Next e Tailwind; manter somente se o scaffold efetivamente os gerar/usar; Tasks 2 e 3. |
| `eslint.config.mjs` | ESLint independente do build; Task 3. |
| `vitest.config.ts`, `vitest.setup.ts` | Ambiente jsdom, globals/matchers e resolução; Task 4. |
| `src/app/layout.tsx`, `src/app/page.tsx`, `src/app/globals.css` | Metadata institucional, página mínima e tokens/estilos globais; Tasks 4 e 5. |
| `src/app/page.test.tsx` | Teste real de marca e status; Task 4. |
| `.env.example` | Comentários sobre variáveis futuras, sem valores/credenciais; Task 6. |
| `README.md` | Setup, versões, scripts, estrutura, segurança, custo, workflow e links; Task 6, atualizado em 10. |
| `.github/workflows/ci.yml` | CI em PR/branch, quatro comandos e cache npm; Task 8. |

Sem `lib/`, `components/ui/`, `features/*`, `supabase/`, `vercel.json`, `.env.local` gerado ou config vazia por conveniência. `.vercel/` poderá existir localmente após `vercel link`, mas permanece ignorada. O arquivo `next-env.d.ts` pode ser gerado pelo Next; nunca editá-lo manualmente.

## Pré-condições de execução e política de versões

Execução começa somente após aprovação deste plano. Antes de mutar, conferir `git status`, `git rev-parse --show-toplevel` e arquivos existentes, sem substituir trabalho alheio. Se o diretório já for Git, usar sua `main`; caso contrário, inicializar. Preservar o conteúdo exato da spec aprovada e deste plano. Criar worktree apenas se for necessário isolar trabalho existente; em workspace limpo, branch local é suficiente.

No dia da execução, ler [releases do Node](https://nodejs.org/en/about/previous-releases), [Next 16](https://nextjs.org/docs/app/getting-started/installation), [criação do projeto](https://nextjs.org/docs/app/api-reference/cli/create-next-app), [Tailwind/PostCSS](https://tailwindcss.com/docs/installation/using-postcss), [Vitest com Next](https://nextjs.org/docs/app/guides/testing/vitest) e changelogs pertinentes. Escolher Node LTS ativo que satisfaça os engines do Next 16 e o runtime gratuito da Vercel. Resolver a última patch estável **da major 16**, não `next@latest` se já apontar para outra major. A expressão `16` em `npm view` serve só para descoberta; gravar `X.Y.Z` exato em `package.json`, sem `^` ou `~` para dependências diretas, e confirmar as transitivas no lockfile. Selecionar React/React DOM estáveis na interseção das peer dependencies do Next escolhido; verificar peers de ESLint, Tailwind, Vitest e Vite antes de instalar. Não usar `--force` ou `--legacy-peer-deps` para resolver incompatibilidade. Registrar tabela com versões e motivo no README.

Comandos de descoberta planejados, sem aplicá-los nesta etapa:

```powershell
node --version
npm --version
npm view next@16 version --json
npm view next@16 peerDependencies engines --json
npm view react version --json
npm view react-dom version --json
npm view tailwindcss@4 version --json
npm view vitest version --json
npm view supabase version --json
```

Conforme a [documentação oficial da CLI](https://supabase.com/docs/guides/local-development/cli/getting-started), verificar o pacote npm `supabase` antes de instalar. Instalar CLI como devDependency com versão exata, nunca `npm install -g supabase`. Se comandos ou flags mudarem, consultar `--help` da versão escolhida e registrar a adaptação no README antes de prosseguir. Para GitHub/Vercel, verificar a ajuda da CLI e versão instalada antes das mutações externas; não presumir que as opções de hoje permanecerão estáveis. Nos comandos abaixo, variáveis PowerShell de versão são preenchidas pelo agente com os valores estáveis/compatíveis efetivamente verificados na primeira checkbox da Task correspondente; não são valores a copiar do prompt.

## Decisão Supabase no Gate 0

**Escolha A: preparar somente CLI e documentação.** O shell e a CI não consultam banco, Auth ou Storage. Criar/vincular projeto remoto vazio (B) consumiria uma das vagas do plano Free, geraria credenciais e uma superfície externa sem validação funcional; não melhora o aceite deste Gate. A CLI fixada, o contrato de variáveis e a documentação bastam para o Gate 1 provisionar um único projeto remoto quando puder exercitar migrations/RLS. Nenhum `supabase init`, `supabase link`, projeto remoto, schema, seed ou bucket é criado no Gate 0.

## Tasks

### Task 1: Preservar documentos e iniciar Git/branch

**Files:** criar `.gitignore` mínimo; manter spec e plano como estão.

**Interfaces:** produz `main` com baseline documental e branch `feature/gate-0-foundation`. Não há API de código.

- [ ] Verificar o workspace: `rg --files --hidden -g '!.git'`, `git status --short`, `git rev-parse --show-toplevel`. Se `git status` indicar que não é repositório, usar `git init -b main`; se houver alterações prévias, preservar e isolar antes de continuar. Não apagar arquivos desconhecidos.
- [ ] Registrar hash SHA-256 da spec com `Get-FileHash docs/superpowers/specs/2026-09-19-correhub-mvp-design.md`; este valor será comparado na Task 11. Confirmar presença do plano aprovado.
- [ ] Criar `.gitignore` com conteúdo inicial abaixo antes de `git add`:

```gitignore
node_modules/
.next/
out/
coverage/
.vercel/
.local/
*.tsbuildinfo
.env*
!.env.example
```

- [ ] Confirmar que `main` existe e que não há código anterior a preservar. Staging explícito dos dois documentos e `.gitignore`: `git add .gitignore docs/superpowers/specs/2026-09-19-correhub-mvp-design.md docs/superpowers/plans/2026-09-19-gate-0-foundation.md`; inspecionar `git diff --cached --stat` e `git diff --cached --check`.
- [ ] Criar commit `docs: establish approved CorreHub baseline`; então `git switch -c feature/gate-0-foundation`. Se Git exigir identidade, usar a identidade Git já autorizada/associada à conta, sem inventar dados pessoais.
- [ ] Verificar: `git branch --show-current` devolve `feature/gate-0-foundation`; `git log --oneline -1` mostra o baseline; `git status --short` está vazio.

### Task 2: Resolver versões e criar scaffold mínimo

**Files:** criar/ajustar `.npmrc`, `.nvmrc`, `package.json`, `package-lock.json`, `tsconfig.json`, `next.config.ts`, `postcss.config.mjs`, `next-env.d.ts`, `src/app/layout.tsx`, `src/app/page.tsx`, `src/app/globals.css`; remover assets/textos padrão do scaffold que não serão usados. O teste e a identidade visual final vêm nas Tasks 4–5.

**Interfaces:** produz app Next 16 executável com `/`, tipos e Tailwind v4; Scripts iniciais `dev`, `build`, `start`. Consumo futuro: CI roda `npm ci` e todos os scripts padronizados.

- [ ] Consultar documentação e comandos de versões da seção anterior. Escolher e anotar `NodeVersion`, `NpmVersion`, `NextVersion`, `ReactVersion`, `ReactDomVersion`, `TailwindVersion` e peers efetivos em notas de execução; só avançar com Next major 16 e React estável compatível. Conferir suporte da Vercel ao Node LTS escolhido. Não registrar versões hipotéticas no repo.
- [ ] Com Node/npm escolhidos disponíveis, criar `.npmrc` com `save-exact=true`; criar `.nvmrc` com a versão Node exata, sem prefixo `v`. Executar scaffold **no diretório atual**, preservando `docs/` e Git: `npx --yes create-next-app@16 . --ts --eslint --tailwind --app --src-dir --use-npm --no-turbopack --no-import-alias` somente se essas flags constarem em `npx create-next-app@16 --help` no momento. Se não, selecionar as opções equivalentes interativamente pela CLI, mantendo os diretórios e docs existentes. Confirmar que a CLI não substitui arquivos prévios; caso recuse diretório não vazio, gerar em subdiretório temporário dentro da workspace e copiar apenas os arquivos gerados após inspeção, sem mover/apagar `docs` ou `.git`.
- [ ] Remover texto/imagens padrão do gerador; manter um `/` mínimo que renderiza “CorreHub” e “Em desenvolvimento”, sem função de produto. Usar fonte de sistema. `layout.tsx` define `lang="pt-BR"` e metadata institucional básica; não fingir páginas de corrida.
- [ ] Ajustar versões diretas para as exatas resolvidas. Depois de atribuir às variáveis PowerShell `$NextVersion`, `$ReactVersion`, `$ReactDomVersion`, `$TailwindVersion` e `$TailwindPostcssVersion` os valores verificados, executar `npm install --save-exact "next@$NextVersion" "react@$ReactVersion" "react-dom@$ReactDomVersion"` e `npm install --save-dev --save-exact "tailwindcss@$TailwindVersion" "@tailwindcss/postcss@$TailwindPostcssVersion"`. Usar o mesmo processo para as demais dependências geradas pelo scaffold. Conferir `npm ls --depth=0` e `npm ci` em instalação limpa; interromper em conflito de peers e resolver versão compatível, sem `--force`.
- [ ] No `package.json`, assegurar scripts `dev: next dev`, `build: next build`, `start: next start` e `packageManager` com npm exato. Confirmar `next --version` via `npm exec -- next --version` inicia em 16; `npm run build` passa sem `.env.local`. Capturar saída antes de adicionar configuração extra.
- [ ] `git add` apenas arquivos do scaffold usados, lockfile, `.npmrc` e `.nvmrc`; rever staged files para excluir `.env`, `.next`, assets padrão e segredos. Commit: `chore: scaffold pinned Next 16 application`.

### Task 3: Tornar lint e typecheck independentes

**Files:** ajustar `package.json`, `tsconfig.json` e `eslint.config.mjs` conforme a saída real do scaffold.

**Interfaces:** produz `npm run lint` e `npm run typecheck` sem variáveis de ambiente. Scripts exatos: `"lint": "eslint ."`, `"typecheck": "next typegen && tsc --noEmit"` se `next typegen` existir na versão 16 selecionada.

- [ ] Registrar ausência dos dois scripts ou falha de `npm run lint` / `npm run typecheck` antes da alteração. `tsconfig.json` deve declarar `"strict": true` e incluir os arquivos de tipos gerados pelo Next conforme scaffold, sem relaxar `noEmit`.
- [ ] Verificar `npm exec -- next --help` para `typegen`; se presente, usar a assinatura acima. Se a patch 16 selecionada exigir outra forma, usar a recomendação oficial verificada e registrar no README. Não usar o build como substituto de lint.
- [ ] Configurar ESLint flat config com `eslint-config-next` da mesma versão de Next e presets recomendados pelo scaffold. Evitar warnings conhecidos em código recém-criado e desativação ampla de regras.
- [ ] Executar `npm run lint`, `npm run typecheck`, `npm run build`; esperado exit code 0 em todos, sem `.env.local`. `npm pkg get scripts` mostra comandos. Commit: `chore: enforce lint and strict typecheck`.

### Task 4: Criar teste real da página mínima

**Files:** criar `vitest.config.ts`, `vitest.setup.ts`, `src/app/page.test.tsx`; ajustar `src/app/page.tsx` somente para satisfazer o comportamento testado; ajustar `package.json`/lockfile.

**Interfaces:** produz `npm run test` = `vitest run` e `npm run test:watch` = `vitest`. Teste importa a página padrão `Page(): JSX.Element` (ou inferência React equivalente) e renderiza seu resultado em jsdom.

- [ ] Resolver versões estáveis de `vitest`, `@vitejs/plugin-react`, `jsdom`, `@testing-library/react` e `@testing-library/jest-dom`, conferindo peers com a versão React/Vite escolhida. Atribuir as versões verificadas a `$VitestVersion`, `$ViteReactVersion`, `$JsdomVersion`, `$TestingLibraryVersion` e `$JestDomVersion`; executar `npm install --save-dev --save-exact "vitest@$VitestVersion" "@vitejs/plugin-react@$ViteReactVersion" "jsdom@$JsdomVersion" "@testing-library/react@$TestingLibraryVersion" "@testing-library/jest-dom@$JestDomVersion"`. Não instalar Playwright neste Gate, pois não há fluxo interativo para justificar navegador automatizado em CI.
- [ ] Escrever `vitest.config.ts` com `defineConfig`, `plugins: [react()]`, `test: { environment: 'jsdom', setupFiles: ['./vitest.setup.ts'], include: ['src/**/*.test.tsx'] }`; `vitest.setup.ts` importa `@testing-library/jest-dom/vitest`. Testing Library oferece cleanup automático quando `afterEach` global existe; confirmar isso na versão selecionada e, se necessário, adicionar `afterEach(cleanup)` somente no setup. Ajustar imports à API oficial da versão escolhida. Configurar `test.globals: true` somente se os testes usarem globals; o teste abaixo importa `it` e `expect` de `vitest`.
- [ ] Escrever primeiro `src/app/page.test.tsx` com este comportamento observável:

```tsx
import { render, screen } from '@testing-library/react';
import { expect, it } from 'vitest';
import Page from './page';

it('identifica a fundação do CorreHub', () => {
  render(<Page />);
  expect(screen.getByRole('heading', { level: 1, name: 'CorreHub' })).toBeInTheDocument();
  expect(screen.getByText('Em desenvolvimento')).toBeInTheDocument();
});
```

  Rodar `npm run test -- src/app/page.test.tsx` e confirmar falha antes de adaptar a página; se a página inicial já tiver exatamente o contrato, adicionar primeiro expectativa de status ainda ausente e verificar a falha.
- [ ] Implementar o menor JSX para satisfazer o teste, sem corridas, CTA de confirmação, feed ou contadores. Rodar `npm run test`, `npm run lint`, `npm run typecheck`; todos devem passar. Teste mede copy e semântica que chegarão ao usuário, não a existência trivial de arquivo.
- [ ] Commit: `test: verify foundation landing renders`.

### Task 5: Fixar tokens e validar shell responsiva

**Files:** ajustar `src/app/globals.css`, `src/app/page.tsx` e, se necessário, `src/app/layout.tsx`; sem biblioteca de componentes neste Gate.

**Interfaces:** produz variáveis CSS semânticas `--ch-primary`, `--ch-primary-hover`, `--ch-foreground`, `--ch-on-primary`, `--ch-background`, `--ch-surface`, `--ch-muted`, `--ch-border`, `--ch-destructive`, `--ch-success`, `--ch-warning`, `--ch-focus`, `--ch-disabled`. Tailwind v4 consome os tokens via `@theme inline` (confirmar sintaxe na documentação da versão escolhida).

- [ ] Medir/registrar contraste de pares de uso antes de estilizar: texto padrão em background/surface, muted em surface, on-primary em primary/hover, e estados semânticos em seus fundos. Aplicar fórmula WCAG de luminância relativa e razões mínimas 4,5:1 para texto comum e 3:1 para texto grande/contorno de foco onde aplicável. Escolher os cinco valores adicionais após a medição; se `muted` inicial falhar para texto pequeno no uso proposto, usar token de texto derivado mais escuro, mantendo `muted` da spec como referência cromática. Registrar pares/valores/razões no README. [Critério WCAG](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).
- [ ] Centralizar todos os hexadecimais em `src/app/globals.css`; confirmar com `rg '#[0-9a-fA-F]{6}' src` que nenhum componente contém hex. Expor classes Tailwind por tokens ou `var(--ch-...)`, sem números cromáticos soltos. Usar layout de largura fluida, padding mobile e limite legível desktop.
- [ ] Mostrar somente marca, mensagem e aviso de desenvolvimento; usar superfície/cor como validação visual, sem navegação para páginas inexistentes. Conferir visualmente 360, 390, 430, 768, 1024 e 1440 px: texto completo, sem overflow horizontal, foco legível e contraste. Corrigir na mesma Task se falhar.
- [ ] Rodar `npm run test`, `npm run lint`, `npm run typecheck`, `npm run build`; esperado zero falhas. Commit: `style: establish CorreHub tokens and responsive shell`.

### Task 6: Documentar operação local e proteger variáveis

**Files:** criar `.env.example` e `README.md`; revisar `.gitignore`. Nenhum `.env.local` é criado porque o Gate 0 não exige variável.

**Interfaces:** README define setup `npm ci`, `npm run dev`, `npm run lint`, `npm run typecheck`, `npm run test`, `npm run test:watch`, `npm run build`, Node/npm escolhidos, estrutura real, workflow `main`/`feature/...`/`fix/...`, R$ 0, links relativos para spec/plano e estratégia de variáveis. Gate 1 poderá adicionar as variáveis públicas Supabase quando tiver projeto real.

- [ ] Escrever `.env.example` apenas com comentários: `# Gate 0 não requer variáveis de ambiente.` e `# Gate 1 documentará URL e chave publicável do Supabase após provisionamento.` Não inserir chaves, URLs, strings que pareçam credenciais nem variável de service role pública.
- [ ] Escrever README conciso com o que é CorreHub, aviso de fundação sem funcionalidades, tabela de versões exatas da Task 2/4, comandos e saídas esperadas, diretórios existentes, práticas de branch/commit, setup Node/npm, fluxo de PR/CI, custo/limites gratuitos e links para spec/plano. Documentar que env local fica em `.env.local` ignorado, que browser só pode usar chave publicável e que segredo privilegiado é server-only quando existir. Explicar ausência deliberada de Supabase remoto no Gate 0.
- [ ] Verificar ignore com arquivo local de ensaio criado e removido nesta Task: escrever `.env.local` contendo apenas `CORREHUB_IGNORE_TEST=1`; `git check-ignore -v .env.local` deve apontar `.gitignore` e `git status --short --untracked-files=all` não deve listá-lo; remover com `Remove-Item -LiteralPath .env.local`. Antes de qualquer `git add`, confirmar `git ls-files .env.local` vazio. Não usar segredo real no ensaio.
- [ ] Conferir `git diff --check`, procurar `NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY` somente como proibição na documentação e varrer arquivos tracked em busca de tokens/URLs privadas sem imprimir valores. `npm ci` e `npm run build` continuam passando sem env.
- [ ] Commit: `docs: document zero-cost local workflow and env policy`.

### Task 7: Preparar a ferramenta Supabase, sem projeto remoto

**Files:** ajustar `package.json`, `package-lock.json`, `README.md`.

**Interfaces:** produz CLI local reproduzível para Gate 1; nenhum arquivo `supabase/` ainda.

- [ ] Consultar [documentação oficial da CLI](https://supabase.com/docs/guides/local-development/cli/getting-started), changelog e `npm view supabase version engines --json`; confirmar nome do pacote npm e compatibilidade com Node escolhido. Atribuir a versão estável verificada a `$SupabaseCliVersion` e instalar: `npm install --save-dev --save-exact "supabase@$SupabaseCliVersion"`.
- [ ] Executar `npm exec --no -- supabase --version` e `npm exec --no -- supabase --help`; registrar versão no README. Repetir `npm ci` e comando de versão para provar lockfile.
- [ ] `rg --files supabase` deve não encontrar pasta; conferir que `supabase` não foi inicializado/vinculado, que não há SQL/migration/seed, URL ou secret novos, e que quatro scripts de qualidade continuam independentes da CLI.
- [ ] Commit: `chore: pin Supabase CLI for Gate 1`.

### Task 8: Criar CI gratuito sem secrets

**Files:** criar `.github/workflows/ci.yml`; ajustar README apenas se a documentação dos checks mudar.

**Interfaces:** workflow `CI` em `pull_request` para `main` e `push` para `feature/**`, `fix/**`, `main`; job `quality` em `ubuntu-latest` com permissões `contents: read`. Instala Node escolhido, cache npm pelo lockfile, `npm ci`, lint, typecheck, test e build. Nenhuma variável Supabase/Vercel/GitHub secret no job.

- [ ] Antes do arquivo, confirmar localmente `npm ci`, `npm run lint`, `npm run typecheck`, `npm run test`, `npm run build` em sequência sem `.env.local`; saída esperada exit code 0. Esta é a baseline que CI deve reproduzir.
- [ ] Conferir versões estáveis/majors de `actions/checkout` e `actions/setup-node` nas fontes oficiais e usar referências fixas da major verificada ou SHA de commit revisado. Escrever workflow nesta forma, substituindo as referências apenas se as versões oficiais mudarem:

```yaml
name: CI
on:
  pull_request:
    branches: [main]
  push:
    branches: [main, 'feature/**', 'fix/**']
permissions:
  contents: read
jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version-file: .nvmrc
          cache: npm
      - run: npm ci
      - run: npm run lint
      - run: npm run typecheck
      - run: npm run test
      - run: npm run build
```

- [ ] Conferir sintaxe YAML, `node-version-file`, lockfile e permissões. A escolha exata de action deve ser verificada no dia da execução; `v4` acima é esqueleto de contrato, não dispensa verificação. `npm ci` deve falhar se lockfile e manifest divergirem. Não incluir Playwright, Docker, banco ou secrets.
- [ ] Verificar `git diff --check`, repetir scripts locais e commit: `ci: validate foundation on branches and pull requests`. Confirmação de execução remota ocorre na Task 9.

### Task 9: Criar repositório privado e validar CI no GitHub

**Files:** nenhum arquivo obrigatório; README recebe URL remota somente se acrescentar valor e sem duplicar spec.

**Interfaces:** produz `origin` privado da conta autorizada, branch `main`, branch `feature/gate-0-foundation`, PR revisável e checks de CI. Não cria organização.

- [ ] Verificar `gh --version`, `gh auth status`, `gh repo create --help`, `gh pr create --help`. Se `gh` faltar no Windows, instalar a CLI gratuita com `winget install --id GitHub.cli -e --source winget`, reabrir o processo de shell se PATH exigir e repetir. Confirmar identidade da conta autorizada antes de mutação. **Human authorization boundary:** se `gh auth status` não tiver sessão, o agente inicia `gh auth login`; apenas a conclusão do login/OAuth/código no navegador pelo usuário é humana. Depois, agente retoma `gh auth status` e passos seguintes.
- [ ] Verificar colisão de nome na conta autenticada: `gh repo view correhub --json name,owner,visibility,url`. Se existir repositório `correhub` autorizado e compatível, inspecionar branches/remotes antes de conectar. Se nome estiver ocupado por repositório não reutilizável, parar apenas a criação remota e solicitar ao usuário decisão mínima de nome; não inventar sufixo. Continuar documentação/verificações locais independentes enquanto aguarda.
- [ ] Para repo ausente, usar `gh repo create correhub --private --source . --remote origin` após conferir ajuda da versão instalada. `git push -u origin main`; `git push -u origin feature/gate-0-foundation`. Se o baseline `main` não contiver workflow, isso é esperado; CI roda na branch de feature e no PR.
- [ ] Criar PR: escrever em `.local/pr-body.md` um texto curto que descreva shell fundacional, testes, scripts e CI, sem secrets; executar `gh pr create --base main --head feature/gate-0-foundation --title "chore: establish CorreHub Gate 0 foundation" --body-file .local/pr-body.md --draft`. O diretório `.local/` é ignorado; criar diretório via `New-Item -ItemType Directory -Force -Path .local` e remover o arquivo com `Remove-Item -LiteralPath .local/pr-body.md` após o comando. Não fazer merge nesta Task.
- [ ] Executar `gh repo view --json visibility,url,defaultBranchRef`, `git remote -v`, `git ls-remote --heads origin main feature/gate-0-foundation`, `gh pr checks --watch` (ou `gh run watch` do workflow encontrado com `gh run list`); exigir `quality` verde para HEAD do PR. Se Actions estiver desabilitado por configuração/limite, inspecionar e habilitar apenas opção gratuita autorizada; não comprar minutos. Corrigir falhas e fazer commit `fix: repair foundation CI` somente se houver defeito concreto.

### Task 10: Conectar Vercel Hobby e validar preview

**Files:** atualizar `README.md` com URL real e procedimento de verificação; `.vercel/` permanece ignorada.

**Interfaces:** projeto Vercel vinculado ao repositório privado e preview do branch; a URL documentada serve a página de fundação sem depender de Supabase.

- [ ] Exigir Task 9 com código local saudável e CI verde. Verificar termos atuais do [Hobby](https://vercel.com/docs/plans/hobby) e [Fair Use](https://vercel.com/docs/limits/fair-use-guidelines): desenvolvimento/validação pessoal não comercial deve ser elegível. Se não for, não criar projeto nesse plano e registrar motivo; escolher alternativa gratuita compatível em revisão separada, sem pagar ou prometer deploy.
- [ ] Verificar `vercel --version`, `vercel whoami`, `vercel --help`, `vercel link --help`, `vercel git connect --help`, `vercel deploy --help`; se CLI faltar, consultar `npm view vercel version engines --json`, atribuir versão verificada a `$VercelCliVersion` e instalar CLI sem modificar dependências do app com `npm install --global "vercel@$VercelCliVersion"`. **Human authorization boundary:** se a sessão Vercel não existir, o agente inicia `vercel login`; o usuário completa apenas OAuth/código/consentimento indispensável; agente retoma `vercel whoami`.
- [ ] Criar/vincular projeto **`correhub`** na conta pessoal autorizada com `vercel link` e confirmar plano Hobby, diretório raiz e framework Next.js; não comprar domínio, habilitar add-on ou copiar env de produção. Se projeto homônimo já existir, inspecionar associação e reutilizar somente se for o projeto autorizado; não sobrescrever outro projeto. **Ainda não conectar GitHub ao projeto Vercel:** `main` contém somente o baseline documental e um build automático dela falharia. A conexão Git ocorre na Task 11, depois do merge.
- [ ] Fazer preview da branch com `vercel deploy --yes` (verificar flags da versão instalada), sem `--prod`; capturar a URL retornada sem imprimir env. Confirmar que o projeto não recebeu variáveis desnecessárias nem domínio pago. Se deployment protection exigir autenticação, usar sessão autorizada para smoke test; uma URL de preview protegida não é evidência de erro de build.
- [ ] Fazer `Invoke-WebRequest` à URL ou navegador autenticado conforme proteção: HTTP 200, título HTML e corpo com CorreHub/status, sem resposta de erro de runtime. Inspecionar deployment/logs sem imprimir secrets. Registrar URL real, branch, data e finalidade não comercial no README; `git add README.md`, commit `docs: record validated Vercel preview`, push e aguardar novo check do PR. Se o novo commit gerar preview diferente, atualizar somente a evidência final na entrega sem criar ciclo infinito de commits de URLs.

### Task 11: Auditoria final, integração e entrega do Gate

**Files:** corrigir somente arquivos com falha identificada; não adicionar feature. A documentação final do Gate é README + spec + plano e evidência na entrega/PR.

**Interfaces:** resultado revisável em PR, integração dos commits em `main` após checks, GitHub/Vercel conectados, URL de preview e deploy da `main` verificados. O merge mantém histórico dos commits pequenos.

- [ ] Rodar obrigatoriamente, nesta ordem, em workspace sem `.env.local`:

```powershell
npm run lint
npm run typecheck
npm run test
npm run build
git status
git log --oneline
```

- [ ] Confirmar Node/Next/React/Tailwind/Supabase CLI a partir de `npm ls --depth=0`, `.nvmrc`, `package-lock.json`; `tsconfig.json` com strict; CSS com oito tokens da spec e cinco adicionais testados; shell em viewports e teste de marca/status passando. `npm ci` em instalação limpa e build sem env devem continuar verdes.
- [ ] Confirmar `git check-ignore -v .env.local`, `git ls-files .env.local`, `git ls-files .vercel`, `git status --short`, busca de segredos nos arquivos versionados e hash SHA-256 da spec igual ao capturado na Task 1. Conferir que não existem migration, schema de domínio, usuário ou corrida fictícia. Não imprimir valores de env em logs/evidências.
- [ ] Em GitHub, `gh repo view --json visibility,url`, `git ls-remote --heads origin main feature/gate-0-foundation`, `gh pr checks --watch`; exigir HEAD do PR e CI verde. Em Vercel, reabrir URL do preview, HTTP 200 e texto esperado, sem erro crítico. Corrigir falhas na branch e repetir os comandos/checks antes de integração. Se Supabase remoto não foi criado, registrar explicitamente “CLI local preparada; projeto remoto inexistente; nenhuma migration”.
- [ ] Após CI e preview aprovados, executar `gh pr ready` e `gh pr merge --merge --delete-branch` se a política real do repositório permitir merge. Usar `--merge` para preservar commits pequenos; não fazer bypass de regras de branch. Atualizar `main` local com `git switch main` e `git pull --ff-only origin main`, confirmar que `package.json` e app estão presentes e CI de `main` verde com `gh run list`/`gh run watch`.
- [ ] Agora conectar projeto Vercel ao repositório privado via `vercel git connect` com `origin` validado. **Human authorization boundary:** se Vercel/GitHub exigir consentimento OAuth de integração, o usuário aprova apenas acesso ao repositório correto; o agente verifica associação e continua. Verificar o deployment não comercial da `main` criado pela integração; se integração não disparar automaticamente, executar `vercel deploy --prod --yes` depois de conferir `--help`. Usar apenas subdomínio gratuito e confirmar URL estável, HTTP 200, título/status e ausência de erro crítico. Não habilitar faturamento, add-on ou operação comercial.
- [ ] Registrar URL estável de validação e URL de preview no README, sem credenciais. Commit `docs: record validated foundation deployment` em `main`, push e esperar CI/deploy desse HEAD. Testar URL estável novamente; isso não exige alterar README a cada URL de deployment imutável. `git status --short` deve estar vazio; `git log --oneline` deve conter commits coerentes. Corrigir qualquer falha, repetir checks e não declarar Gate 0 concluído com falha ou dependência paga.

## Human authorization boundary

| Momento possível | Motivo inevitável | Ação mínima do usuário | Retomada do agente |
| --- | --- | --- | --- |
| Task 9, somente se `gh auth status` falhar | GitHub requer prova de posse da conta | Concluir login/OAuth/código iniciado pelo agente | Verificar conta, criar repo privado, origin, push, PR e CI. |
| Task 9, somente se `correhub` estiver ocupado e não puder ser reutilizado | Nome preferido exige decisão do dono | Informar nome alternativo ou autorizar reutilização do repo identificado | Aplicar exatamente a decisão, sem criar organização. |
| Task 10, somente se `vercel whoami` falhar | Vercel requer autenticação | Concluir login/OAuth/código iniciado pelo agente | Vincular projeto e fazer preview. |
| Task 11, somente se Git integration pedir consentimento | Vercel precisa acesso ao repo privado correto | Aprovar autorização OAuth do repo/conta exibidos | Confirmar conexão e deploy. |

Supabase CLI não requer login no Gate 0; nenhum login Supabase deve ser iniciado. Falha de network/instalação é problema técnico do agente, não tarefa ao usuário. Em todas as fronteiras, primeiro concluir trabalho local independente e tentar sessões existentes. O agente executa todos os comandos e configurações após a autenticação.

## Critérios de aceite e evidência exigida

- [ ] Next.js 16 funcionando: `npm exec -- next --version` mostra major 16; build e preview servem `/`.
- [ ] TypeScript strict: `tsconfig.json` declara `strict: true`; `npm run typecheck` verde.
- [ ] Tailwind v4: versões de `tailwindcss`/PostCSS fixadas e estilos visíveis no build/preview.
- [ ] Tokens do CorreHub centralizados: oito valores da spec e cinco semânticos adicionais somente em `globals.css`; contraste registrado.
- [ ] Shell responsiva mínima: inspeção em 360, 390, 430, 768, 1024, 1440 px sem overflow ou UI falsa.
- [ ] Teste real passando: teste da marca e status falhou antes da implementação e passa após, usando Testing Library.
- [ ] Lint passa: saída de `npm run lint`.
- [ ] Typecheck passa: saída de `npm run typecheck`.
- [ ] Tests passam: saída de `npm run test`.
- [ ] Build passa: saída de `npm run build` sem env Supabase.
- [ ] `.env.local` ignorado: `git check-ignore -v .env.local` e `git ls-files .env.local` vazio.
- [ ] `.env.example` sem secrets: diff inspecionado, somente comentários.
- [ ] Nenhum segredo versionado: staged/tracked inspecionados antes do push, sem chave privada ou token.
- [ ] Git inicializado: `git rev-parse --show-toplevel` e branches corretas.
- [ ] Commits coerentes: `git log --oneline` com fronteiras das Tasks.
- [ ] GitHub remoto privado criado/conectado, quando autorização necessária estiver concluída: `gh repo view`, PR e refs remotas; `main` contém o app validado.
- [ ] CI validada: check `quality` verde no HEAD do PR, sem secrets.
- [ ] Tooling do Supabase preparado: versão CLI via lockfile e `npm exec --no -- supabase --version`.
- [ ] Nenhuma migration de domínio antecipada: não há `supabase/`, SQL ou seed.
- [ ] Vercel conectada e deploy validado, quando autorização necessária estiver concluída e Hobby elegível: preview e URL estável da `main` com HTTP 200 e shell correto.
- [ ] Documentação atualizada: README com versões, setup, scripts, custos, URLs e links; spec sem alteração.
- [ ] Nenhum recurso dos Gates 1–17 implementado: revisão de arquivos/rotas/dependências.
- [ ] Custo obrigatório permanece **R$ 0**: contas Free/Hobby elegíveis, cotas e ausência de compras/add-ons documentadas.

## Commits planejados

1. `docs: establish approved CorreHub baseline` — spec/plano e ignore, em `main`.
2. `chore: scaffold pinned Next 16 application` — branch `feature/gate-0-foundation`.
3. `chore: enforce lint and strict typecheck`.
4. `test: verify foundation landing renders`.
5. `style: establish CorreHub tokens and responsive shell`.
6. `docs: document zero-cost local workflow and env policy`.
7. `chore: pin Supabase CLI for Gate 1`.
8. `ci: validate foundation on branches and pull requests`.
9. `docs: record validated Vercel preview` — somente após existir URL real.
10. `docs: record validated foundation deployment` — `main`, após merge e URL estável reais.

Commits `fix: ...` só aparecem em resposta a falha concreta, com teste/check reexecutado. O plano não pede commit único no fim nem commit/merge antecipado nesta etapa de escrita. Na futura execução autorizada, o PR e seu CI/preview são revisados antes de integrar `main`.

## Referências técnicas para conferir durante execução

- [Next.js instalação](https://nextjs.org/docs/app/getting-started/installation), [create-next-app](https://nextjs.org/docs/app/api-reference/cli/create-next-app), [Vitest](https://nextjs.org/docs/app/guides/testing/vitest).
- [Tailwind v4 com PostCSS](https://tailwindcss.com/docs/installation/using-postcss), [shadcn/ui para Next.js](https://ui.shadcn.com/docs/installation/next) — shadcn entra quando houver componente que o use.
- [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started), [Supabase Free](https://supabase.com/pricing).
- [GitHub CLI repo create](https://cli.github.com/manual/gh_repo_create), [GitHub Actions e cobrança](https://docs.github.com/en/billing/concepts/product-billing/github-actions).
- [Vercel CLI link](https://vercel.com/docs/cli/link), [Git integration](https://vercel.com/docs/cli/git), [deploy](https://vercel.com/docs/cli/deploy), [Hobby](https://vercel.com/docs/plans/hobby).

**Estado deste plano:** pronto para revisão. Nenhuma Task foi executada ao escrevê-lo. A execução começa somente após a aprovação humana deste documento.
