#requires -version 5.1
# ============================================================================
#  ENG. REVERSA - instalador para Windows (via WSL2)
# ----------------------------------------------------------------------------
#  O toolkit roda dentro do WSL2 (Ubuntu), onde estao REA, Ghidra, decomp.wtf
#  e a CLI `eng`. Este script:
#    1. verifica/instala o WSL2
#    2. prepara o Ubuntu (pacotes, JDK 21, Node)
#    3. copia o toolkit para ~/eng-reversa dentro do WSL
#    4. roda o install.sh de la
#    5. cria a ponte MCP (Windows -> WSL)
#    6. registra MCP + skills no cliente de agente do Windows
#    7. instala os atalhos eng.ps1 / eng.cmd
#
#  Uso (PowerShell, na pasta do repositorio):
#    powershell -ExecutionPolicy Bypass -File .\install.ps1
#
#  Opcoes:
#    -Distro Ubuntu        distro do WSL a usar
#    -WithDecompWtf        instala tambem o decomp.wtf
#    -SkipGhidra           nao baixa a Ghidra (usa GHIDRA_INSTALL_DIR)
#    -SkipPrereqs          nao instala pacotes/JDK/Node no WSL
#    -NoWindowsMcp         nao altera a config do cliente no Windows
#    -NoShims              nao instala os atalhos eng.ps1/eng.cmd
#    -InstallWsl           tenta instalar o WSL2 se estiver ausente
#    -Help                 esta ajuda
# ============================================================================
[CmdletBinding()]
param(
    [string]$Distro = "",
    [string]$InstallDir = "eng-reversa",
    [switch]$WithDecompWtf,
    [switch]$SkipGhidra,
    [switch]$SkipPrereqs,
    [switch]$NoWindowsMcp,
    [switch]$NoShims,
    [switch]$InstallWsl,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

function Info($mensagem) { Write-Host "[eng] $mensagem" }
function Aviso($mensagem) { Write-Host "[aviso] $mensagem" -ForegroundColor Yellow }
function Erro($mensagem) { Write-Host "[ERRO] $mensagem" -ForegroundColor Red; exit 1 }

function Mostrar-Ajuda {
    Write-Host @"
ENG. REVERSA - instalador Windows (WSL2)

Uso:
  powershell -ExecutionPolicy Bypass -File .\install.ps1 [opcoes]

Opcoes:
  -Distro <nome>     distro do WSL (padrao: Ubuntu)
  -WithDecompWtf     instala tambem o decomp.wtf
  -SkipGhidra        nao baixa a Ghidra
  -SkipPrereqs       nao instala pacotes/JDK/Node no WSL
  -NoWindowsMcp      nao altera a config do cliente no Windows
  -NoShims           nao instala os atalhos eng.ps1/eng.cmd
  -InstallWsl        tenta instalar o WSL2 + Ubuntu
  -Help              esta ajuda
"@
}

function Atualizar-Mcp {
    param(
        [string]$Caminho,
        [string]$Nome,
        [object[]]$Comando
    )
    $json = Get-Content -LiteralPath $Caminho -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $json.PSObject.Properties["mcp"]) {
        $json | Add-Member -NotePropertyName "mcp" -NotePropertyValue (New-Object PSObject)
    }
    $entrada = New-Object PSObject
    $entrada | Add-Member -NotePropertyName "type" -NotePropertyValue "local"
    $entrada | Add-Member -NotePropertyName "command" -NotePropertyValue $Comando
    $entrada | Add-Member -NotePropertyName "enabled" -NotePropertyValue $true
    if ($json.mcp.PSObject.Properties[$Nome]) {
        $json.mcp.$Nome = $entrada
    } else {
        $json.mcp | Add-Member -NotePropertyName $Nome -NotePropertyValue $entrada
    }
    $texto = $json | ConvertTo-Json -Depth 100
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Caminho, $texto, $utf8)
}

if ($Help) { Mostrar-Ajuda; exit 0 }

if ($env:OS -ne "Windows_NT") {
    Erro "este instalador e para Windows. No Linux use ./install.sh"
}

Write-Host "============================================================"
Write-Host " ENG. REVERSA - instalador Windows (WSL2)"
Write-Host "============================================================"

# ---------------------------------------------------------------------------
# 1. WSL2 e distro
# ---------------------------------------------------------------------------
Info "verificando o WSL2"
$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wsl) {
    Erro "wsl.exe nao encontrado. Ative o WSL2:
  - Windows 10 2004+ ou Windows 11
  - PowerShell como administrador: wsl --install
  - reinicie o computador e rode este script de novo"
}

$saida = & wsl.exe -l -q 2>$null
$distros = @()
foreach ($linha in @($saida)) {
    $limpa = ($linha -replace "`0", "").Trim()
    if ($limpa) { $distros += $limpa }
}

if ($distros.Count -eq 0) {
    if ($InstallWsl) {
        Info "instalando WSL2 + Ubuntu (pode pedir elevacao e reiniciar)"
        & wsl.exe --install -d Ubuntu
        Erro "se o Windows pediu reinicio, reinicie, abra o Ubuntu uma vez e rode este script de novo"
    }
    Erro "nenhuma distro WSL encontrada. Rode em um PowerShell como administrador:
  wsl --install -d Ubuntu
Depois reinicie, abra o Ubuntu uma vez e rode este script de novo."
}

if ($Distro) {
    if ($distros -notcontains $Distro) {
        Erro "distro '$Distro' nao encontrada. Disponiveis: $($distros -join ', ')"
    }
    $distroFinal = $Distro
} elseif ($distros -contains "Ubuntu") {
    $distroFinal = "Ubuntu"
} elseif ($distros -contains "Ubuntu-24.04") {
    $distroFinal = "Ubuntu-24.04"
} elseif ($distros -contains "Ubuntu-22.04") {
    $distroFinal = "Ubuntu-22.04"
} else {
    $distroFinal = $distros[0]
    Aviso "usando a distro '$distroFinal'"
}
Info "distro: $distroFinal"

$homeLinux = (@(& wsl.exe -d $distroFinal -- sh -lc 'printf %s "$HOME"') -join "").Trim()
if (-not $homeLinux) { Erro "nao foi possivel obter o HOME dentro do WSL" }
$destLinux = "$homeLinux/$InstallDir"
Info "destino no WSL: $destLinux"

# ---------------------------------------------------------------------------
# 2. Copia do toolkit para o WSL
# ---------------------------------------------------------------------------
$origem = $PSScriptRoot
if (-not (Test-Path (Join-Path $origem "config\env.sh"))) {
    Erro "install.ps1 precisa estar na raiz do repositorio clonado"
}

& wsl.exe -d $distroFinal -- mkdir -p $destLinux
if ($LASTEXITCODE -ne 0) { Erro "falha ao criar $destLinux no WSL" }

$destRel = $destLinux -replace '/', '\'
$unc = "\\wsl.localhost\$distroFinal$destRel"
if (-not (Test-Path $unc)) { $unc = "\\wsl$\$distroFinal$destRel" }
if (-not (Test-Path $unc)) {
    Erro "nao foi possivel acessar o WSL por UNC. Alternativa:
  1. abra o Ubuntu
  2. git clone https://github.com/SanctusLocalHost/eng-reversa.git
  3. cd eng-reversa && ./install.sh"
}

Info "copiando o toolkit para o WSL"
$excluir = @(".git", "tools", "workspace", "targets", "exports")
Get-ChildItem -LiteralPath $origem -Force | Where-Object { $excluir -notcontains $_.Name } | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $unc -Recurse -Force
}
foreach ($pasta in @("tools", "targets", "exports", "workspace")) {
    $alvo = Join-Path $unc $pasta
    if (-not (Test-Path $alvo)) { New-Item -ItemType Directory -Force -Path $alvo | Out-Null }
}
$template = Join-Path $unc "workspace\_TEMPLATE"
if (-not (Test-Path $template)) {
    Copy-Item -LiteralPath (Join-Path $origem "workspace\_TEMPLATE") -Destination (Join-Path $unc "workspace") -Recurse -Force
}

# ---------------------------------------------------------------------------
# 3. Preparacao do Ubuntu
# ---------------------------------------------------------------------------
if (-not $SkipPrereqs) {
    Info "preparando o Ubuntu (pacotes, JDK 21, Node.js)"
    & wsl.exe -d $distroFinal -- bash "$destLinux/windows/wsl-prepare.sh"
    if ($LASTEXITCODE -ne 0) { Erro "a preparacao do WSL falhou" }
} else {
    Aviso "preparacao do WSL ignorada (-SkipPrereqs)"
}

# ---------------------------------------------------------------------------
# 4. Instalacao dentro do WSL
# ---------------------------------------------------------------------------
$comando = "cd `"$destLinux`" && ./install.sh --yes"
if ($WithDecompWtf) { $comando += " --with-decomp-wtf" }
if ($SkipGhidra) { $comando += " --no-ghidra" }

Info "rodando o instalador dentro do WSL"
& wsl.exe -d $distroFinal -- bash -lc $comando
if ($LASTEXITCODE -ne 0) { Erro "o install.sh falhou dentro do WSL" }

# ---------------------------------------------------------------------------
# 5. Ponte MCP
# ---------------------------------------------------------------------------
Info "criando a ponte MCP (Windows -> WSL)"
& wsl.exe -d $distroFinal -- bash -lc "cd `"$destLinux`" && ./windows/mcp-bridge.sh"
if ($LASTEXITCODE -ne 0) { Erro "falha ao criar a ponte MCP" }

$bridgeDir = (@(& wsl.exe -d $distroFinal -- sh -lc 'printf %s "${XDG_DATA_HOME:-$HOME/.local/share}/eng-reversa"') -join "").Trim()
$reaWrapper = "$bridgeDir/mcp-rea.sh"
$decompWrapper = "$bridgeDir/mcp-decomp.sh"

& wsl.exe -d $distroFinal -- test -x $reaWrapper
if ($LASTEXITCODE -ne 0) { Erro "wrapper MCP do REA nao encontrado em $reaWrapper" }

& wsl.exe -d $distroFinal -- test -x $decompWrapper
$temDecomp = ($LASTEXITCODE -eq 0)

# ---------------------------------------------------------------------------
# 6. Cliente de agente no Windows
# ---------------------------------------------------------------------------
if (-not $NoWindowsMcp) {
    $clientRoot = Join-Path $env:USERPROFILE ".config\opencode"
    $configPath = Join-Path $clientRoot "opencode.json"

    if (Test-Path $configPath) {
        Copy-Item -LiteralPath $configPath -Destination "$configPath.bak" -Force
        Atualizar-Mcp -Caminho $configPath -Nome "rea" -Comando @("wsl.exe", "-d", $distroFinal, "--", $reaWrapper)
        if ($temDecomp) {
            Atualizar-Mcp -Caminho $configPath -Nome "decomp" -Comando @("wsl.exe", "-d", $distroFinal, "--", $decompWrapper)
        }
        Info "MCP registrado em $configPath"
    } else {
        Aviso "config do cliente nao encontrada em $configPath"
        Aviso "instale/abra o cliente uma vez e rode este script de novo"
    }

    if (Test-Path $clientRoot) {
        $skillsDst = Join-Path $clientRoot "skills"
        New-Item -ItemType Directory -Force -Path $skillsDst | Out-Null
        Copy-Item -Path (Join-Path $origem "skills\*") -Destination $skillsDst -Recurse -Force
        $agentsDst = Join-Path $clientRoot "agents"
        New-Item -ItemType Directory -Force -Path $agentsDst | Out-Null
        Copy-Item -LiteralPath (Join-Path $origem "agents\eng-reversa.md") -Destination $agentsDst -Force
        Info "skills e agente copiados para $clientRoot"
    } else {
        Aviso "diretorio do cliente nao encontrado em $clientRoot"
    }
} else {
    Aviso "registro no cliente do Windows ignorado (-NoWindowsMcp)"
}

# ---------------------------------------------------------------------------
# 7. Atalhos eng.ps1 / eng.cmd
# ---------------------------------------------------------------------------
if (-not $NoShims) {
    $binDir = Join-Path $env:USERPROFILE ".local\bin"
    New-Item -ItemType Directory -Force -Path $binDir | Out-Null
    Copy-Item -LiteralPath (Join-Path $origem "windows\eng.ps1") -Destination $binDir -Force
    Copy-Item -LiteralPath (Join-Path $origem "windows\eng.cmd") -Destination $binDir -Force

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not $userPath) { $userPath = "" }
    $partes = @($userPath -split ';' | Where-Object { $_ })
    if ($partes -notcontains $binDir) {
        if ($userPath.TrimEnd(';')) {
            $novoPath = $userPath.TrimEnd(';') + ';' + $binDir
        } else {
            $novoPath = $binDir
        }
        [Environment]::SetEnvironmentVariable("Path", $novoPath, "User")
    }
    [Environment]::SetEnvironmentVariable("ENG_WSL_DISTRO", $distroFinal, "User")
    $env:ENG_WSL_DISTRO = $distroFinal
    $env:Path = $env:Path + ";" + $binDir
    Info "atalho 'eng' instalado em $binDir"
} else {
    Aviso "atalhos ignorados (-NoShims)"
}

# ---------------------------------------------------------------------------
# Resumo
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================================"
Write-Host " Instalacao concluida."
Write-Host "============================================================"
Write-Host " Toolkit no WSL : $destLinux"
Write-Host " Distro         : $distroFinal"
Write-Host ""
Write-Host " Proximos passos:"
Write-Host "   1. abra um PowerShell novo"
Write-Host "   2. teste: eng doctor"
Write-Host "   3. reinicie o cliente de agente"
Write-Host "   4. peca ao agente para usar a ENG. REVERSA no alvo desejado"
Write-Host ""
Write-Host " Observacao: caminhos C:\... sao convertidos para /mnt/c/... pelo atalho."
Write-Host " Para atualizar: git pull no clone do Windows e rode install.ps1 de novo."
