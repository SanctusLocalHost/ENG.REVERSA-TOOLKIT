#!/usr/bin/env bash
# ============================================================================
#  ENG. REVERSA - ponte MCP entre o Windows e o WSL
# ----------------------------------------------------------------------------
#  Cria scripts que o cliente de agente no Windows pode executar via
#  wsl.exe, mantendo o servidor MCP rodando dentro do WSL (onde estao REA,
#  Ghidra e decomp.wtf).
#
#  Saida: ${XDG_DATA_HOME:-$HOME/.local/share}/eng-reversa/mcp-rea.sh
#         ${XDG_DATA_HOME:-$HOME/.local/share}/eng-reversa/mcp-decomp.sh
#
#  Rodar depois de ./install.sh. Idempotente.
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/config/env.sh"

DEST="${XDG_DATA_HOME:-$HOME/.local/share}/eng-reversa"
mkdir -p "$DEST"

escrever() {
  local nome="$1" bin="$2" extra="${3:-}"
  {
    printf '#!/usr/bin/env bash\n'
    printf '# Gerado por windows/mcp-bridge.sh - nao editar\n'
    printf 'source "%s/config/env.sh"\n' "$ROOT"
    [ -n "$extra" ] && printf '%s\n' "$extra"
    printf 'exec "%s" mcp\n' "$bin"
  } > "$DEST/$nome"
  chmod +x "$DEST/$nome"
  printf '[mcp] %s -> %s\n' "$nome" "$bin"
}

REA_BIN="$(command -v rea || true)"
[ -n "$REA_BIN" ] || { echo "[ERRO] rea nao encontrado no WSL" >&2; exit 1; }
escrever "mcp-rea.sh" "$REA_BIN"

if command -v decomp >/dev/null 2>&1; then
  escrever "mcp-decomp.sh" "$(command -v decomp)" "export DECOMP_AGENT_NAME=opencode"
else
  echo "[mcp] decomp.wtf nao instalado; mcp-decomp.sh nao criado"
fi

echo
echo "Ponte MCP pronta em: $DEST"
ls -1 "$DEST"
