# Fluxos n8n na Case

O n8n é self-hosted na VPS (`n8n-main`, `n8n-worker`, `n8n-postgres`). Ele orquestra o que alimenta a
Central e o que fala com as plataformas de anúncio e CRM.

## A regra de segredo que vale mais que todas

**Nunca passe segredo por item.** O `execution_data` do n8n grava o payload **em claro**, com
retenção longa. Um token que atravessa nós vira histórico permanente legível por quem tem acesso ao
banco do n8n.

O padrão certo: a chamada de saída acontece **dentro da API**, que lê o segredo do próprio ambiente.
O n8n dispara e passa identificadores, não credenciais.

## O verde mentiroso

Um nó pode terminar verde e não ter feito nada. Dois modos já observados:

1. **Erro sem `statusCode`** passa por checagem de `statusCode` sem disparar o ramo de erro.
2. **`.output(1)` não gera conexão** e não reclama. Saída de erro é `.onError()`. Conte as arestas
   antes de publicar.

Regra: **antes de dar um fluxo por pronto, execute e leia a execução**, não o canvas.

## O SDK preserva o que o aviso diz que perde

`update_workflow` **preserva** credenciais de nó HTTP, apesar do aviso "skipped" sugerir o contrário.
Mas reescrever pelo SDK **perde parâmetro** que não foi declarado. Só dá para provar executando.

Mantenha um rascunho como rede de segurança antes de publicar por cima de um fluxo que funciona.

## O status que vem de ontem

`get_execution` do MCP **serve status em cache**. Ele ja devolveu `running` com `runData` vazio para
uma execucao que tinha terminado com sucesso minutos antes. Quem serve status fresco e
`search_executions`. Um agente perdeu uma rodada inteira concluindo que duas execucoes tinham
travado por disputa com o cron; elas tinham dado certo.

**Regra:** confirme conclusao pelo `search_executions`, e so entao leia o conteudo com `get_execution`.

## A credencial que o create atribui pela metade

`create_workflow_from_code` liga credencial em alguns nos HTTP e nao em outros, e
`autoAssignedCredentials: []` sai **identico** nos dois casos. Um fluxo derivado de outro funcional
veio com 2 de 3 nos autenticados; o terceiro deu `403 (#200) Provide valid app ID` em 69 de 69
contas, com o no verde por causa do `neverError`.

Credencial generica (`httpQueryAuth`) **nao e atribuivel pela API** nesta instancia. O caminho que
funciona e nao criar fluxo novo: **rode no rascunho do fluxo existente**, porque `update_workflow`
preserva credencial por nome de no, `execute` manual roda o rascunho, e a versao publicada segue
intocada. Restaure o rascunho depois e prove pelo **diff** contra a `activeVersion`: o `versionId`
nunca volta a bater, porque todo update cunha id novo.

## A guarda que a restauracao leva junto

Guarda de tamanho, de sanidade ou de log que voce poe no rascunho para uma operacao pontual **morre
quando o rascunho e restaurado**, que e justamente o que se quer no fim da operacao. Se a guarda
deveria valer para sempre, ela tem que entrar por publicacao, nao por rascunho. Vale checar depois:
a protecao que voce lembra de ter escrito pode nunca ter existido em producao.

## Assinatura de webhook

As rotas de ingest da Central são protegidas por HMAC com anti-replay em aceite duplo:
`X-Case-Timestamp` assinando `ts.body` numa janela de 5 minutos. Sem o header, é modo legado —
existe para não quebrar braços antigos do n8n.

Ao criar braço novo, **assine com timestamp desde o começo**. A flag
`WEBHOOK_REQUIRE_TIMESTAMP=1` fecha o modo legado, e ela só pode ser ligada quando todos os braços
tiverem migrado.

## Cron que não se pode atropelar

| Job | Quando |
|---|---|
| Anomalias de gasto | diário, **10h** |
| Relatórios semanais | **segunda, 7h** |
| Health check da Central | a cada 5 min |

Migration e restart de API não devem cair em cima dessas janelas.

## O que costuma quebrar em silêncio

- **Ingest que descarta métrica sem log.** Já foi causa raiz de "cliente sem métrica" que ninguém
  percebia. Ao escrever handler de ingest, garanta contador ou log no caminho de descarte.
- **Dedupe por data em fuso errado.** `slice(0,10)` de ISO em UTC vira o dia seguinte depois das 21h
  de Brasília. Use a data vinda do Postgres com timezone de São Paulo.
- **Agregado derivado derrubando o ingest.** Reagregação sem `try/catch` faz uma venda falhar por
  causa de um agregado. Ingest de venda não pode cair por causa de derivado.
- **Workflow schedule-only não executa manualmente pelo CLI.** Para validar, chame o HTTP exato com
  timestamp e HMAC.

## Conversões offline

O padrão da Case liga CRM a plataforma de anúncio em dois workflows: um enriquece o lead com IDs de
clique e UTMs no submit do formulário; outro dispara a conversão quando o negócio muda de fase
(Lead Qualificado e Venda). Suporta RD Station, HubSpot, Pipedrive, Kommo e o caso genérico via
Sheets ou webhook.

O gargalo recorrente não é técnico: é acesso. Token de System User no BM do Meta, Developer Token do
Google Ads, chave de aplicação da Loja Integrada. Levante isso **antes** de prometer prazo.
