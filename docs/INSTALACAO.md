# Instalação e manutenção

Este documento cobre a instalação em uma máquina nova, a atualização e a
solução de problemas. O caminho curto é:

```bash
gh auth login
gh repo clone SanctusLocalHost/eng-reversa
cd eng-reversa
./install.sh
```

No **Windows**, use WSL2 e siga `docs/WINDOWS.md` (há um instalador PowerShell
que prepara o WSL e registra tudo no cliente do Windows).

O instalador trabalha **na própria pasta clonada**. Use `--home <dir>` para
copiar o toolkit para outro lugar antes de instalar.

---

## 1. Pré-requisitos

| Item | Versão | Observação |
|------|--------|------------|
| Linux | x86_64 | Testado em Debian/Ubuntu-like; macOS experimental |
| Node.js | 22.x, 24.x ou 26+ | O REA não aceita versões fora dessa faixa |
| npm | junto com o Node | Instala o `rea-agents` globalmente |
| JDK | 21+ | O Ghidra 12.1 exige JDK 21; `JAVA_HOME` é detectado |
| Python 3 | 3.9+ | Usado pelo instalador e scripts auxiliares |
| git, curl, tar, unzip | recentes | Download e extração da Ghidra |
| Espaço em disco | ~2,5 GB | Ghidra extraída + cache npm |

Instalação dos pré-requisitos no Debian/Ubuntu (exemplo):

```bash
sudo apt update
sudo apt install -y git curl unzip tar python3 openjdk-21-jdk
# Node 22/24: prefira o nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
source ~/.nvm/nvm.sh
nvm install 24
```

Ferramentas opcionais, por tipo de alvo:

```bash
sudo apt install -y rizin binwalk gdb tshark jadx apktool
```

## 2. O que o instalador faz

1. **Verificações** — sistema, Node, npm, Java, Python, git, curl, tar, unzip.
2. **REA** — `npm install --global rea-agents@latest` (pulado se já estiver na
   versão mais recente).
3. **Ghidra** — baixa a release 12.1.x mais recente do repositório oficial e
   extrai em `tools/ghidra_<versao>_PUBLIC/`. Se `GHIDRA_INSTALL_DIR` já
   apontar para uma instalação 12.1.x válida, ela é reutilizada. Para usar um
   zip local: `GHIDRA_ZIP=/caminho/ghidra.zip ./install.sh`.
4. **Provider** — roda `rea doctor --provider ghidra` e mostra o resultado.
5. **MCP** — `rea setup --all-detected --yes` registra o servidor `rea` em
   todos os clientes de agente detectados. Se o decomp.wtf estiver instalado,
   `decomp connect` registra o servidor `decomp`.
6. **Skills e agente** — `eng registrar` instala links simbólicos nos
   diretórios de skills/agentes dos clientes detectados e em
   `~/.agents/skills/`.
7. **Shell** — adiciona um bloco protegido em `~/.bashrc` que carrega
   `config/env.sh`, e cria o atalho `~/.local/bin/eng`.
8. **Verificação** — roda `eng doctor`.

## 3. Opções do instalador

```bash
./install.sh --help
./install.sh --dry-run           # plano completo, sem executar
./install.sh --yes               # sem confirmações
./install.sh --no-ghidra         # não baixa Ghidra (usa GHIDRA_INSTALL_DIR)
./install.sh --with-decomp-wtf   # instala o decomp.wtf e conecta o MCP
./install.sh --no-shell          # não altera o ~/.bashrc
./install.sh --home ~/Softwares/eng-reversa
./install.sh --force             # permite --home em pasta não vazia
```

## 4. Verificação

```bash
eng doctor            # rápido
eng doctor --deep     # inclui o diagnóstico do provider Ghidra
eng env               # raiz, JAVA_HOME, GHIDRA_INSTALL_DIR, PATH
```

Teste de fumaça do Ghidra headless (gera pseudocódigo de um binário pequeno):

```bash
eng ghidra /bin/true --out /tmp/teste-ghidra
ls /tmp/teste-ghidra | head
```

## 5. Uso em outra máquina (restauração)

1. Instale os pré-requisitos da seção 1.
2. Clone o repositório privado (autentique-se antes) e rode `./install.sh`.
3. Abra um terminal novo e reinicie o cliente de agente.
4. Confirme com `eng doctor` e peça ao agente: "use a ENG. REVERSA para
   analisar <alvo>".

No **Windows**, use WSL2 e siga `docs/WINDOWS.md`:

```powershell
# clone no Windows, depois:
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

O instalador PowerShell prepara o Ubuntu do WSL, copia o toolkit, roda o
`install.sh` e registra MCP/skills no cliente do Windows.

Os dados de trabalho (`workspace/`, `targets/`, `exports/` e `tools/`) não vão
para o git: cada máquina baixa a Ghidra e cria seus próprios workspaces.

## 6. Atualização

```bash
git pull
./install.sh
```

O instalador é idempotente: reinstala apenas o que falta ou mudou de versão.
Depois de mover a pasta do toolkit, rode `eng registrar` para atualizar os
links simbólicos.

## 7. Solução de problemas

| Sintoma | Causa provável | Ação |
|---------|----------------|------|
| `eng: command not found` | shell sem o bloco do toolkit | `source ~/.bashrc` ou `source <raiz>/config/env.sh` |
| REA reclama da versão do Ghidra | versão fora da linha 12.1 | confira `eng doctor`; baixe 12.1.x em `tools/` |
| `UnsupportedClassVersionError` | JDK antigo | instale JDK 21+ e ajuste `JAVA_HOME` |
| Ghidra headless morre por memória | heap alto para a RAM disponível | `GHIDRA_MAXMEM=1G eng ghidra ...` |
| Provider Ghidra não encontrado | `GHIDRA_INSTALL_DIR` inválido | `eng doctor`; reexporte a variável ou rode o instalador |
| MCP não aparece no cliente | cliente não reiniciado | reinicie o cliente; rode `rea setup --all-detected --yes` |
| Skills não aparecem | links ausentes | `eng registrar` e reinicie o cliente |
| Downloads falham | proxy/rede | use `GHIDRA_ZIP` local e `npm config set proxy ...` |
| Pouco espaço | Ghidra + cache | libere ~3 GB ou use `--no-ghidra` com instalação externa |

Logs úteis:

```bash
eng doctor --deep
rea doctor --json > /tmp/rea-doctor.json
```

## 8. Desinstalação

```bash
./uninstall.sh            # remove bloco do shell e links nos clientes
./uninstall.sh --purge    # remove também tools/ (Ghidra baixada)
```

Para remover os pacotes globais:

```bash
npm uninstall --global rea-agents
uv tool uninstall decomp.wtf   # se instalado
```
