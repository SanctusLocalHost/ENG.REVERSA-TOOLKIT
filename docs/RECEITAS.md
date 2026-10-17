# Receitas prontas por tipo de alvo

Cada receita assume o ambiente carregado
(`source "<raiz-do-toolkit>/config/env.sh"` ou `eng` já no PATH).
Antes de tudo: `eng doctor`.

---

## 1. APK Android (jogo/app)

```bash
eng triage game.apk --salvar meu-app
eng new meu-app --alvo game.apk --destino "<destino>"

# declarações, manifest, permissões
eng rea inspect-android-package game.apk --json
# método específico
eng rea inspect-android-method game.apk --class com.exemplo.MainActivity --method onCreate --json
# recursos (manifest decodificado, strings) — precisa apktool
eng rea decode-android-resources game.apk --json
```

- Se for **Unity IL2CPP** (libil2cpp.so): procure `global-metadata.dat` dentro
  do APK; ferramentas da comunidade (Il2CppDumper) + REA para libil2cpp.so.
- Se for **Flutter**: `eng rea identify-flutter-build game.apk --json`.
- Instale `jadx`/`apktool` para as rotas Java/Kotlin completas
  (`sudo apt install jadx apktool`, se disponível no repositório).

## 2. App Electron / JavaScript

```bash
eng triage meu-app --salvar app-js
eng new app-js --alvo meu-app --destino "<destino>"
eng rea analyze-javascript-application meu-app --json
# se só tiver o .asar: aponte para a pasta que contém o app.asar
```

Devolve módulos, imports, rotas, IPC (preload <-> main), source maps.

## 3. Binário nativo (ELF Linux / PE Windows)

```bash
eng triage bin --salvar bin-x
eng new bin-x --alvo bin --destino "<destino>"

eng rea analyze bin --json                     # visão geral
eng ghidra bin --ws bin-x                      # pseudocódigo C de tudo
eng rizin quick bin                            # disassembly/strings rápido
```

Acompanhe o `analise/ghidra-*/index-funcoes.tsv` para priorizar funções
(maiores primeiro). Para função interativa:

```bash
eng rea decompile bin 0x<endereço> --format md
```

## 4. .NET (dll/exe CLR)

```bash
eng triage app.dll --salvar dotnet-app
eng rea analyze app.dll --json                 # metadados, tipos, CIL
eng rea compare-managed-members a.dll b.dll    # comparar versões por assinatura
```

## 5. Game retrô (decomp byte-a-byte)

```bash
eng triage jogo.z64 --salvar jogo
eng decomp connect
eng decomp import jogo.z64 jogo                # sua cópia do game
# no app (navegador): acompanhe o mapa; no cliente com MCP os agentes trabalham
eng decomp export jogo ./workspace/jogo/analise/decomp-export
```

Plataformas: N64/GC/Wii (recomendados), PS1/PS2/GBA/DS (beta).

## 6. Firmware / imagem embarcada

```bash
eng triage firmware.bin --salvar fw
eng rea extract-firmware firmware.bin --json   # regiões + extração
binwalk -e firmware.bin                        # alternativa direta
# em seguida trate os ELFs extraídos como receita 3
```

## 7. WASM

```bash
eng triage modulo.wasm --salvar wasm-mod
eng rea inspect_wasm_artifact modulo.wasm --json
eng rea compare-wasm-interfaces a.wasm b.wasm --json
```

## 8. Web / capturas de rede

```bash
eng rea analyze-web-bundle https://alvo/app.js --json
eng rea export-web-scripts https://alvo --json      # baixa p/ análise estática
eng rea inspect captura.har --json                  # HAR/SAZ
tshark -r captura.pcap -Y http.request              # pacotes
```

## 9. GameMaker / Ren'Py / RPG Maker (engines de script)

```bash
eng triage data.win --salvar gm-game
# GameMaker: community tools (UndertaleModTool) para data.win; REA/rizin p/ runner nativo
# Ren'Py:  unrpa/unrpyc (pip install unrpa unrpyc) p/ .rpa/.rpyc
# RPG Maker: extrair .rgss3a (rgss extractor); .rxdata com Marshal (Ruby) — ruby -e
eng rizin quick "runner-nativo"                # engine nativa em paralelo
```

## 10. Python congelado (PyInstaller)

```bash
eng triage app --salvar pyapp
# 1. extrair: pyinstxtractor-ng "app" (pip install pyinstxtractor-ng)
# 2. bytecode: pycdc/decompyle3 para os .pyc extraídos
# 3. paralelo: eng ghidra app --ws pyapp  (o loader nativo também revela muito)
```

## 11. Debug em execução (entender comportamento ao vivo)

```bash
eng rea debug-with-rizin --help      # comandos rizin de debug em sessão efêmera
eng rea debug-with-gdb --help        # comandos GDB (precisa de TTY p/ inferior vivo)
eng rea capture-process <alvo> --json # captura de execução (PTY) com evidências
gdb -p <pid> / gdb --args <executável>   # debug manual clássico
```

## 12. Comparar versões (o que mudou entre builds?)

```bash
eng rea compare a.json b.json                      # Evidence bundles canônicos
eng rizin diff v1.elf v2.elf                       # seções/tamanhos
cmp -l a b | head                                  # bytes divergentes
```

---

## Economia de contexto (agente de IA)

- Prefira `--format md` e `--token-limit`.
- Use `--snapshot` para não pagar análise repetida.
- Leia `index-funcoes.tsv` e escolha funções alvo em vez de despejar tudo.
- Grave artefatos grandes em arquivo (`analise/`) e leia só o necessário.
