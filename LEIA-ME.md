# Pacote do Claude Code (08/10/2026)

Skills, plugins e MCPs do Claude Code do Miguel, prontos para instalar em outra conta.
Nenhum token, senha ou login viaja aqui dentro.

## Instalar

Com o Claude Code já instalado e logado na conta de destino:

```bash
cd pacote-claude-2026-10-08
./instalar.sh
```

O script copia as skills, instala os 2 plugins e cadastra os MCPs. Ele não sobrescreve
nada: o que já existir com o mesmo nome é mantido. Pode rodar mais de uma vez.

Opções:

| Opção | O que faz |
|---|---|
| `--plugins-do-app` | instala também os 6 plugins da Anthropic (ver abaixo) |
| `--sem-plugins` | pula os plugins |
| `--sem-mcp` | pula os MCPs |

Depois de rodar: reinicie o Claude Code e use `/mcp` para entrar no tactiq e no n8n.

## O que tem dentro

### `skills-claude-code/` (24 skills, vão para `~/.claude/skills`)

| Skill | Para quê |
|---|---|
| `01-recon-osint` a `19-grc-compliance` | 19 skills de segurança (reconhecimento, vulnerabilidades, resposta a incidente, nuvem, logs, GRC e outras) |
| `brag` e `brag-slim` | vídeo curto de lançamento a partir de um projeto ou site |
| `case-engenharia` | como trabalhar no código e na infra da Case sem quebrar produção |
| `find-skills` | descobrir e instalar skills |
| `playwright-skill` | automação de navegador com Playwright |

A `playwright-skill` vai sem a pasta `node_modules` (18 MB). Na primeira vez, rode
`npm run setup` dentro da pasta dela; o script lembra disso no final.

### `plugins/claude-code/` (2 plugins)

| Plugin | Versão | Origem |
|---|---|---|
| `superpowers` | 6.2.0 | github.com/obra/superpowers (marketplace `superpowers-dev`) |
| `codex` | 1.0.6 | github.com/openai/codex-plugin-cc (marketplace `openai-codex`) |

O instalador baixa os dois do repositório oficial, então a versão instalada pode ser mais
nova que a daqui. As pastas ficam no pacote só como cópia de referência. O `codex` precisa
do Codex CLI instalado e logado na máquina; rode `/codex:setup` para conferir.

### Plugins da Anthropic (não vão em cópia)

`product-management`, `marketing`, `engineering`, `data`, `design` e
`cowork-plugin-management`. São públicos, do marketplace `anthropics/knowledge-work-plugins`.
No aplicativo de desktop, ligue cada um na tela de plugins. No Claude Code de terminal, rode
`./instalar.sh --plugins-do-app`.

### `mcps/mcp-servers.json` (4 servidores MCP)

| Nome | Endereço | Como entra |
|---|---|---|
| `n8n-ops` | `https://n8n.ops.somoscase.com/mcp-server/http` | token próprio (ver abaixo) |
| `n8n` | `https://pires072931.app.n8n.cloud/mcp-server/http` | login pelo `/mcp` |
| `tactiq` | `https://mcp.tactiq.io` | login pelo `/mcp` |
| `codegraph` | programa local: `codegraph serve --mcp` | precisa do programa `codegraph` instalado |

O arquivo serve de referência; quem cadastra é o `instalar.sh`.

**Token do n8n-ops.** Não vem no pacote. Cada pessoa gera o seu no n8n
(`n8n.ops.somoscase.com`, na tela de acesso por MCP) e passa de um destes jeitos:

```bash
N8N_OPS_TOKEN="seu-token" ./instalar.sh
```

ou digita quando o script perguntar. Sem token, o `n8n-ops` é pulado e o resto segue.

**n8n (cloud).** No dia em que o pacote foi feito, esse servidor não estava conectando na
máquina de origem. Se continuar assim, o problema é do endereço, não da instalação.

## O que não vem no pacote

**Conectores da conta claude.ai.** Ficam presos à conta e ao login de cada serviço; não dá
para exportar. Reconecte na conta de destino, em Configurações > Conectores:

- Google Calendar, Google Drive
- Asana, ClickUp, monday.com
- Meta Ads, Meta Developers, TikTok Ads
- Lovable, n8n
- RD CRM Case, RD MCP Case, Google Ads MCP Case, Stape IO, WP MCP My360

Os cinco da última linha têm nome próprio, sinal de que foram adicionados por URL
(conector personalizado). A URL de cada um está na tela de conectores da conta de origem.

**Skills próprias da conta claude.ai.** Estas 12 moram na conta, não no Claude Code, e não
estão neste pacote: `acompanhamento-aparecer-na-a`, `agente-caser`, `agente-crm-case-ecomm`,
`case-email-writer`, `case-infra`, `case-meta-mcp-builder`, `case-offline-conv-builder`,
`central-importacao-compradores`, `designer-claudio`, `linkedin-post-ptbr`,
`pesquisa-previa-kickoff` e `relatorio-semestral-case`.

**Tokens, senhas e logins.** Nenhum.
