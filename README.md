# ENG. REVERSA

Toolkit de engenharia reversa assistida por IA: **descompilar, entender e
recriar** software e games. Uma CLI modular (`eng`), um workspace por alvo,
skills e um agente prontos para clientes de agente de IA, e os melhores motores
open source de análise.

```
alvo  ->  triagem  ->  análise (REA / Ghidra / decomp.wtf / rizin)
      ->  evidências  ->  reconstrução  ->  publicação no diretório destino
```

## O que vem pronto

| Recurso | Papel |
|---------|-------|
| **REA** (rea-agents) | CLI + servidor MCP de engenharia reversa: binários nativos, Electron/JavaScript, APK, .NET, firmware, WASM, rede |
| **Ghidra 12.1.x dedicada** | Provider do REA e exportação headless de pseudocódigo C |
| **decomp.wtf** (opcional) | Descompilação byte-a-byte de games N64, PS1/PS2, GameCube, Wii, GBA, DS |
| **rizin** | Disassembly, xrefs e strings rápidos |
| **`eng`** | Dispatcher modular: `doctor`, `triage`, `new`, `list`, `report`, `publish`, `rea`, `decomp`, `ghidra`, `rizin`, `registrar`, `env` |
| **Skills + agente** | Instruções de fluxo para o agente de IA e registro automático nos clientes detectados |

## Requisitos

- Linux x86_64 (testado); Windows via WSL2; macOS deve funcionar com ajustes
- Node.js 22.x, 24.x ou 26+ e npm
- JDK 21+ (o Ghidra 12.1 exige JDK 21)
- Python 3, git, curl, tar, unzip
- Aproximadamente 2,5 GB livres (Ghidra e cache do npm)
- Opcionais: `rizin`, `binwalk`, `gdb`, `tshark`, `jadx`, `apktool`

## Instalação

Repositório privado: autentique-se antes de clonar.

```bash
gh auth login
gh repo clone SanctusLocalHost/eng-reversa
cd eng-reversa
./install.sh
```

Sem o `gh`, use `git clone https://github.com/SanctusLocalHost/eng-reversa.git`
com um token de acesso pessoal ou uma chave SSH configurada.

No **Windows**, use o WSL2. Há duas opções: rodar tudo dentro do Ubuntu do WSL
(paridade total) ou usar o instalador PowerShell, que prepara o WSL, copia o
toolkit, registra MCP/skills no cliente do Windows e cria o atalho `eng`.
Passo a passo: `docs/WINDOWS.md`.

O instalador é idempotente e faz, em ordem:

1. valida os pré-requisitos e versões;
2. instala `rea-agents` globalmente via npm;
3. baixa a Ghidra 12.1.x para `tools/` (ou reutiliza a existente);
4. valida o provider Ghidra do REA;
5. registra os servidores MCP nos clientes de agente detectados (`rea setup --all-detected`, `decomp connect` quando instalado);
6. instala as skills e o agente nos diretórios dos clientes detectados;
7. integra ao shell (`~/.bashrc` + atalho `~/.local/bin/eng`);
8. roda `eng doctor` e mostra o resultado.

Opções úteis:

```bash
./install.sh --dry-run          # mostra o plano sem executar
./install.sh --yes              # não pergunta nada
./install.sh --no-ghidra        # usa uma Ghidra já instalada (GHIDRA_INSTALL_DIR)
./install.sh --with-decomp-wtf  # instala também o decomp.wtf (games retrô)
./install.sh --no-shell         # não altera o ~/.bashrc
./install.sh --home <dir>       # copia o toolkit para <dir> e instala a partir dele
```

Depois da instalação, abra um terminal novo (ou `source ~/.bashrc`) e
**reinicie o cliente de agente** para carregar skills, agente e MCP.

## Uso rápido

```bash
eng doctor                                   # tudo pronto?
eng new meu-projeto \
  --alvo "/caminho/do/artefato" \
  --destino "/caminho/do/projeto-que-vai-receber-a-recriacao" \
  --descricao "objetivo da análise"

eng triage "/caminho/do/artefato" --salvar meu-projeto
# ... análise: eng rea ... | eng ghidra ... | eng decomp ... | eng rizin ...
# ... recriação em workspace/meu-projeto/reconstrucao/ ...

eng report meu-projeto                       # estado atual
eng publish meu-projeto                      # DRY-RUN
eng publish meu-projeto --exec               # aplica no destino registrado
```

## Comandos

| Comando | Função |
|---------|--------|
| `eng doctor [--deep]` | Diagnóstico de todas as ferramentas |
| `eng triage <alvo> [--salvar ws]` | Classifica o alvo e recomenda o motor |
| `eng new <nome> [--alvo] [--destino]` | Cria workspace de análise |
| `eng list` | Lista workspaces |
| `eng report <nome> [--salvar]` | Resumo do estado do workspace |
| `eng publish <nome> [--exec]` | Publica a reconstrução no destino (dry-run por padrão) |
| `eng rea ...` | REA com o ambiente correto |
| `eng decomp ...` | decomp.wtf |
| `eng ghidra <bin> [--ws N]` | Exportação massiva de pseudocódigo C |
| `eng rizin [quick\|diff\|...]` | Inspeção rápida |
| `eng registrar` | Re-registra skills/agente nos clientes de agente |
| `eng env [--shell]` | Mostra raiz e variáveis de ambiente |

Comandos novos: crie `bin/eng-<novo>` executável; o dispatcher encontra
automaticamente.

## Como o agente de IA entende o toolkit

Três camadas, todas genéricas e detectadas pelo instalador:

- **Skills** (`skills/`): fluxo completo e instruções por ferramenta. São
  instaladas como links simbólicos em `<diretório-do-cliente>/skills/` e em
  `~/.agents/skills/` (convenção compartilhada entre clientes).
- **Agente** (`agents/eng-reversa.md`): perfil de especialista, copiado como
  link para `<diretório-do-cliente>/agents/`.
- **MCP**: os servidores `rea` e `decomp` são registrados pelos próprios
  instaladores das ferramentas, que detectam os clientes presentes.

Se mover a pasta do toolkit, rodar `eng registrar` de novo. Para conferir o
registro: `eng doctor`.

## Estrutura

```
eng-reversa/
├── install.sh             instalador Linux/WSL
├── uninstall.sh           remove integrações (Linux/WSL)
├── install.ps1            instalador Windows (WSL2 + cliente nativo)
├── uninstall.ps1          desinstalador Windows
├── windows/               preparação do WSL, ponte MCP e atalhos eng
├── bin/                   CLI modular (eng + eng-*)
├── config/env.sh          ambiente central (raiz resolvida dinamicamente)
├── skills/                skills do agente (eng-reversa, eng-rea, eng-decomp)
├── agents/                perfil de agente
├── ghidra-scripts/        exportadores Java para Ghidra headless
├── docs/                  arquitetura, fluxo, receitas, instalação e Windows
├── tools/                 Ghidra dedicada (baixada; fora do git)
├── workspace/             um diretório por análise (fora do git)
├── targets/               artefatos originais, somente leitura (fora do git)
└── exports/               resultados avulsos (fora do git)
```

## Documentação

- `docs/INSTALACAO.md` — instalação detalhada, atualização e solução de problemas
- `docs/WINDOWS.md` — Windows: WSL2, instalador PowerShell, atalho e ponte MCP
- `docs/ARQUITETURA.md` — layout, comandos e ambiente
- `docs/FLUXO-DE-TRABALHO.md` — o ciclo completo, fase a fase
- `docs/RECEITAS.md` — receitas por tipo de alvo (APK, Unity, Electron, ROM, .NET...)
- `skills/` — instruções carregadas pelo agente de IA

## Atualização

```bash
git pull
./install.sh
```

## Desinstalação

```bash
./uninstall.sh            # remove bloco do ~/.bashrc e links nos clientes
./uninstall.sh --purge    # remove também a Ghidra baixada em tools/
```

Pacotes globais (`rea-agents`, `decomp.wtf`) não são removidos
automaticamente; o script mostra os comandos para isso.

## Uso responsável e licenças

- Analise apenas software que você possui ou está autorizado a examinar.
- Não redistribua código descompilado, ROMs, assets ou outros artefatos de
  terceiros.
- Este repositório não inclui binários de terceiros. REA (MIT), decomp.wtf
  (MIT), Ghidra (Apache-2.0) e rizin (LGPL-3.0) são baixados/instalados das
  fontes originais e mantêm suas próprias licenças.
- O código deste toolkit é distribuído sob a licença MIT (veja `LICENSE`).
