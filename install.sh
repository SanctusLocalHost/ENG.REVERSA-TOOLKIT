#!/usr/bin/env bash
# ============================================================================
#  ENG. REVERSA — instalador de restauração
# ----------------------------------------------------------------------------
#  Instala e configura o toolkit nesta máquina:
#    1. valida pré-requisitos
#    2. instala o REA (rea-agents) globalmente
#    3. baixa/valida a Ghidra 12.1.x dedicada em tools/
#    4. registra os servidores MCP nos clientes de agente detectados
#    5. instala skills e agente nos clientes detectados
#    6. integra ao shell (~/.bashrc e atalho ~/.local/bin/eng)
#    7. roda eng doctor
#
#  Uso: ./install.sh [opções]
#  Idempotente: pode rodar quantas vezes quiser.
# ============================================================================
set -uo pipefail

KIT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

ASSUME_YES=0
DRY_RUN=0
DO_GHIDRA=1
DO_DECOMP=0
DO_SHELL=1
FORCE=0
TARGET_HOME=""

usage() {
  cat <<'EOF'
ENG. REVERSA — instalador

Uso:
  ./install.sh [opções]

Opções:
  -y, --yes            não pergunta nada
      --dry-run        mostra o plano completo sem executar
      --no-ghidra      não baixa a Ghidra (usa GHIDRA_INSTALL_DIR existente)
      --with-decomp-wtf instala também o decomp.wtf (games retrô)
      --no-shell       não altera o ~/.bashrc nem cria o atalho eng
      --home <dir>     copia o toolkit para <dir> e instala a partir dele
      --force          permite usar --home em diretório não vazio
  -h, --help           esta ajuda

Variáveis de ambiente:
  GHIDRA_INSTALL_DIR   Ghidra 12.1.x já instalada (evita download)
  GHIDRA_ZIP           zip local da Ghidra (evita download)
  GHIDRA_MAXMEM        heap do Ghidra (padrão 2G)
EOF
}

info()  { printf "[eng] %s\n" "$*"; }
warn()  { printf "[aviso] %s\n" "$*"; }
die()   { printf "[ERRO] %s\n" "$*" >&2; exit 1; }

run() {
  if [ "$DRY_RUN" = 1 ]; then
    printf "[dry-run] %s\n" "$*"
    return 0
  fi
  "$@"
}

confirm() {
  [ "$ASSUME_YES" = 1 ] && return 0
  [ "$DRY_RUN" = 1 ] && return 0
  [ -t 0 ] || return 0
  printf "%s [s/N] " "$1"
  read -r resposta
  case "$resposta" in
    s|S|y|Y|sim|SIM) return 0 ;;
    *) return 1 ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes) ASSUME_YES=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --no-ghidra) DO_GHIDRA=0 ;;
    --with-decomp-wtf) DO_DECOMP=1 ;;
    --no-shell) DO_SHELL=0 ;;
    --force) FORCE=1 ;;
    --home)
      shift
      TARGET_HOME="${1:-}"
      [ -n "$TARGET_HOME" ] || die "--home precisa de um diretório"
      ;;
    -h|--help) usage; exit 0 ;;
    *) die "opção desconhecida: $1 (use --help)" ;;
  esac
  shift
done

echo "============================================================"
echo " ENG. REVERSA — instalador"
echo "============================================================"
info "origem: $KIT_DIR"
info "modo:   $([ "$DRY_RUN" = 1 ] && echo 'dry-run (nada sera alterado)' || echo 'instalação')"
echo

# ---------------------------------------------------------------------------
# 0. Instalação em outro diretório (--home)
# ---------------------------------------------------------------------------
if [ -n "$TARGET_HOME" ]; then
  mkdir -p "$TARGET_HOME" || die "não foi possível criar $TARGET_HOME"
  TARGET_HOME="$(cd "$TARGET_HOME" && pwd)"
  if [ "$TARGET_HOME" != "$KIT_DIR" ]; then
    if [ -n "$(ls -A "$TARGET_HOME" 2>/dev/null)" ] && [ "$FORCE" != 1 ]; then
      die "destino não vazio: $TARGET_HOME (use --force ou escolha outra pasta)"
    fi
    info "copiando o toolkit para $TARGET_HOME"
    if [ "$DRY_RUN" = 1 ]; then
      printf "[dry-run] copiar %s -> %s\n" "$KIT_DIR" "$TARGET_HOME"
    else
      if git -C "$KIT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git -C "$KIT_DIR" archive --format=tar HEAD | tar -x -C "$TARGET_HOME" \
          || die "falha ao copiar o toolkit"
      else
        for item in "$KIT_DIR"/*; do
          base="$(basename "$item")"
          case "$base" in
            tools|workspace|targets|exports) continue ;;
          esac
          cp -a "$item" "$TARGET_HOME/" || die "falha ao copiar $base"
        done
        [ -f "$KIT_DIR/.gitignore" ] && cp -a "$KIT_DIR/.gitignore" "$TARGET_HOME/"
        mkdir -p "$TARGET_HOME/workspace"
        cp -a "$KIT_DIR/workspace/_TEMPLATE" "$TARGET_HOME/workspace/" 2>/dev/null || true
        mkdir -p "$TARGET_HOME/targets" "$TARGET_HOME/exports" "$TARGET_HOME/tools"
      fi
    fi
    KIT_DIR="$TARGET_HOME"
    info "nova raiz: $KIT_DIR"
  fi
fi

# ---------------------------------------------------------------------------
# 1. Pré-requisitos
# ---------------------------------------------------------------------------
echo "-- 1/7 Pré-requisitos"

if [ -f "$KIT_DIR/config/env.sh" ]; then
  # shellcheck source=/dev/null
  . "$KIT_DIR/config/env.sh"
fi

faltando=()
for cmd in git curl tar unzip python3 node npm; do
  command -v "$cmd" >/dev/null 2>&1 || faltando+=("$cmd")
done
if [ ${#faltando[@]} -gt 0 ]; then
  die "faltam comandos: ${faltando[*]}
Instale antes de continuar. Exemplo (Debian/Ubuntu):
  sudo apt install -y git curl unzip tar python3
  (Node 22/24/26: recomendado via nvm — veja docs/INSTALACAO.md)"
fi

node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
case "$node_major" in
  22|24|26) info "Node.js $(node --version) OK" ;;
  *)
    if [ "$node_major" -ge 22 ] 2>/dev/null; then
      warn "Node.js $(node --version): o REA declara suporte a 22.x, 24.x e 26+"
    else
      die "Node.js $(node --version) é antigo; instale 22.x, 24.x ou 26+ (recomendado via nvm)"
    fi
    ;;
esac

if [ -z "${JAVA_HOME:-}" ] || [ ! -x "${JAVA_HOME:-}/bin/java" ]; then
  if command -v java >/dev/null 2>&1; then
    java_real="$(readlink -f "$(command -v java)")"
    JAVA_HOME="$(cd "$(dirname "$java_real")/.." && pwd)"
    export JAVA_HOME
  fi
fi
if [ -z "${JAVA_HOME:-}" ] || [ ! -x "$JAVA_HOME/bin/java" ]; then
  die "JDK não encontrado. Instale o JDK 21+:
  sudo apt install -y openjdk-21-jdk
  export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64"
fi
java_major="$("$JAVA_HOME/bin/java" -version 2>&1 | head -1 | sed -E 's/.*"([0-9]+).*/\1/')"
if [ "${java_major:-0}" -lt 21 ] 2>/dev/null; then
  warn "JDK $java_major detectado; o Ghidra 12.1 exige JDK 21+"
fi
info "JDK ${java_major:-?} em $JAVA_HOME"
echo

# ---------------------------------------------------------------------------
# 2. REA (rea-agents)
# ---------------------------------------------------------------------------
echo "-- 2/7 REA (rea-agents)"
if command -v rea >/dev/null 2>&1; then
  info "já instalado: $(rea --version 2>/dev/null || echo 'versão desconhecida')"
  if confirm "Atualizar o rea-agents para a última versão?"; then
    run npm install --global rea-agents@latest
  fi
else
  run npm install --global rea-agents@latest
fi
if [ "$DRY_RUN" != 1 ] && ! command -v rea >/dev/null 2>&1; then
  die "rea não encontrado após a instalação; confira o PATH do npm (npm config get prefix)"
fi
echo

# ---------------------------------------------------------------------------
# 3. Ghidra 12.1.x dedicada
# ---------------------------------------------------------------------------
echo "-- 3/7 Ghidra 12.1.x"
ghidra_ok() {
  [ -n "${GHIDRA_INSTALL_DIR:-}" ] && [ -x "$GHIDRA_INSTALL_DIR/support/analyzeHeadless" ]
}
if ghidra_ok; then
  gver="$(grep -m1 '^application.version=' "$GHIDRA_INSTALL_DIR/Ghidra/application.properties" 2>/dev/null | cut -d= -f2)"
  info "já disponível: $gver em $GHIDRA_INSTALL_DIR"
elif [ "$DO_GHIDRA" = 0 ]; then
  warn "download desativado (--no-ghidra) e GHIDRA_INSTALL_DIR não aponta para uma Ghidra válida"
else
  mkdir -p "$KIT_DIR/tools"
  ZIP_URL=""
  ZIP_FILE="$KIT_DIR/tools/ghidra_12.1.x.zip"
  if [ -n "${GHIDRA_ZIP:-}" ] && [ -f "${GHIDRA_ZIP:-}" ]; then
    ZIP_FILE="$GHIDRA_ZIP"
    info "usando zip local: $ZIP_FILE"
  else
    info "procurando a release 12.1.x mais recente"
    if [ "$DRY_RUN" != 1 ]; then
      ZIP_URL="$(curl -fsSL --max-time 30 \
        "https://api.github.com/repos/NationalSecurityAgency/ghidra/releases?per_page=30" \
        | grep -o 'https://[^"]*ghidra_12\.1\.[0-9]*_PUBLIC_[0-9]*\.zip' \
        | sort -V | tail -1)"
      [ -n "$ZIP_URL" ] || ZIP_URL="https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.4_build/ghidra_12.1.4_PUBLIC_20260921.zip"
    else
      ZIP_URL="(release 12.1.x mais recente do GitHub)"
    fi
    info "download: $ZIP_URL"
    run curl -fL --retry 3 --connect-timeout 30 -o "$ZIP_FILE" "$ZIP_URL"
  fi
  if [ "$DRY_RUN" != 1 ]; then
    [ -f "$ZIP_FILE" ] || die "zip da Ghidra não encontrado: $ZIP_FILE"
    info "extraindo em tools/ (pode demorar)"
    unzip -q "$ZIP_FILE" -d "$KIT_DIR/tools" || die "falha ao extrair a Ghidra"
    case "$ZIP_FILE" in
      "$KIT_DIR"/tools/*) rm -f "$ZIP_FILE" ;;
    esac
    # recarrega o ambiente para descobrir a pasta extraída
    # shellcheck source=/dev/null
    . "$KIT_DIR/config/env.sh"
    ghidra_ok || die "Ghidra extraída, mas analyzeHeadless não foi encontrado em tools/"
    info "Ghidra pronta: $GHIDRA_INSTALL_DIR"
  fi
fi
echo

# ---------------------------------------------------------------------------
# 4. Registro MCP nos clientes de agente
# ---------------------------------------------------------------------------
echo "-- 4/7 Registro MCP"
if [ "$DRY_RUN" = 1 ]; then
  printf "[dry-run] rea setup --all-detected --yes\n"
else
  if rea setup --all-detected --yes >/tmp/eng-rea-setup.log 2>&1; then
    info "rea setup concluído"
  else
    warn "rea setup não concluiu (veja /tmp/eng-rea-setup.log)"
    tail -5 /tmp/eng-rea-setup.log 2>/dev/null | sed 's/^/       /'
  fi
fi

if [ "$DO_DECOMP" = 1 ]; then
  if command -v decomp >/dev/null 2>&1; then
    info "decomp.wtf já instalado: $(decomp --version 2>/dev/null || echo 'ok')"
  else
    info "instalando decomp.wtf (última versão disponível, 0.10.6)"
    if [ "$DRY_RUN" = 1 ]; then
      printf "[dry-run] curl -fsSL https://decomp.wtf/install.sh | bash -s -- --no-start\n"
    else
      if ! curl -fsSL https://decomp.wtf/install.sh | bash -s -- --no-start; then
        warn "instalação do decomp.wtf falhou; tente manualmente:
  curl -fsSL https://decomp.wtf/install.sh | bash"
      fi
    fi
  fi
fi

if command -v decomp >/dev/null 2>&1; then
  run decomp connect || warn "decomp connect não concluiu; rode 'decomp connect' depois"
fi
echo

# ---------------------------------------------------------------------------
# 5. Skills e agente
# ---------------------------------------------------------------------------
echo "-- 5/7 Skills e agente"
if [ "$DRY_RUN" = 1 ]; then
  printf "[dry-run] %s/bin/eng-registrar\n" "$KIT_DIR"
else
  chmod +x "$KIT_DIR"/bin/eng* 2>/dev/null || true
  "$KIT_DIR/bin/eng-registrar" || warn "eng registrar terminou com erro"
fi
echo

# ---------------------------------------------------------------------------
# 6. Integração com o shell
# ---------------------------------------------------------------------------
echo "-- 6/7 Shell"
if [ "$DO_SHELL" = 1 ]; then
  RC="$HOME/.bashrc"
  BEGIN="# >>> ENG. REVERSA >>>"
  END="# <<< ENG. REVERSA <<<"
  if [ "$DRY_RUN" = 1 ]; then
    printf "[dry-run] adicionar bloco em %s (se ausente)\n" "$RC"
    printf "[dry-run] ln -sfn %s/bin/eng %s/.local/bin/eng\n" "$KIT_DIR" "$HOME"
  else
    touch "$RC"
    if grep -qF "$BEGIN" "$RC"; then
      info "bloco já presente em $RC"
    else
      {
        printf '\n%s\n' "$BEGIN"
        printf 'if [ -f "%s/config/env.sh" ]; then\n' "$KIT_DIR"
        printf '  . "%s/config/env.sh"\n' "$KIT_DIR"
        printf 'fi\n'
        printf '%s\n' "$END"
      } >> "$RC" || warn "não foi possível escrever em $RC"
      info "bloco adicionado em $RC"
    fi
    mkdir -p "$HOME/.local/bin"
    ln -sfn "$KIT_DIR/bin/eng" "$HOME/.local/bin/eng"
    info "atalho: $HOME/.local/bin/eng"
  fi
else
  info "integração com o shell desativada (--no-shell)"
fi
echo

# ---------------------------------------------------------------------------
# 7. Verificação
# ---------------------------------------------------------------------------
echo "-- 7/7 Verificação"
if [ "$DRY_RUN" = 1 ]; then
  printf "[dry-run] %s/bin/eng doctor\n" "$KIT_DIR"
  echo
  echo "Dry-run concluído. Nada foi alterado."
  exit 0
fi

# shellcheck source=/dev/null
. "$KIT_DIR/config/env.sh"

echo
if "$KIT_DIR/bin/eng" doctor; then
  echo
  echo "============================================================"
  echo " Instalação concluída."
  echo "============================================================"
  echo " Próximos passos:"
  echo "   1. abra um terminal novo (ou: source ~/.bashrc)"
  echo "   2. reinicie o cliente de agente para carregar skills/MCP"
  echo "   3. peça: \"use a ENG. REVERSA para analisar <alvo>\""
  echo " Documentação: $KIT_DIR/docs/INSTALACAO.md"
  exit 0
else
  echo
  warn "O diagnóstico encontrou erros. Corrija os itens [ERRO] e rode:"
  echo "       $KIT_DIR/bin/eng doctor"
  exit 1
fi
