# Arquitetura

## Visão geral

```
<raiz-do-toolkit>/
├── README.md              guia rápido
├── install.sh             instalador de restauração (idempotente)
├── uninstall.sh           remove integrações
├── install.ps1            instalador Windows (WSL2)
├── uninstall.ps1          desinstalador Windows
├── windows/               preparação do WSL, ponte MCP e atalhos eng
├── bin/                   CLI modular: `eng <comando>` (cada comando = 1 arquivo)
├── config/
│   └── env.sh             ambiente central (carregado por todos os scripts)
├── skills/                skills do agente (SKILL.md por ferramenta)
│   ├── eng-reversa/       skill principal (fluxo completo)
│   ├── eng-rea/           REA (binários, apps, APK, Electron, .NET...)
│   └── eng-decomp/        decomp.wtf (games byte-a-byte)
├── agents/
│   └── eng-reversa.md     perfil de agente (linkado nos clientes detectados)
├── ghidra-scripts/        scripts Java para Ghidra headless
├── docs/                  documentação detalhada
├── tools/                 Ghidra dedicada (baixada no install; fora do git)
├── workspace/             UM DIRETÓRIO POR ANÁLISE (o trabalho acontece aqui)
│   └── _TEMPLATE/
├── targets/               artefatos originais, somente leitura (fora do git)
└── exports/               resultados avulsos (fora de workspaces)
```

A raiz é resolvida dinamicamente por `config/env.sh` a partir da localização
do próprio arquivo. A pasta pode ser movida ou clonada em qualquer caminho,
inclusive com espaços, sem alterar scripts.

## Comandos (bin/)

| Comando | Função |
|---------|--------|
| `eng doctor [--deep]` | Diagnóstico de todas as ferramentas |
| `eng triage <alvo> [--salvar ws]` | Classifica o alvo e recomenda o motor |
| `eng new <nome> [--alvo] [--destino]` | Cria workspace de análise |
| `eng list [--json]` | Lista workspaces |
| `eng report <nome> [--salvar]` | Resumo do estado do workspace |
| `eng publish <nome> [--exec]` | Publica a reconstrução no destino (dry-run padrão) |
| `eng rea ...` | REA com ambiente correto |
| `eng decomp ...` | decomp.wtf |
| `eng ghidra <bin> [--ws N]` | Exportação massiva de pseudocódigo |
| `eng rizin [quick\|diff\|...]` | Inspeção rápida |
| `eng registrar` | (Re)instala skills e agente nos clientes de agente |
| `eng env [--shell]` | Mostra variáveis de ambiente |

Adicionar um comando novo: crie `bin/eng-<novo>` executável — o dispatcher
encontra automaticamente. O padrão de cada script:

```bash
#!/usr/bin/env bash
set -uo pipefail
ENG_REV_HOME="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
source "$ENG_REV_HOME/config/env.sh"
# ... implementação ...
```

## Ambiente (config/env.sh)

| Variável | Papel |
|----------|-------|
| `ENG_REV_HOME` / `ENG_REVERSA` | Raiz do toolkit (resolvida dinamicamente) |
| `ENG_REV_BIN`, `ENG_REV_TOOLS`, `ENG_REV_DOCS` | Diretórios internos |
| `GHIDRA_INSTALL_DIR` | Ghidra dedicada em `tools/ghidra_*/` (descoberta automática, preferência 12.1.x) |
| `JAVA_HOME` | JDK 21+ (detectado entre candidatos comuns) |
| `GHIDRA_MAXMEM` | Heap do Ghidra (padrão `2G`; reduza em máquinas com pouca RAM) |
| `PATH` | Inclui `bin/` e `~/.local/bin` (uv/decomp) |

`config/env.sh` é seguro para `source` repetido e não depende de arquivos
pessoais.

## Ferramentas

| Ferramenta | Onde | Papel |
|-----------|------|-------|
| **rea-agents** | npm global | MCP + CLI de RE (provider Ghidra) |
| **Ghidra 12.1.x** | `tools/ghidra_*_PUBLIC` | Motor de descompilação do REA + headless |
| **decomp.wtf** (opcional) | uv tool (`~/.local/bin/decomp`) | Decomp byte-a-byte de games |
| **rizin** | sistema | Disassembly rápido |
| **binwalk, tshark, gdb, objdump** | sistema | Apoio (firmware, rede, debug, ELF) |

Versões mínimas e instalação: `docs/INSTALACAO.md`.

## Integração com clientes de agente

O toolkit não depende de um cliente específico. O registro tem três partes:

1. **Skills** — `eng registrar` cria links simbólicos de `skills/*` em
   `<raiz-do-cliente>/skills/` para cada diretório de cliente detectado, além
   de `~/.agents/skills/` (convenção compartilhada).
2. **Agente** — link de `agents/eng-reversa.md` em `<raiz-do-cliente>/agents/`.
3. **MCP** — `rea setup --all-detected --yes` e `decomp connect` registram os
   servidores nas configurações dos clientes que as ferramentas reconhecem.

Depois de qualquer mudança de registro, **reinicie o cliente de agente**.
`eng doctor` mostra quais configurações contêm `rea`/`decomp` e quantas skills
estão linkadas.

No **Windows**, o registro tem uma ponte adicional: `install.ps1` cria
`mcp-rea.sh`/`mcp-decomp.sh` dentro do WSL e aponta os servidores MCP do
cliente nativo para `wsl.exe`. O atalho `eng` encaminha comandos e converte
caminhos `C:\...` em `/mnt/c/...`.
