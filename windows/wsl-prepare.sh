#!/usr/bin/env bash
# ============================================================================
#  ENG. REVERSA - preparacao do WSL2 (Ubuntu) para o instalador
# ----------------------------------------------------------------------------
#  Chamado por install.ps1. Instala o que falta dentro do WSL:
#    - git, curl, tar, unzip, python3
#    - JDK 21 (Ghidra 12.1 exige)
#    - Node.js 22/24/26+ (via nvm, quando necessario)
#
#  Pode ser rodado manualmente:
#      bash windows/wsl-prepare.sh
# ============================================================================
set -uo pipefail

info() { printf "[wsl] %s\n" "$*"; }
warn() { printf "[wsl][aviso] %s\n" "$*"; }
die()  { printf "[wsl][ERRO] %s\n" "$*" >&2; exit 1; }

# --- pacotes basicos --------------------------------------------------------
faltam=()
for c in git curl tar unzip python3; do
  command -v "$c" >/dev/null 2>&1 || faltam+=("$c")
done

java_ok=0
if command -v java >/dev/null 2>&1; then
  linha="$(java -version 2>&1 | head -1)"
  versao="$(printf '%s' "$linha" | sed -E 's/.*"([0-9]+).*/\1/')"
  [ "${versao:-0}" -ge 21 ] 2>/dev/null && java_ok=1
fi
[ "$java_ok" = 1 ] || faltam+=("openjdk-21-jdk")

if [ ${#faltam[@]} -gt 0 ]; then
  info "instalando pacotes: ${faltam[*]}"
  info "o sudo pode pedir sua senha do WSL"
  sudo apt-get update || die "apt-get update falhou"
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${faltam[@]}" \
    || die "nao foi possivel instalar: ${faltam[*]}
Em Ubuntu antigo, o JDK 21 pode nao existir no repositorio.
Instale manualmente um JDK 21+ e rode de novo."
else
  info "pacotes basicos e JDK 21 ja presentes"
fi

# --- Node.js ----------------------------------------------------------------
node_ok=0
if command -v node >/dev/null 2>&1; then
  major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  case "$major" in
    22|24) node_ok=1 ;;
    *) [ "$major" -ge 26 ] 2>/dev/null && node_ok=1 ;;
  esac
fi

if [ "$node_ok" = 1 ]; then
  info "Node.js $(node --version) ja presente"
else
  info "instalando Node.js 24 via nvm"
  export NVM_DIR="$HOME/.nvm"
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash \
      || die "falha ao instalar o nvm"
  fi
  # shellcheck source=/dev/null
  . "$NVM_DIR/nvm.sh"
  nvm install 24 || die "falha ao instalar o Node.js 24"
  nvm alias default 24 >/dev/null 2>&1 || true
  info "Node.js $(node --version) instalado"
fi

info "WSL pronto. Rode agora: ./install.sh"
