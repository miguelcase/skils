# Anatomia da Central do Cliente

Checkout compartilhado com o Codex em `~/Documents/Codex/2026-07-09/va/work/central-cliente`.
**Não trabalhe nele.** Crie worktree fora dessa árvore.

**Mas entenda o limite desse isolamento.** Um `git worktree` é *linked*: o `.git` do worktree é um
arquivo apontando para `.../Codex/.../central-cliente/.git/worktrees/<nome>`. Objetos, refs e
`info/exclude` continuam **dentro da árvore do Codex** — e os `node_modules` symlinkados também. O que
fica isolado é só o *working tree*. Se o Codex apagar ou mexer naquele diretório, o worktree quebra
junto. Isolamento de verdade exigiria clone separado com install próprio.

## Os seis arquivos-hub

Medido em 11/08/2026 sobre os achados abertos: 49 de 59 itens formavam **um único componente
conectado**, preso por estes seis arquivos. Quem planeja lote precisa saber disso, porque é o que
decide se duas frentes podem correr em paralelo.

| Arquivo | Itens que o tocavam |
|---|---|
| `apps/api/src/routes/tarefas.ts` | 12 |
| `apps/web/lib/api.ts` | 11 |
| `apps/web/app/cliente/[id]/PainelDados.tsx` | 10 |
| `apps/api/src/routes/webhooks.ts` | 9 |
| `apps/web/app/cliente/[id]/ClientDashboard.tsx` | 8 |
| `apps/api/src/routes/painel.ts` | 7 |

**Regra prática:** um arquivo-hub tem um dono serial por vez. Quem cruza só abre PR depois do merge
do dono. Ignorar isso produz conflito semântico no maior arquivo do projeto.

`apps/web/lib/api.ts` é compartilhado e não tem como ter dono único. Regime: função ou tipo **novo**
entra no fim do arquivo; cada frente só altera o corpo das funções que lhe cabem; ninguém reordena,
renomeia ou roda formatador no arquivo inteiro.

## O que a medição de produção já estabeleceu

Não refaça este trabalho. Está em `docs/superpowers/plans/evidencia/` na branch
`melhorias/revisoes-central-e-indices`.

**A Central não tem problema de indexação.** As tabelas mais varridas sequencialmente são minúsculas
— `contas` 2 páginas, `clientes` 5, `alertas` 8, `usuarios` 2, `conta_estado` 1 — e índice não acelera
tabela que cabe em duas páginas. As duas maiores, `metricas_diarias` (38 páginas) e `pendencias` (172),
vivem em cache: `metricas_diarias` lê **71 blocos de disco contra 9,9 milhões de acertos**. Seis
candidatos foram criados e medidos em produção: o planner ignorou cinco, e o sexto foi usado sem ganho.

**Os dois gargalos reais, ambos de padrão de acesso:**

1. **A home dispara ~185 requisições por ciclo de 15 segundos.** São dois 1+N encadeados, não um:
   `listClientes()` busca a lista e o detalhe de cada cliente; `listAlertas()` sem `clienteId`
   **reexecuta a `listClientes()` inteira** e soma mais N. Os hooks são independentes e o `apiFetch`
   não tem cache. Explica os 430 mil `seq_scan` em `contas` (78 linhas, 2 páginas).

2. **As rotas de tarefas gastam ~90% do tempo compilando, não executando.** São duas rotas com
   números próprios:

   | Rota | Com JIT | Com `jit = off` | Fração que é compilação |
   |---|---|---|---|
   | `GET /api/tarefas/minhas` | 65 ms | **5,8 ms** | ~91% |
   | `GET /api/tarefas/projetos/:id` | 64 ms | **2,8 ms** | ~96% |

   O planner estima 1.723 linhas onde existem 130, e o custo passa do `jit_above_cost` padrão de
   100.000. Depois do `ANALYZE` aplicado em produção em 11/08, o custo caiu para **~170 mil** (era
   ~218 mil), mas segue 1,7× acima do limiar e **o JIT continua disparando**. Como `pg.Pool.query`
   usa statement não-nomeado, **replaneja e re-JITa a cada request**. `ANALYZE` não resolve porque o
   erro é de seletividade de `OR` com `EXISTS`. As saídas: reescrever o `OR` como `UNION`, subir
   `jit_above_cost`, ou `jit = off` na conexão.

## Tabelas que importam

`central.pendencias` é a única com tamanho real (172 páginas, ~3.400 linhas). As outras quentes
(`contas`, `clientes`, `alertas`, `usuarios`, `conta_estado`) têm de 1 a 8 páginas.

**Duas features entregues e não usadas:** `tarefa_corresponsaveis` e `tarefa_projeto_itens` estão
vazias em produção. Co-responsável e tarefa-em-vários-projetos foram construídos, revisados e
ninguém adotou.

## Import do Asana

3.084 tarefas importadas, **729 sem projeto e sem cliente**. Classificadas: 69 internas, 40 com
cliente identificável, 620 ambíguas.

**Elas não são consertáveis por SQL**, e o mecanismo exato importa para não procurar no lugar errado.
O import **casa** o nome do projeto do Asana contra os projetos da Central e, quando casa, **persiste
o vínculo derivado** (`projeto_id` e `cliente_id`, em `import-asana.ts:215-220`). O que nunca é
persistido é o **texto cru** do nome do projeto: não existe coluna para ele em `central.pendencias`.
Quando o nome **não** casa, ele aparece só no relatório de retorno (`projetos_sem_par`) e num
`request.log.warn` que fica em **`routes/webhooks.ts:573`**, não no `import-asana.ts` — e some dali.

Por isso corrigir o casamento de nome conserta o fluxo daqui pra frente, não o passivo.

**E tentar resolver por texto é perigoso, não só insuficiente:** casamento automático sobre título e
descrição acertaria 2 de 16, porque as descrições que citam cliente são atas de reunião listando
vários de uma vez. Um algoritmo mecânico atribuiria 13 tarefas ao cliente errado, escolhido por ser
o primeiro da lista.

## Deploy e CI

São **três** workflows, e os detalhes abaixo mudam decisão de planejamento.

**`ci.yml`** roda em `pull_request` **sem filtro de path nenhum** — todo PR roda o CI inteiro, mesmo
um que só toque `docs/`. No push para `main` o filtro existe e são quatro paths: `apps/**`,
`.github/workflows/ci.yml`, `pnpm-lock.yaml`, `pnpm-workspace.yaml`.

E ele tem **dois jobs em paralelo**, não um:

| Job | O que faz |
|---|---|
| `api` | `pnpm install --frozen-lockfile`, `pnpm --filter @case-central/api build` (typecheck), depois `pnpm --filter @case-central/api test` |
| `web` | install, `pnpm --filter @case-central/web build` com `NEXT_PUBLIC_USE_MOCK=true` — o que dá typecheck, lint e build de uma vez |

Node 24 e pnpm 11.7.0 via corepack. **Isso importa para a trava 3:** o `tsc` local cobre o portão de
tipos dos dois jobs, mas nunca o do `vitest`.

**`deploy-firebase.yml`** publica o front, e dispara em push na `main` com **seis** paths, não só
`apps/web/**`: mais `firebase.json`, `.firebaserc`, `pnpm-lock.yaml`, `pnpm-workspace.yaml` e o próprio
workflow. **Mexer só no `pnpm-lock.yaml` já publica o front.** Aceita `workflow_dispatch`, e tem
`concurrency` com `cancel-in-progress: true` — dois merges seguidos cancelam o deploy mais velho.

**`pages.yml`** é o que ninguém deve apertar por engano. Publica o front no GitHub Pages com
`NEXT_PUBLIC_USE_MOCK=true`, numa instância **pública e sem autenticação**, com dados mock que incluem
e-mails do time. Hoje só tem `workflow_dispatch` (o gatilho de push foi desabilitado na revisão de
segurança M15, em julho de 2026), então não dispara sozinho. Mas o botão existe.

**Backend não sobe por workflow nenhum.** Exige rebuild da imagem `case-central-api` pelo Codex.
