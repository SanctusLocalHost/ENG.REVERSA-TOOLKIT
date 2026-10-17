#!/usr/bin/env bash
# ============================================================================
#  ENG. REVERSA — Variáveis de ambiente centralizadas
# ----------------------------------------------------------------------------
#  Carregado (source) por todos os scripts em bin/.
#  A raiz é resolvida dinamicamente: a pasta pode ser movida ou clonada em
#  qualquer caminho (inclusive com espaços) sem quebrar nada.
#
#  Uso manual no terminal:
#      source "<raiz-do-toolkit>/config/env.sh"
# ============================================================================

# ---------------------------------------------------------------------------
# Raiz e diretórios internos
# ---------------------------------------------------------------------------
ENG_REV_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ENG_REV_HOME
export ENG_REV_BIN="$ENG_REV_HOME/bin"
export ENG_REV_TOOLS="$ENG_REV_HOME/tools"
export ENG_REV_SCRIPTS="$ENG_REV_HOME/ghidra-scripts"
export ENG_REV_WORKSPACES="$ENG_REV_HOME/workspace"
export ENG_REV_TARGETS="$ENG_REV_HOME/targets"
export ENG_REV_EXPORTS="$ENG_REV_HOME/exports"
export ENG_REV_DOCS="$ENG_REV_HOME/docs"

# Atalho genérico usado por agentes e scripts externos
export ENG_REVERSA="$ENG_REV_HOME"

# ---------------------------------------------------------------------------
# Ghidra dedicada (o REA exige a linha 12.1.x) — descoberta automática em
# tools/ghidra_*/. Prefere a série 12.1; aceita outra apenas como fallback.
# ---------------------------------------------------------------------------
if [ -z "${GHIDRA_INSTALL_DIR:-}" ] || [ ! -x "${GHIDRA_INSTALL_DIR:-}/support/analyzeHeadless" ]; then
  _g_cand=""
  for _g in "$ENG_REV_TOOLS"/ghidra_*/; do
    [ -x "${_g}support/analyzeHeadless" ] || continue
    _g_ver="$(grep -m1 '^application.version=' "${_g}Ghidra/application.properties" 2>/dev/null | cut -d= -f2)"
    case "$_g_ver" in
      12.1*) _g_cand="$_g"; break ;;
      *) [ -z "$_g_cand" ] && _g_cand="$_g" ;;
    esac
  done
  if [ -n "$_g_cand" ]; then
    export GHIDRA_INSTALL_DIR="$(cd "$_g_cand" && pwd)"
  fi
  unset _g_cand _g _g_ver 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# JDK 21+ (recomendado para o Ghidra 12.1; usa o maior candidato disponível)
# ---------------------------------------------------------------------------
if [ -z "${JAVA_HOME:-}" ] || [ ! -x "${JAVA_HOME:-}/bin/java" ]; then
  for jdk in /usr/lib/jvm/java-21-openjdk-amd64 \
             /usr/lib/jvm/java-21-openjdk \
             /usr/lib/jvm/java-21-openjdk-arm64 \
             /usr/lib/jvm/default-java; do
    if [ -x "$jdk/bin/java" ]; then export JAVA_HOME="$jdk"; break; fi
  done
fi
if [ -n "${JAVA_HOME:-}" ]; then
  case ":$PATH:" in
    *":$JAVA_HOME/bin:"*) ;;
    *) export PATH="$JAVA_HOME/bin:$PATH" ;;
  esac
fi

# ---------------------------------------------------------------------------
# Node.js via nvm (o rea-agents requer Node 22.x, 24.x ou 26+)
# ---------------------------------------------------------------------------
if ! command -v node >/dev/null 2>&1 && [ -d "$HOME/.nvm/versions/node" ]; then
  _node_dir="$(ls -d "$HOME"/.nvm/versions/node/v* 2>/dev/null | sort -V | tail -1)"
  [ -n "$_node_dir" ] && export PATH="$_node_dir/bin:$PATH"
  unset _node_dir
fi

# ---------------------------------------------------------------------------
# Gerenciador uv e binários de ferramentas instaladas por ele (~/.local/bin)
# ---------------------------------------------------------------------------
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) [ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH" ;;
esac

# ---------------------------------------------------------------------------
# bin/ do próprio toolkit no PATH (permite chamar `eng ...` de qualquer lugar)
# ---------------------------------------------------------------------------
case ":$PATH:" in
  *":$ENG_REV_BIN:"*) ;;
  *) export PATH="$ENG_REV_BIN:$PATH" ;;
esac

# ---------------------------------------------------------------------------
# Limite de memória do Ghidra. Em máquinas com pouca RAM, reduza (ex.: 1G).
# ---------------------------------------------------------------------------
: "${GHIDRA_MAXMEM:=2G}"
export GHIDRA_MAXMEM
