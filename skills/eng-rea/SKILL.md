---
name: REA (Reverse Engineer Anything)
description: Usar a ferramenta REA (rea-agents / MCP "rea") para engenharia reversa de binários nativos, apps Electron/JavaScript, websites, APK Android, .NET, firmware, WASM, banco SQLite e capturas de rede. Use quando precisar de pseudocódigo, disassembly, xrefs, strings de um binário, entender um app sem código-fonte, ou quando o usuário citar REA, rea-agents, MCP rea, Ghidra headless via REA.
---

# REA — Reverse Engineer Anything (rea-agents 6.x)

REA roda localmente e devolve evidências (pseudocódigo, assembly, referências).
O toolkit configura o provider **Ghidra 12.1.x** dedicado em `tools/ghidra_*/`
(o REA exige a linha 12.1; uma instalação do sistema em outra versão não serve).

O wrapper `eng rea` garante o ambiente (carrega `GHIDRA_INSTALL_DIR` e
`JAVA_HOME`):

```bash
source "<raiz-do-toolkit>/config/env.sh"
eng rea <comando> ...          # == rea ... com o ambiente certo
```

Se `eng` já estiver no PATH, o `source` é opcional.

## Diagnóstico

```bash
eng rea doctor --json                        # saúde geral
eng rea doctor --provider ghidra --json      # só o motor Ghidra
```

## Comandos mais usados (CLI)

```bash
# Visão geral de um app/binário (sem abrir GUI)
eng rea analyze <caminho> --json

# Ler código: pseudocódigo de uma função (por nome ou endereço)
eng rea decompile <caminho> <símbolo|0xENDEREÇO> --format md

# Dossiê completo de uma função (código + chamadas + referências)
eng rea function <caminho> <símbolo|0xENDEREÇO> --json

# Inspeção/inventário
eng rea inspect <caminho> --json

# Electron/JS local (estático, sem provider): módulos, IPC, source maps
eng rea analyze-javascript-application <pasta-do-app-ou-asar> --json

# APK Android
eng rea inspect-android-package <app.apk> --json
eng rea inspect-android-method <app.apk> --class <Classe> --method <m> --json

# Firmware
eng rea extract-firmware <arquivo> --json

# .NET / CLR
eng rea analyze <assembly.dll> --json
eng rea demangle-swift <símbolo>              # símbolos Swift/Mach-O

# Rede / web
eng rea analyze-web-bundle <url> --json
eng rea inspect <captura.har> --json
```

Opções globais úteis: `--format md|json|yaml|jsonl`, `--token-limit <n>`,
`--filter-output chaves`, `--snapshot <arquivo>` (reusa análise entre chamadas),
`--llms` (manifesto para LLM), `--help` em qualquer comando.

Lista completa: `eng rea --help` (mais de 100 comandos).

## Via MCP

Se o cliente de agente tiver o servidor `rea` registrado, as ferramentas ficam
disponíveis nativamente na sessão (`open_binary`, `binary_session`,
`decompile`, ...). Prefira MCP para investigações interativas:
`binary_session` com `{}` lista a disponibilidade. Registro/checagem:

```bash
rea setup --all-detected --yes     # detecta e configura os clientes presentes
eng doctor                         # confere o que está registrado
```

## Boas práticas

1. Alvos grandes: use `--snapshot` para não reanalisar a cada chamada.
2. Economia de contexto: `--format md` + `--token-limit 4000`.
3. Cite sempre o endereço/função de origem das conclusões.
4. O provider Ghidra dedicado fica em `tools/ghidra_*/` (12.1.x). Rode
   `eng doctor` para ver o caminho e a versão exatos.
