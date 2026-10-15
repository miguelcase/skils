# Skills para Claude Code e Codex

Coleção pessoal de **24 skills**, cópias de referência de **2 plugins** e configuração de **4 servidores MCP**, baseada no pacote de 08/10/2026.

As skills reúnem instruções, exemplos e, em alguns casos, scripts que o Claude Code usa em tarefas de segurança, automação de navegador, produção de vídeos e engenharia. O instalador permite escolher Claude Code, Codex ou ambos e copia as skills para a configuração do usuário; as ferramentas e dependências de cada skill são instaladas separadamente.

## Estrutura

```text
.
├── README.md                 # Guia de instalação e uso
├── LEIA-ME.md                # Notas originais do pacote
├── instalar.sh               # Escolha do destino e instalação
├── scripts/                  # Adaptação das cópias para Codex
├── tests/                    # Verificações isoladas do instalador
├── skills-claude-code/       # 24 skills, cada uma com SKILL.md
├── plugins/claude-code/      # Cópias dos plugins superpowers e codex
└── mcps/mcp-servers.json     # Referência das configurações MCP
```

## Instalação rápida

Pré-requisitos:

- Git e Bash, em macOS, Linux ou Windows com WSL.
- Para usar no Claude: Claude Code instalado e autenticado, com o comando `claude` disponível no terminal. Consulte a [instalação oficial](https://code.claude.com/docs/en/setup).
- Para instalar para Codex: Python 3. Para usar as skills depois, Codex instalado e autenticado (aplicativo, CLI ou extensão com suporte a skills locais). A instalação das skills não exige o executável `codex`.
- Acesso à internet para baixar plugins e dependências.
- Node.js 20+ e npm para a `playwright-skill`; outras skills podem exigir Python e ferramentas específicas descritas em seus respectivos `SKILL.md`.

Clone o repositório e escolha o destino:

```bash
git clone https://github.com/miguelcase/skils.git
cd skils

# Somente skills do Codex:
./instalar.sh --destino codex

# Claude Code (comportamento original: skills, plugins e MCPs):
./instalar.sh --destino claude

# Skills nos dois agentes, sem plugins ou MCPs:
./instalar.sh --destino ambos --sem-plugins --sem-mcp
```

Execute a opção correspondente ao seu objetivo. Sem `--destino`, o padrão continua sendo `claude`. Para instalar nos dois e também configurar plugins/MCPs do Claude, use `./instalar.sh --destino ambos`.

### Destinos e compatibilidade

| Destino | Pasta de skills | Plugins e MCPs |
|---|---|---|
| `claude` (padrão) | `${CLAUDE_CONFIG_DIR:-~/.claude}/skills` | Configurados pelo instalador, salvo opções para pular. |
| `codex` | `~/.agents/skills` | Nenhum cadastro automático. |
| `ambos` | As duas pastas acima | Configurados somente no Claude. |

O caminho do Codex segue a [documentação oficial de skills da OpenAI](https://learn.chatgpt.com/docs/build-skills). Para instalar em outro local, defina `CODEX_SKILLS_DIR`; essa variável é uma opção deste instalador, não uma configuração do Codex. O destino escolhido precisa ser uma pasta que o Codex consulte. Exemplo de instalação restrita a um projeto:

```bash
CODEX_SKILLS_DIR="/caminho/do/seu-projeto/.agents/skills" ./instalar.sh --destino codex
```

Para Codex, o instalador copia scripts, referências e assets e gera um `SKILL.md` de entrada com `name` igual ao nome da pasta e a descrição original. Mantém o corpo original e acrescenta instruções para resolver caminhos e adaptar referências a ferramentas do Claude. Os demais metadados do frontmatter, como `allowed-tools` do Claude, não são transferidos. Os arquivos de origem e suas informações de autoria/licença continuam no repositório.

Essa adaptação permite instalar e descobrir as 24 skills no Codex; não substitui ferramentas externas nem garante que todo fluxo originalmente escrito para Claude funcione sem ajustes. Etapas que dependem de plugins, MCPs ou ferramentas ausentes precisam desses recursos no ambiente de destino. Nenhuma tarefa das skills é executada durante a instalação.

No modo Claude, o instalador:

1. Copia as 24 skills para `~/.claude/skills/`, ou para `$CLAUDE_CONFIG_DIR/skills/` quando essa variável estiver definida.
2. Cadastra os marketplaces e instala `superpowers` e `codex` pelas origens oficiais.
3. Cadastra os MCPs no escopo do usuário. `n8n-ops` depende de token; `codegraph` depende do programa local.
4. Exibe as etapas que ainda precisam ser feitas manualmente e informa eventuais falhas.

Skills que já existem com o mesmo nome são mantidas. Para plugins e MCPs, o script tenta cadastrar/instalar e trata respostas contendo `already` como itens existentes; ele não implementa atualização ou reconciliação das configurações.

Depois, reinicie o Claude Code. Use `/mcp` dentro dele para conferir conexões e autenticar os serviços que exigirem login.

### Instalar somente as skills do Claude

Para começar sem configurar plugins nem MCPs:

```bash
./instalar.sh --sem-plugins --sem-mcp
```

Nesse modo, a cópia das skills também funciona sem o comando `claude` instalado. Para utilizá-las, o Claude Code precisa estar disponível depois.

### Opções do instalador

| Opção | Efeito |
|---|---|
| `--destino claude\|codex\|ambos` | Escolhe o agente; padrão `claude`. Aceita também `--destino=codex`. |
| `--sem-plugins` | Pula a instalação dos plugins. |
| `--sem-mcp` | Pula o cadastro dos servidores MCP. |
| `--plugins-do-app` | Instala também seis plugins do marketplace `anthropics/knowledge-work-plugins`. |
| `--help` | Mostra a ajuda. |

As opções podem ser combinadas. `--plugins-do-app` só tem efeito quando a instalação de plugins está habilitada.

### Preparar o Playwright em cada destino

Depois de copiar as skills, instale as dependências e o Chromium:

```bash
cd "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/playwright-skill"
npm run setup
```

Para Codex, use a pasta correspondente:

```bash
cd "${CODEX_SKILLS_DIR:-$HOME/.agents/skills}/playwright-skill"
npm run setup
```

Se instalou nos dois agentes, prepare cada cópia que for usar. Esse comando está definido no `package.json` da skill e executa `npm install` seguido da instalação do Chromium pelo Playwright. A pasta `node_modules` não vem no pacote.

### Instalar uma skill manualmente no Claude

A partir da raiz deste repositório, este exemplo instala apenas `brag-slim` e mantém qualquer cópia existente:

```bash
skills_destino="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"
mkdir -p "$skills_destino"
if [ -e "$skills_destino/brag-slim" ]; then
  echo "brag-slim já existe; cópia mantida."
else
  cp -R skills-claude-code/brag-slim "$skills_destino/brag-slim"
fi
```

Copie a pasta inteira: `scripts/`, `references/` e `assets/`, quando presentes, fazem parte da skill. Para limitar a instalação a um projeto, use `<seu-projeto>/.claude/skills/` como destino, conforme a [documentação de skills do Claude Code](https://code.claude.com/docs/en/skills).

## Catálogo de skills

Os identificadores abaixo são os nomes das pastas do pacote. Consulte o `SKILL.md` de cada uma para conhecer seus requisitos, instruções e exemplos.

### Segurança — 19 skills

| Pasta | Finalidade |
|---|---|
| [01-recon-osint](skills-claude-code/01-recon-osint/SKILL.md) | Reconhecimento, DNS, subdomínios e levantamento de informações públicas. |
| [02-vulnerability-scanner](skills-claude-code/02-vulnerability-scanner/SKILL.md) | Auditoria de dependências, CVEs e configurações, com priorização de correções. |
| [03-exploit-development](skills-claude-code/03-exploit-development/SKILL.md) | Pesquisa de vulnerabilidades e provas de conceito em testes autorizados. |
| [04-reverse-engineering](skills-claude-code/04-reverse-engineering/SKILL.md) | Análise de binários, assembly, firmware e protocolos. |
| [05-malware-analysis](skills-claude-code/05-malware-analysis/SKILL.md) | Análise de arquivos suspeitos, comportamento e regras YARA. |
| [06-threat-hunting](skills-claude-code/06-threat-hunting/SKILL.md) | Extração de IOCs, inteligência de ameaças e mapeamento MITRE ATT&CK. |
| [07-incident-response](skills-claude-code/07-incident-response/SKILL.md) | Resposta a incidentes, coleta de evidências e análise forense. |
| [08-network-security](skills-claude-code/08-network-security/SKILL.md) | Análise de tráfego, PCAPs, firewalls e regras de detecção. |
| [09-web-security](skills-claude-code/09-web-security/SKILL.md) | Avaliação de aplicações web, APIs e autenticação. |
| [10-cloud-security](skills-claude-code/10-cloud-security/SKILL.md) | Avaliação de segurança em nuvem e configurações de infraestrutura. |
| [11-csoc-automation](skills-claude-code/11-csoc-automation/SKILL.md) | Automação de operações de SOC e fluxos de segurança. |
| [12-log-analysis](skills-claude-code/12-log-analysis/SKILL.md) | Interpretação de logs, correlação de eventos e detecção de anomalias. |
| [13-crypto-analysis](skills-claude-code/13-crypto-analysis/SKILL.md) | Análise de criptografia, certificados e implementações criptográficas. |
| [14-red-team-ops](skills-claude-code/14-red-team-ops/SKILL.md) | Planejamento e operações de red team em escopo autorizado. |
| [15-blue-team-defense](skills-claude-code/15-blue-team-defense/SKILL.md) | Defesa, hardening e engenharia de detecção. |
| [16-ai-llm-security](skills-claude-code/16-ai-llm-security/SKILL.md) | Segurança de LLMs, agentes, RAG e prompt injection. |
| [17-mobile-security](skills-claude-code/17-mobile-security/SKILL.md) | Segurança de aplicações Android/iOS e análise de APK/IPA. |
| [18-ot-ics-security](skills-claude-code/18-ot-ics-security/SKILL.md) | Segurança de ambientes industriais, ICS e SCADA. |
| [19-grc-compliance](skills-claude-code/19-grc-compliance/SKILL.md) | Gestão de riscos, controles, políticas e preparação de evidências de auditoria. |

Use as skills de testes de segurança somente em sistemas próprios ou com autorização e escopo definidos.

### Vídeo, automação e engenharia — 5 skills

| Skill | Finalidade |
|---|---|
| [brag](skills-claude-code/brag/SKILL.md) | Produzir um vídeo curto de lançamento a partir do código de um projeto, usando Hyperframes. |
| [brag-slim](skills-claude-code/brag-slim/SKILL.md) | Criar um vídeo de apresentação a partir de uma pasta de projeto ou URL, usando as ferramentas disponíveis na máquina. |
| [case-engenharia](skills-claude-code/case-engenharia/SKILL.md) | Orientações específicas de trabalho nos projetos da Case; exige adaptar o contexto para outros ambientes. |
| [find-skills](skills-claude-code/find-skills/SKILL.md) | Descobrir e instalar outras skills do ecossistema. |
| [playwright-skill](skills-claude-code/playwright-skill/SKILL.md) | Automatizar navegação, capturas de tela, testes de interface e fluxos web. |

## Como usar no Codex

No aplicativo Codex, abra o projeto desejado e mencione a skill pelo nome no pedido. No CLI, abra o projeto com `codex` e use `$nome-da-skill` ou `/skills`. A seleção automática também pode ocorrer pela descrição. Esses mecanismos e as pastas de descoberta estão na [documentação oficial](https://learn.chatgpt.com/docs/build-skills).

Exemplos de prompts (digite no Codex, não no shell):

```text
$playwright-skill abra http://localhost:3000 e confira a interface mobile.

$02-vulnerability-scanner revise as dependências deste projeto.

$12-log-analysis analise estes logs e priorize os erros recorrentes.

$brag-slim crie um vídeo vertical de 20 segundos deste projeto.

$find-skills encontre uma skill de acessibilidade web.
```

No Codex, os nomes são os identificadores de pasta do catálogo abaixo. Se uma skill não aparecer, reinicie o aplicativo ou a sessão e confira o destino da instalação. As referências a `/brag` e outros comandos do Claude nos textos originais devem ser usadas como menções `$brag` no Codex.

## Como usar no Claude Code

Abra o Claude Code na pasta do projeto em que deseja trabalhar:

```bash
cd /caminho/do/seu-projeto
claude
```

Segundo a [documentação oficial](https://code.claude.com/docs/en/skills), o Claude pode carregar uma skill quando a descrição combina com o pedido; também é possível invocá-la com `/nome-da-skill`. Digite `/` para conferir os comandos disponíveis na sua instalação.

Exemplos de pedidos dentro do Claude Code:

```text
Use a skill playwright-skill para abrir http://localhost:3000,
verificar a versão mobile e salvar capturas de tela.

Use a skill de análise de logs em 12-log-analysis para examinar
estes logs e apontar erros recorrentes e possíveis causas.

Use a skill de auditoria de vulnerabilidades em 02-vulnerability-scanner
para revisar as dependências deste projeto e priorizar as correções.

Use find-skills para encontrar uma skill de acessibilidade web.
```

As skills de vídeo também documentam estas invocações:

```text
/brag
/brag-slim https://exemplo.com --format vertical --duration 20
```

Os exemplos em linguagem natural são úteis para as skills de segurança: seus campos `name` contêm títulos descritivos, com espaços e pontuação, em vez de identificadores simples. A descoberta e a validação podem variar conforme a versão do Claude Code. Se alguma não aparecer, confira o diagnóstico antes de presumir que o nome da pasta funciona como comando.

## Plugins do Claude Code

| Plugin | Versão da cópia | Origem | Uso |
|---|---|---|---|
| `superpowers` | 6.2.0 | [obra/superpowers](https://github.com/obra/superpowers) | Fluxos de planejamento, implementação, testes e revisão. |
| `codex` | 1.0.6 | [openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc) | Integração do Claude Code com o Codex CLI. |

O instalador baixa os plugins pelos marketplaces oficiais; a versão instalada pode diferir das cópias deste repositório. O plugin `codex` depende do Codex CLI instalado e autenticado. Depois da instalação, use `/codex:setup` para conferir os requisitos.

Com `./instalar.sh --plugins-do-app`, o script também tenta instalar `product-management`, `marketing`, `engineering`, `data`, `design` e `cowork-plugin-management`. Esses seis plugins não estão incluídos como cópias locais.

## Servidores MCP do Claude Code

MCPs conectam o Claude Code a serviços e ferramentas. O modo Codex não altera `config.toml` nem importa o JSON do Claude; configure suas conexões separadamente no Codex quando alguma tarefa precisar delas. O arquivo [mcps/mcp-servers.json](mcps/mcp-servers.json) é uma referência; o instalador faz o cadastro com `claude mcp add`.

| Nome | Serviço | Requisito |
|---|---|---|
| `tactiq` | `https://mcp.tactiq.io` | Autenticação pelo `/mcp`. |
| `n8n` | Instância cloud indicada no instalador | Acesso à instância e autenticação pelo `/mcp`. |
| `n8n-ops` | Instância da Case indicada no instalador | Token próprio da instância; sem token, é pulado. |
| `codegraph` | Processo local `codegraph serve --mcp` | Executável `codegraph` disponível no `PATH`; sem ele, é pulado. |

Os endereços de n8n são específicos do ambiente de origem. Para outro ambiente, ajuste-os em uma cópia local do instalador antes do cadastro; editar apenas o JSON de referência não altera o comportamento do script.

Para `n8n-ops`, o instalador solicita o token de forma oculta no terminal interativo. Pressione Enter para pular. Também aceita a variável `N8N_OPS_TOKEN`. Use credenciais próprias e mantenha-as fora do Git.

As notas originais registram que o n8n cloud não conectava na máquina de origem na data do pacote; a disponibilidade atual precisa ser conferida separadamente.

## Atualizar e resolver problemas

Para baixar alterações deste repositório:

```bash
git pull --ff-only
```

**Isso não atualiza as skills já copiadas para Claude ou Codex.** O instalador mantém as pastas existentes nos dois destinos. Para atualizar uma skill, faça backup da pasta instalada, compare suas personalizações e mova o backup para fora das pastas de descoberta e rode o instalador novamente para o destino desejado. No Codex, isso reaplica a adaptação dos metadados; copiar somente o original não faz essa adaptação. Evite mesclar arquivos indiscriminadamente, pois arquivos removidos na origem podem continuar no destino.

| Problema | O que verificar |
|---|---|
| `Permission denied` ao executar o instalador | Execute `bash instalar.sh` com as mesmas opções desejadas. |
| `claude` não encontrado | Confira a instalação e o `PATH`; para apenas copiar skills, use `--sem-plugins --sem-mcp`. |
| Skill do Codex não aparece | Confira `~/.agents/skills/<pasta>/SKILL.md` ou o destino personalizado; reinicie a sessão. Procure também cópias com o mesmo nome em outros escopos. |
| Python 3 não encontrado no modo Codex | Instale Python 3 e confira o comando `python3` no `PATH`. |
| Skill do Claude não aparece ou não é usada | Confira `<configuração>/skills/<pasta>/SKILL.md`, reinicie o Claude Code e peça explicitamente a skill. Revise o frontmatter e os diagnósticos da sua versão. |
| Playwright sem navegador ou dependências | Execute `npm run setup` na pasta instalada da `playwright-skill`, usando Node.js 20+. |
| Script de segurança pede um módulo Python ou ferramenta | Consulte os pré-requisitos do `SKILL.md` correspondente; o instalador não prepara essas dependências. |
| MCP não conecta | Confira `/mcp`, URL, acesso à instância e autenticação. |
| Instalador termina com falhas | Leia os itens `FALHOU`, corrija a causa e execute novamente. Etapas anteriores podem já ter sido concluídas. |

## Limites do pacote

- O instalador oferece skills para **Claude Code e Codex**. Os plugins e MCPs incluídos na automação continuam exclusivos do modo Claude.
- Conectores e skills exclusivos da conta claude.ai não são migrados pelo instalador. As notas e a relação original estão em [LEIA-ME.md](LEIA-ME.md).
- Logins e tokens precisam ser configurados na conta de destino.
- Cada componente mantém suas próprias informações de autoria e licença; consulte os arquivos correspondentes antes de redistribuir.

## Verificar o instalador

Os testes usam pastas temporárias e comandos simulados, sem modificar a instalação pessoal nem conectar serviços:

```bash
bash -n instalar.sh
python3 -m unittest discover -s tests -v
```
