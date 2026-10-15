#!/usr/bin/env bash
# Instala skills para Claude Code, Codex ou ambos.
# Sem --destino, preserva o comportamento original (Claude Code).
# Plugins e MCPs sao configurados apenas para Claude Code.

set -u
AQUI="$(cd "$(dirname "$0")" && pwd)"
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
PLUGINS=1; PLUGINS_APP=0; MCP=1
DESTINO=claude
CODEX_SKILLS="${CODEX_SKILLS_DIR:-$HOME/.agents/skills}"
ajuda() {
  cat <<'HELP'
Uso: ./instalar.sh [--destino claude|codex|ambos] [opcoes]
  --destino claude|codex|ambos  Padrao: claude (aceita --destino=codex)
  --sem-plugins                Pula plugins do Claude Code
  --sem-mcp                    Pula MCPs do Claude Code
  --plugins-do-app             Inclui plugins Anthropic no modo Claude
  --help                      Mostra esta ajuda
Codex: requer Python 3; instala em ~/.agents/skills (ou CODEX_SKILLS_DIR).
Claude: usa CLAUDE_CONFIG_DIR ou ~/.claude. Itens existentes sao mantidos.
HELP
}
while [ "$#" -gt 0 ]; do
  a="$1"
  case "$a" in
    --destino)
      [ "$#" -ge 2 ] || { echo "--destino exige claude, codex ou ambos" >&2; exit 2; }
      DESTINO="$2"; shift ;;
    --destino=*) DESTINO="${a#*=}" ;;
    --plugins-do-app) PLUGINS_APP=1 ;;
    --sem-plugins) PLUGINS=0 ;;
    --sem-mcp) MCP=0 ;;
    -h|--help) ajuda; exit 0 ;;
    *) echo "opcao desconhecida: $a (veja --help)" >&2; exit 2 ;;
  esac
  shift
done
case "$DESTINO" in
  claude|codex|ambos) ;;
  *) echo "destino invalido: $DESTINO (use claude, codex ou ambos)" >&2; exit 2 ;;
esac
# Validate Codex prerequisites before modifying either destination.
if [ "$DESTINO" != claude ] && ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 e necessario para preparar as skills do Codex." >&2
  exit 1
fi

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

if [ "$DESTINO" != claude ]; then
  echo "Skills Codex -> $CODEX_SKILLS"
  if ! python3 "$AQUI/scripts/install_codex_skills.py" "$AQUI/skills-claude-code" "$CODEX_SKILLS"; then
    falhas=$((falhas + 1))
  fi
  echo '  Use $nome-da-skill no Codex; se nao aparecer, reinicie o aplicativo ou a sessao.'
  echo '  Plugins e MCPs deste instalador sao exclusivos do modo Claude.'
fi

if [ "$DESTINO" != codex ]; then
  echo "1) Skills Claude Code -> $CFG/skills"
  mkdir -p "$CFG/skills" || { echo "Nao foi possivel criar $CFG/skills" >&2; exit 1; }
  novas=0; mantidas=0; playwright_novo=0
  for d in "$AQUI"/skills-claude-code/*/; do
    d="${d%/}"
    [ -f "$d/SKILL.md" ] || continue
    n="$(basename "$d")"
    if [ -e "$CFG/skills/$n" ] || [ -L "$CFG/skills/$n" ]; then
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
fi
echo
if [ "$falhas" -gt 0 ]; then echo "Terminou com $falhas falha(s)."; exit 1; fi
echo "Terminou sem falhas."
