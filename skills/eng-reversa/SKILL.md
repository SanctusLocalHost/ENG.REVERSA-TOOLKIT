---
name: Eng. Reversa
description: Engenharia reversa assistida por IA de software e games — descompilar, entender o funcionamento e recriar o comportamento no destino correto. Use quando o pedido envolver reverse engineering, descompilação, decompilar, analisar binário/APK/ROM/exe, extrair código de um app ou jogo, entender como uma funcionalidade funciona internamente, reconstruir/portar algo a partir de um artefato, ou quando o usuário citar "ENG. REVERSA", REA, decomp.wtf, Ghidra, rizin ou splat.
---

# ENG. REVERSA — fluxo padrão

Toolkit de engenharia reversa em um único diretório. A raiz é a pasta que
contém `bin/`, `config/`, `skills/` e `docs/` (este arquivo fica em
`skills/eng-reversa/SKILL.md`, dois níveis abaixo da raiz).

Todos os comandos usam a CLI `eng`. Se `eng` não estiver no PATH, carregue o
ambiente a partir da raiz:

```bash
source "<raiz-do-toolkit>/config/env.sh"
```

`eng env` mostra a raiz resolvida e todas as variáveis. O instalador
(`./install.sh`) já coloca `eng` no PATH e registra as skills no cliente de
agente. No Windows, o atalho `eng` (PowerShell) encaminha para o WSL e converte
caminhos `C:\...` em `/mnt/c/...`.

## Fluxo obrigatório (siga nesta ordem)

### 1. Verificar prontidão (1x por sessão)

```bash
eng doctor            # rápido
eng doctor --deep     # inclui validação do Ghidra pelo REA (mais lento)
```

Corrija qualquer item `[ERRO]` antes de prosseguir.

### 2. Criar um workspace para o alvo

```bash
eng new <nome-do-projeto> \
  --alvo "<caminho do software/game>" \
  --destino "<pasta onde a versão recriada deve ficar>" \
  --descricao "objetivo da análise"
```

- `--alvo` é o artefato original (exe, apk, ELF, ROM, pasta do app).
- `--destino` é **onde o resultado reconstruído será publicado** — a pasta do
  projeto que receberá o port/reimplementação.
- O workspace fica em `workspace/<nome>/` com
  `entrada/ analise/ reconstrucao/ relatorios/`.

### 3. Triagem do alvo (define o motor)

```bash
eng triage "<caminho do alvo>" --salvar <nome-do-projeto>
```

A triagem classifica o arquivo (ELF/PE/.NET/APK/Unity/Electron/ROM/WASM...)
e imprime o **motor recomendado** + comandos de próximo passo.

### 4. Escolha do motor (resumo)

| Alvo | Motor | Comando base |
|------|-------|--------------|
| Binário nativo (ELF/PE/Mach-O), DOS, firmware | **REA** + Ghidra | `eng rea analyze <alvo> --json` |
| App Electron/JavaScript, website | **REA** (estático) | `eng rea analyze-javascript-application <pasta> --json` |
| APK Android (Java/Kotlin) | **REA** (+ jadx se instalado) | `eng rea inspect-android-package <apk> --json` |
| .NET / CLR (dll/exe) | **REA** (estático) | `eng rea analyze <dll> --json` |
| Game retrô (N64, PS1/2, GC/Wii, GBA, DS) — descompilação byte-a-byte | **decomp.wtf** | `eng decomp import <rom> <projeto>` |
| Pseudocódigo C em massa de qualquer binário | **Ghidra headless** | `eng ghidra <binario> --ws <projeto>` |
| Disassembly/refs/strings rápidos | **rizin** | `eng rizin quick <binario>` |
| Debug em execução | REA: `debug-with-gdb`, `debug-with-rizin` | `eng rea debug-with-rizin --help` |

MCP: se o cliente de agente tiver os servidores **rea** e **decomp**
registrados, as ferramentas equivalentes ficam disponíveis nativamente na
sessão, sem shell. O registro é feito pelo instalador (`rea setup`,
`decomp connect`) e pode ser conferido com `eng doctor`.

### 5. Analisar e documentar

- Guarde TODA evidência em `workspace/<nome>/analise/`:
  - saída do Ghidra (`eng ghidra <bin> --ws <nome>`) → `analise/ghidra-*/`
  - trechos de pseudocódigo originais e traduções comentadas
  - `strings`, capturas, dumps, resultados de `eng rea ... --json`
- Use `--format md`/`--json`/`--token-limit` no REA para controlar o tamanho.
- Anote em `analise/NOTAS.md` o que foi descoberto, com endereço/arquivo de
  origem de cada conclusão (rastreabilidade).

### 6. Recriar em `reconstrucao/` (espelhando o destino)

- Escreva o código/asset recriado em `workspace/<nome>/reconstrucao/` com a
  **mesma árvore de pastas** do diretório destino final.
- Regra: recriar comportamento, não copiar artefatos proprietários linha a
  linha. Documente equivalência funcional.
- Teste localmente antes de publicar.

### 7. Publicar no diretório destino

```bash
eng report <nome>                 # estado atual
eng publish <nome>                # DRY-RUN: mostra o que copiaria
eng publish <nome> --exec         # aplica no diretório destino registrado
```

## Regras fixas

1. **Nunca modifique o alvo original** — `targets/` e o alvo em `entrada/` são
   somente leitura.
2. **Publique só via `eng publish`** (dry-run por padrão) para deixar rastro.
3. **Registre evidências** junto de cada conclusão; sem fonte não é resultado.
4. Licenças: analise apenas software que você possui/autorizou. Não publique
   código descompilado de terceiros.
5. Em caso de erro de ferramenta, rode `eng doctor --deep` e siga as dicas.

## Onde está cada coisa

- `bin/` — comandos `eng-*` (modulares; crie um novo com `bin/eng-<novo>`).
- `docs/INSTALACAO.md` — instalação, atualização e solução de problemas.
- `docs/FLUXO-DE-TRABALHO.md` — detalhamento com exemplos por tipo de alvo.
- `docs/RECEITAS.md` — receitas prontas (APK, Unity, Electron, ROM, .NET...).
- `docs/ARQUITETURA.md` — layout completo, env, ferramentas.
