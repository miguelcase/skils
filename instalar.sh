#!/usr/bin/env bash
# Instala o conteudo deste pacote no Claude Code da conta atual.
#
#   ./instalar.sh                    skills + 2 plugins + MCPs
#   ./instalar.sh --plugins-do-app   tambem os 6 plugins da Anthropic (marketplace knowledge-work-plugins)
#   ./instalar.sh --sem-plugins      pula os plugins
#   ./instalar.sh --sem-mcp          pula os MCPs
#
# Nada aqui sobrescreve o que ja existe: skill, plugin ou MCP com o mesmo nome e mantido.
# O token do n8n-ops NAO vem no pacote: passe em N8N_OPS_TOKEN ou digite quando o script pedir.

set -u
AQUI="$(cd "$(dirname "$0")" && pwd)"
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
PLUGINS=1; PLUGINS_APP=0; MCP=1
for a in "$@"; do
  case "$a" in
    --plugins-do-app) PLUGINS_APP=1 ;;
    --sem-plugins) PLUGINS=0 ;;
    --sem-mcp) MCP=0 ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "opcao desconhecida: $a (veja --help)" >&2; exit 2 ;;
  esac
done

falhas=0
aviso() { echo "  ! $*"; }

# roda <rotulo> <mostrar-saida: 1|0> <comando...>
# Nunca imprime o comando (ele pode levar o token); a saida so aparece se mostrar=1.
roda() {
  local rotulo="$1" mostrar="$2" saida; shift 2
  if saida="$("$@" 2>&1)"; then
    echo "  ok: $rotulo"
  elif echo "$saida" | grep -qi "already"; then
    echo "  ja existe, mantido: $rotulo"
  else
    falhas=$((falhas + 1))
    echo "  FALHOU: $rotulo"
    [ "$mostrar" = 1 ] && echo "$saida" | tail -5 | sed 's/^/      /'
  fi
}

echo "1) Skills -> $CFG/skills"
mkdir -p "$CFG/skills"
novas=0; mantidas=0; playwright_novo=0
for d in "$AQUI"/skills-claude-code/*/; do
  d="${d%/}"
  [ -f "$d/SKILL.md" ] || continue
  n="$(basename "$d")"
  if [ -e "$CFG/skills/$n" ]; then
    mantidas=$((mantidas + 1)); echo "  ja existe, mantida: $n"
  elif cp -R "$d" "$CFG/skills/$n"; then
    novas=$((novas + 1)); [ "$n" = playwright-skill ] && playwright_novo=1
  else
    falhas=$((falhas + 1)); echo "  FALHOU: $n"
  fi
done
echo "  $novas instaladas, $mantidas mantidas"

tem_claude=1
if ! command -v claude >/dev/null 2>&1; then
  tem_claude=0
  if [ "$PLUGINS" = 1 ] || [ "$MCP" = 1 ]; then
    falhas=$((falhas + 1))
    aviso "comando 'claude' nao encontrado: plugins e MCPs pulados. Instale o Claude Code e rode de novo."
  fi
fi

if [ "$PLUGINS" = 1 ] && [ "$tem_claude" = 1 ]; then
  echo "2) Plugins"
  roda "marketplace superpowers-dev" 1 claude plugin marketplace add obra/superpowers
  roda "plugin superpowers"          1 claude plugin install superpowers@superpowers-dev
  roda "marketplace openai-codex"    1 claude plugin marketplace add openai/codex-plugin-cc
  roda "plugin codex"                1 claude plugin install codex@openai-codex
  if [ "$PLUGINS_APP" = 1 ]; then
    roda "marketplace knowledge-work-plugins" 1 claude plugin marketplace add anthropics/knowledge-work-plugins
    for p in product-management marketing engineering data design cowork-plugin-management; do
      roda "plugin $p" 1 claude plugin install "$p@knowledge-work-plugins"
    done
  fi
fi

if [ "$MCP" = 1 ] && [ "$tem_claude" = 1 ]; then
  echo "3) MCPs (escopo do usuario)"
  roda "mcp tactiq" 1 claude mcp add --scope user --transport http tactiq https://mcp.tactiq.io
  roda "mcp n8n"    1 claude mcp add --scope user --transport http n8n https://pires072931.app.n8n.cloud/mcp-server/http

  tok="${N8N_OPS_TOKEN:-}"
  if [ -z "$tok" ] && [ -t 0 ]; then
    printf "  Token do n8n-ops (Enter para pular): "; read -rs tok; echo
  fi
  tok="${tok#Bearer }"
  if [ -z "$tok" ]; then
    aviso "n8n-ops pulado: sem token. Gere o seu no n8n.ops.somoscase.com e rode de novo com N8N_OPS_TOKEN=..."
  else
    roda "mcp n8n-ops" 0 claude mcp add --scope user --transport http n8n-ops https://n8n.ops.somoscase.com/mcp-server/http --header "Authorization: Bearer $tok"
  fi

  if cg="$(command -v codegraph 2>/dev/null)"; then
    roda "mcp codegraph" 1 claude mcp add --scope user codegraph -- "$cg" serve --mcp
  else
    aviso "codegraph pulado: o programa 'codegraph' nao esta instalado nesta maquina"
  fi
fi

echo
echo "Falta fazer a mao:"
[ "$playwright_novo" = 1 ] && echo "  - playwright-skill: cd \"$CFG/skills/playwright-skill\" && npm run setup"
echo "  - Reinicie o Claude Code; depois use /mcp para entrar no tactiq e no n8n."
echo "  - Conectores da conta (Meta Ads, Google Drive, Asana...): veja a lista no LEIA-ME.md."
echo
if [ "$falhas" -gt 0 ]; then echo "Terminou com $falhas falha(s)."; exit 1; fi
echo "Terminou sem falhas."
