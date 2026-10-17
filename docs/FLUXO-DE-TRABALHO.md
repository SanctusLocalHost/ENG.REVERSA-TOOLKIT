# Fluxo de trabalho — do artefato à recriação

Este documento detalha o ciclo completo usado por humanos **e** pelo agente de
IA. Todos os comandos assumem que o ambiente está carregado:

```bash
source "<raiz-do-toolkit>/config/env.sh"
```

Se `eng` já estiver no PATH (instalação padrão), o `source` é opcional.

---

## Fase 0 — Prontidão

```bash
eng doctor          # rápido: ferramentas instaladas?
eng doctor --deep   # + validação do provider Ghidra do REA (mais lento)
```

## Fase 1 — Workspace

```bash
eng new meu-jogo \
  --alvo "/caminho/do/alvo" \
  --destino "/caminho/do/projeto-que-vai-receber-a-recriacao" \
  --descricao "o que queremos entender/recriar"
```

Cria `workspace/meu-jogo/`:

```
entrada/       link simbólico para o alvo (o original nunca é tocado)
analise/       triagem, pseudocódigo, notas, evidências
reconstrucao/  código/assets recriados (espelha a árvore do destino)
relatorios/    relatórios finais
```

O destino fica registrado no `workspace.json`. `eng publish` usa esse caminho.

## Fase 2 — Triagem

```bash
eng triage "<alvo>" --salvar meu-jogo
```

Saída: tipo real do arquivo, hash SHA-256, sinais (engine, packing, .NET,
Unity, Electron, ROM...) e o **motor recomendado** com comandos prontos.
Resultado salvo em `analise/TRIAGEM.md`.

## Fase 3 — Análise por motor

### 3a. REA — binários e aplicações

```bash
# visão geral
eng rea analyze "<alvo>" --json

# pseudocódigo de uma função específica
eng rea decompile "<alvo>" 0x401000 --format md

# dossiê de função (código + quem chama + referências)
eng rea function "<alvo>" <nome-ou-endereço> --json

# usar snapshot evita reanalisar a cada chamada (bom para alvos grandes)
eng rea analyze "<alvo>" --snapshot analise/sessao.json --json
eng rea decompile "<alvo>" main --snapshot analise/sessao.json --format md
```

Economia de contexto: `--format md`, `--token-limit 4000`,
`--filter-output <chaves>`.

### 3b. Ghidra headless — pseudocódigo em massa

```bash
eng ghidra "<alvo>" --ws meu-jogo        # -> analise/ghidra-<data>/
# gera: index-funcoes.tsv, strings.tsv e UM .c POR FUNÇÃO
```

Binários grandes: aumente `--timeout`; force arquitetura com
`--processor x86:LE:64:default` (ou `ARM:LE:32:v7`, etc.) quando a
auto-detecção falhar.

### 3c. decomp.wtf — games (byte-a-byte)

```bash
eng decomp connect                   # 1x: registra o MCP nos clientes detectados
eng decomp import "<rom>" meu-game   # sua cópia; o app abre no navegador
# no cliente com MCP: as ferramentas 'decomp' assumem daqui (autopilot, agentes)
eng decomp export meu-game workspace/meu-jogo/analise/decomp-export
```

### 3d. rizin — perguntas rápidas

```bash
eng rizin quick "<alvo>"                          # info+seções+funções+strings
eng rizin -q -c 'aa; pdf @ main' "<alvo>"          # disassembly de main
eng rizin -q -c 'aa; axt @ sym.imp.malloc' "<alvo>" # quem chama malloc
```

## Fase 4 — Documentação com evidência

Em `analise/NOTAS.md`, registre por descoberta:

```markdown
## Como funciona o sistema de dano
- Fonte: `index-funcoes.tsv` -> `00402a10_calc_damage` (Ghidra export 2026-10-17)
- Evidência: pseudocódigo em `analise/ghidra-20261017-1430/00402a10_calc_damage.c`
- Regra: dano = ataque * (1 - defesa/100) + rand(0..3)
- Equivalente recriado em: `reconstrucao/src/dano.py:12`
```

## Fase 5 — Reconstrução

Escreva em `reconstrucao/` **espelhando a árvore do diretório destino**.
Exemplo: se o destino tem `src/sistemas/dano.py`, a recriação fica em
`reconstrucao/src/sistemas/dano.py`. Assim `eng publish` só copia.

Checklist mínimo:

- [ ] Comportamento reproduzido e testado localmente
- [ ] Cada peça rastreável a uma evidência da análise
- [ ] Nada de artefato proprietário copiado integralmente (assets, ROMs)
- [ ] `eng report meu-jogo --salvar` gerou o relatório final

## Fase 6 — Publicação

```bash
eng report meu-jogo              # confere o estado
eng publish meu-jogo             # DRY-RUN — veja a lista de cópias
eng publish meu-jogo --exec      # aplica no destino registrado
```

---

## Referência rápida de erros

| Sintoma | Ação |
|---------|------|
| `eng: command not found` | `source <raiz>/config/env.sh` ou `source ~/.bashrc` |
| REA reclama do Ghidra | `eng doctor --deep`; confirme `GHIDRA_INSTALL_DIR` 12.1.x |
| Ghidra headless sem index | use `--processor`; veja o log no terminal |
| Falta RAM (OOM) | reduza `GHIDRA_MAXMEM` (ex.: `1G`) ou feche outros apps |
| MCP não aparece no cliente | reinicie o cliente; `eng doctor` mostra o registro |
| Skills não aparecem | `eng registrar` e reinicie o cliente |
| decomp.wtf pede atualização | projeto arquivado — ignore; 0.10.6 é a última |
