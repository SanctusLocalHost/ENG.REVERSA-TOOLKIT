#!/usr/bin/env bash
# ============================================================================
#  ENG. REVERSA — desinstalador
# ----------------------------------------------------------------------------
#  Remove:
#    - o bloco do toolkit no ~/.bashrc
#    - o atalho ~/.local/bin/eng
#    - links simbólicos de skills/agente que apontam para este toolkit
#
#  Opções:
#    --purge   remove também tools/ (Ghidra baixada pelo instalador)
#    -y        não pergunta nada
#
#  Pacotes globais (rea-agents, decomp.wtf) NÃO são removidos; o script
#  mostra os comandos ao final.
# ============================================================================
set -uo pipefail

KIT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PURGE=0
ASSUME_YES=0

usage() {
  cat <<'EOF'
ENG. REVERSA — desinstalador

Uso:
  ./uninstall.sh [--purge] [-y]

Opções:
  --purge   remove também tools/ (Ghidra baixada)
  -y        não pergunta nada
  -h        esta ajuda
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --purge) PURGE=1 ;;
    -y|--yes) ASSUME_YES=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[ERRO] opção desconhecida: $1" >&2; exit 1 ;;
  esac
  shift
done

confirm() {
  [ "$ASSUME_YES" = 1 ] && return 0
  [ -t 0 ] || return 0
  printf "%s [s/N] " "$1"
  read -r resposta
  case "$resposta" in s|S|y|Y|sim|SIM) return 0 ;; *) return 1 ;; esac
}

echo "ENG. REVERSA — desinstalação"
echo "  raiz: $KIT_DIR"
echo

# ---------------------------------------------------------------------------
# 1. Bloco no ~/.bashrc
# ---------------------------------------------------------------------------
RC="$HOME/.bashrc"
BEGIN="# >>> ENG. REVERSA >>>"
END="# <<< ENG. REVERSA <<<"
if [ -f "$RC" ] && grep -qF "$BEGIN" "$RC"; then
  tmp="$(mktemp)"
  awk -v b="$BEGIN" -v e="$END" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    skip != 1 { print }
  ' "$RC" > "$tmp" && mv "$tmp" "$RC"
  echo "[ok] bloco removido de $RC"
else
  echo "[ok] nenhum bloco encontrado em $RC"
fi

# ---------------------------------------------------------------------------
# 2. Atalho ~/.local/bin/eng
# ---------------------------------------------------------------------------
LINK="$HOME/.local/bin/eng"
if [ -L "$LINK" ]; then
  alvo="$(readlink -f "$LINK" 2>/dev/null || true)"
  case "$alvo" in
    "$KIT_DIR"/*) rm -f "$LINK"; echo "[ok] atalho removido: $LINK" ;;
    *) echo "[aviso] $LINK aponta para outro lugar; mantido" ;;
  esac
elif [ -e "$LINK" ]; then
  echo "[aviso] $LINK não é um link simbólico; mantido"
else
  echo "[ok] atalho ausente: $LINK"
fi

# ---------------------------------------------------------------------------
# 3. Links de skills/agente nos clientes de agente
# ---------------------------------------------------------------------------
RAIZES=(
  "$HOME/.agents"
  "$HOME/.claude"
  "$HOME/.config/opencode"
  "$HOME/.codex"
  "$HOME/.gemini"
  "$HOME/.cursor"
  "$HOME/.config/amp"
)
removidos=0
for r in "${RAIZES[@]}"; do
  for sub in skills agents; do
    d="$r/$sub"
    [ -d "$d" ] || continue
    while IFS= read -r -d '' link; do
      alvo="$(readlink -f "$link" 2>/dev/null || true)"
      case "$alvo" in
        "$KIT_DIR"/*) rm -f "$link"; removidos=$((removidos+1)) ;;
      esac
    done < <(find "$d" -maxdepth 1 -type l -print0 2>/dev/null)
  done
done
echo "[ok] links removidos nos clientes: $removidos"

# ---------------------------------------------------------------------------
# 4. Ferramentas baixadas (opcional)
# ---------------------------------------------------------------------------
if [ "$PURGE" = 1 ]; then
  if [ -d "$KIT_DIR/tools" ] && [ -n "$(ls -A "$KIT_DIR/tools" 2>/dev/null)" ]; then
    if confirm "Remover $KIT_DIR/tools (Ghidra baixada)?"; then
      rm -rf "$KIT_DIR/tools"
      echo "[ok] tools/ removido"
    else
      echo "[ok] tools/ mantido"
    fi
  else
    echo "[ok] tools/ já está vazio"
  fi
fi

echo
echo "Desinstalação concluída. Os dados em workspace/, targets/ e exports/"
echo "foram preservados."
echo
echo "Para remover os pacotes globais (opcional):"
echo "  npm uninstall --global rea-agents"
echo "  uv tool uninstall decomp.wtf"
echo
echo "Reinicie o cliente de agente para descarregar skills e MCP."
