---
name: decomp.wtf (games byte-a-byte)
description: Descompilação byte-a-byte de games retrô usando decomp.wtf (MCP "decomp") — N64, PlayStation 1/2, GameCube, Wii, GBA, DS. Use quando o alvo for uma ROM/imagem de disco/dispositivo de game e o objetivo for reconstruir o código C que compila EXATAMENTE para os mesmos bytes, criar projeto de decomp ou continuar um decomp público, ou quando o usuário citar decomp.wtf, decomp, splat, objdiff, m2c.
---

# decomp.wtf — descompilação com verificação byte-a-byte

Descompila games que **você possui**: cada função tentada é compilada com o
compilador original da época, ligada no endereço real e comparada byte a byte.
Só conta quando bate 100%.

Plataformas recomendadas: **GameCube, Wii, Nintendo 64** (mais testadas).
Beta: PS1, PS2, GBA, DS. Projetos ficam em `~/Decomp` por padrão.

> Projeto arquivado pelo autor (última versão 0.10.6) — segue funcionando,
> sem atualizações. Respeite a regra: apenas cópias suas; não publicar código
> descompilado de jogos de terceiros.

## Comandos

```bash
source "<raiz-do-toolkit>/config/env.sh"

eng decomp connect                 # 1x: registra o MCP nos clientes de agente detectados
eng decomp                         # abre o app no navegador (mapa ao vivo)
eng decomp connect --list          # status das conexões dos agentes
eng decomp import <rom|iso> <projeto> [--own-copy]   # importa sua cópia
eng decomp export <projeto> <pasta>                  # exporta árvore de decomp
eng decomp host <rom> --own-copy --address <url>     # sessão colaborativa
eng decomp --help
```

## Fluxo típico com agente

1. `eng decomp connect` (uma vez) e reinicie o cliente de agente.
2. `eng decomp import "<rom>" <nome-do-projeto>` — o app abre e faz o split
   (splat/spimdisasm) encontrando todas as funções.
3. No cliente com o MCP `decomp` registrado, as ferramentas ficam disponíveis:
   peça "descompile a função X do projeto Y". Agentes podem rodar em paralelo
   (`start_agents`) e o autopilot cobre as funções fáceis primeiro.
4. `eng decomp export <projeto> "<pasta>"` gera a árvore decompilável
   (C ligado + assembly do resto) que reconstrói a ROM byte a byte.

## Integração com o workspace do toolkit

- Importe a cópia do game a partir de `targets/` ou `workspace/<nome>/entrada/`.
- Exporte o resultado para `workspace/<nome>/analise/decomp-export/` para
  documentar, ou direto para `reconstrucao/` quando o destino final for um
  projeto de port/mod.
