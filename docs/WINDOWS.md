# Windows

O toolkit usa bash, ELF e ferramentas Linux. No Windows ele roda dentro do
**WSL2 (Ubuntu)**, que é também o caminho oficial do decomp.wtf. Há dois modos
de uso:

| Modo | Onde o agente roda | Indicado para |
|------|--------------------|---------------|
| **A. Tudo no WSL2** | dentro do Ubuntu (WSL) | paridade total, mais simples e estável |
| **B. Agente no Windows** | no Windows, com MCP/atalho apontando para o WSL | quem prefere o cliente no Windows |

Nos dois casos o toolkit, o REA, a Ghidra e o decomp.wtf ficam dentro do WSL.

---

## Pré-requisitos

- Windows 10 versão 2004+ ou Windows 11
- Virtualização habilitada na BIOS/UEFI
- WSL2 com uma distro Ubuntu
- Acesso ao repositório privado (GitHub autenticado)

Instalar o WSL2 (PowerShell como administrador, uma vez):

```powershell
wsl --install -d Ubuntu
```

Reinicie se o Windows pedir. Abra o Ubuntu pelo menu Iniciar e conclua a
criação do usuário/senha.

---

## Opção A — tudo dentro do WSL2 (recomendada)

Abra o Ubuntu (WSL) e rode:

```bash
sudo apt update
sudo apt install -y git curl unzip tar python3 openjdk-21-jdk

# Node 22/24/26+ (recomendado via nvm)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
source ~/.nvm/nvm.sh
nvm install 24

# repositório privado: autentique-se antes
gh auth login          # ou configure uma chave SSH
gh repo clone SanctusLocalHost/eng-reversa
cd eng-reversa
./install.sh
```

Opcional, para games retrô:

```bash
./install.sh --with-decomp-wtf
```

Depois disso, rode o agente **dentro do WSL** (mesmo terminal). Skills, agente
e servidores MCP são registrados no ambiente Linux, exatamente como em uma
máquina Linux comum.

Se preferir, o próprio instalador prepara os pacotes, o JDK, o Node, copia o
toolkit e roda o `install.sh` por você: use a Opção B e depois abra o Ubuntu.

---

## Opção B — agente no Windows + backend no WSL

1. Clone o repositório privado no Windows (GitHub Desktop, `gh repo clone` ou
   `git clone` com suas credenciais).
2. Abra o PowerShell na pasta clonada e rode:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

O instalador:

1. verifica o WSL2 e escolhe a distro (padrão: Ubuntu);
2. prepara o Ubuntu (`windows/wsl-prepare.sh`): pacotes, JDK 21 e Node;
3. copia o toolkit para `~/eng-reversa` dentro do WSL;
4. roda o `install.sh` (REA, Ghidra, skills, agente, MCP no WSL);
5. cria a ponte MCP (`windows/mcp-bridge.sh`);
6. registra `rea` e `decomp` na configuração do cliente de agente no Windows,
   apontando para `wsl.exe`, e copia as skills/agente para o cliente;
7. instala os atalhos `eng.ps1` e `eng.cmd` em `%USERPROFILE%\.local\bin` e
   adiciona essa pasta ao PATH do usuário.

Opções:

```powershell
.\install.ps1 -WithDecompWtf     # instala o decomp.wtf no WSL
.\install.ps1 -SkipGhidra        # usa uma Ghidra já instalada
.\install.ps1 -SkipPrereqs       # não instala pacotes/JDK/Node
.\install.ps1 -NoWindowsMcp      # não altera a config do cliente
.\install.ps1 -NoShims           # não cria os atalhos eng
.\install.ps1 -Distro Ubuntu-24.04
.\install.ps1 -InstallWsl        # tenta instalar o WSL2 se faltar
.\install.ps1 -Help
```

Depois: abra um PowerShell novo, teste `eng doctor` e reinicie o cliente de
agente.

### Como o atalho `eng` funciona no Windows

```powershell
eng doctor
eng new meu-projeto --alvo "C:\jogos\meu-jogo" --destino "D:\projetos\meu-port"
```

O atalho converte caminhos `C:\...` para `/mnt/c/...` e executa o comando
dentro do WSL. Para caminhos com espaços, use aspas. Se algo não funcionar no
`cmd`, use PowerShell.

O mesmo vale para o agente: ele chama `eng ...` no Windows, o atalho encaminha
para o WSL e devolve a saída.

---

## Caminhos e desempenho

- `C:\Users\voce\...` = `/mnt/c/Users/voce/...` no WSL.
- `D:\...` = `/mnt/d/...`.
- Trabalhe com os alvos e workspaces dentro do WSL (`~/...`) quando possível:
  `/mnt/c` é bem mais lento para análise, I/O do Ghidra e builds.
- Para acessar arquivos do WSL pelo Explorer: `\\wsl.localhost\Ubuntu\home\<usuario>`.

---

## decomp.wtf

Use `-WithDecompWtf` (Opção B) ou `./install.sh --with-decomp-wtf` (Opção A).
O decomp.wtf roda dentro do mesmo Ubuntu; os compiladores periódicos são
instalados por ele. O instalador nativo do decomp.wtf para Windows cria outra
distro WSL e não é necessário aqui.

---

## Atualização

Opção A (dentro do WSL):

```bash
cd ~/eng-reversa
git pull
./install.sh
```

Opção B (no Windows):

```powershell
cd <pasta-do-clone>
git pull
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

O `install.ps1` é idempotente e reaplica apenas o que mudou.

---

## Solução de problemas

| Sintoma | Ação |
|---------|------|
| `wsl` não reconhecido | Atualize o Windows e rode `wsl --install` como administrador; reinicie |
| Nenhuma distro encontrada | `wsl --install -d Ubuntu`; abra o Ubuntu uma vez |
| Erro de virtualização | Habilite VT-x/AMD-V na BIOS/UEFI |
| `eng` não encontrado no Windows | Abra um PowerShell novo; confira `%USERPROFILE%\.local\bin` no PATH |
| Caminho com espaços quebra | Use aspas; prefira PowerShell ao `cmd` |
| MCP não aparece no cliente | Reinicie o cliente; confira o registro na config; rode o wrapper manualmente no WSL |
| `wsl --shutdown` travou o MCP | Reabra o WSL (`wsl -d Ubuntu -- true`) e reinicie o cliente |
| Node antigo no WSL | `nvm install 24 && nvm alias default 24` |
| JDK ausente/antigo | `sudo apt install -y openjdk-21-jdk`; confira `JAVA_HOME` |
| Ghidra sem memória | `GHIDRA_MAXMEM=1G` antes de `eng ghidra` |
| Análise lenta | Mova o alvo/workspace de `/mnt/c` para `~/` no WSL |
| Clone privado nega acesso | `gh auth login` ou configure chave SSH no WSL/Windows |

Diagnóstico:

```powershell
eng doctor
wsl -d Ubuntu -- bash -lc "cd ~/eng-reversa && ./bin/eng doctor --deep"
```

---

## Desinstalação

No Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 -RemoveWsl -Purge
```

- Sem `-RemoveWsl`: remove atalhos, MCP e skills do cliente Windows; preserva o
  toolkit no WSL.
- Com `-RemoveWsl`: roda também o `uninstall.sh` dentro do WSL.
- Com `-Purge`: remove a Ghidra baixada (`tools/`).

Pacotes globais (`rea-agents`, `decomp.wtf`) não são removidos
automaticamente; o `uninstall.sh` mostra os comandos.
