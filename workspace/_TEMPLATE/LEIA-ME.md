# Template de workspace

Copiado por `eng new <nome>`. Estrutura:

| Pasta | Conteúdo |
|-------|----------|
| `entrada/`      | link simbólico do alvo + amostras relacionadas |
| `analise/`      | TRIAGEM.md, NOTAS.md, exports do Ghidra/REA, dumps, strings |
| `reconstrucao/` | material recriado, espelhando a árvore do destino final |
| `relatorios/`   | relatórios finais (eng report --salvar) |

O `workspace.json` (criado por `eng new`) registra alvo, destino e descrição.
