#requires -version 5.1
# ============================================================================
#  ENG. REVERSA - desinstalador Windows
# ----------------------------------------------------------------------------
#  Remove:
#    - atalhos eng.ps1 / eng.cmd
#    - MCP rea/decomp da config do cliente no Windows
#    - skills e agente copiados para o cliente
#    - opcionalmente, o toolkit dentro do WSL (-RemoveWsl)
#
#  Uso:
#    powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
#    powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 -RemoveWsl -Purge
# ============================================================================
[CmdletBinding()]
param(
    [string]$Distro = "",
    [switch]$RemoveWsl,
    [switch]$Purge,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

function Info($mensagem) { Write-Host "[eng] $mensagem" }
function Aviso($mensagem) { Write-Host "[aviso] $mensagem" -ForegroundColor Yellow }

if ($Help) {
    Write-Host @"
ENG. REVERSA - desinstalador Windows

Uso:
  powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 [-RemoveWsl] [-Purge] [-Distro Ubuntu]

Opcoes:
  -RemoveWsl   roda o uninstall.sh dentro do WSL
  -Purge       com -RemoveWsl, remove tambem a Ghidra (tools/)
  -Distro      distro do WSL (padrao: Ubuntu)
"@
    exit 0
}

function Remover-Mcp {
    param([string]$Caminho, [string]$Nome)
    if (-not (Test-Path $Caminho)) { return }
    $json = Get-Content -LiteralPath $Caminho -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($json.PSObject.Properties["mcp"]) {
        $prop = $json.mcp.PSObject.Properties[$Nome]
        if ($prop) {
            Copy-Item -LiteralPath $Caminho -Destination "$Caminho.bak" -Force
            $json.mcp.PSObject.Properties.Remove($Nome)
            $texto = $json | ConvertTo-Json -Depth 100
            $utf8 = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($Caminho, $texto, $utf8)
            Info "MCP '$Nome' removido de $Caminho"
        }
    }
}

Write-Host "ENG. REVERSA - desinstalacao Windows"
Write-Host ""

# --- atalhos ---------------------------------------------------------------
$binDir = Join-Path $env:USERPROFILE ".local\bin"
foreach ($arquivo in @("eng.ps1", "eng.cmd")) {
    $caminho = Join-Path $binDir $arquivo
    if (Test-Path $caminho) {
        Remove-Item -LiteralPath $caminho -Force
        Info "removido: $caminho"
    }
}

# --- config do cliente -----------------------------------------------------
$clientRoot = Join-Path $env:USERPROFILE ".config\opencode"
$configPath = Join-Path $clientRoot "opencode.json"
Remover-Mcp -Caminho $configPath -Nome "rea"
Remover-Mcp -Caminho $configPath -Nome "decomp"

$skillsDst = Join-Path $clientRoot "skills"
foreach ($skill in @("eng-reversa", "eng-rea", "eng-decomp")) {
    $caminho = Join-Path $skillsDst $skill
    if (Test-Path $caminho) {
        Remove-Item -LiteralPath $caminho -Recurse -Force
        Info "skill removida: $caminho"
    }
}
$agentPath = Join-Path $clientRoot "agents\eng-reversa.md"
if (Test-Path $agentPath) {
    Remove-Item -LiteralPath $agentPath -Force
    Info "agente removido: $agentPath"
}

[Environment]::SetEnvironmentVariable("ENG_WSL_DISTRO", $null, "User")

# --- WSL -------------------------------------------------------------------
if ($RemoveWsl) {
    $distroFinal = $Distro
    if (-not $distroFinal) { $distroFinal = "Ubuntu" }

    $homeLinux = (@(& wsl.exe -d $distroFinal -- sh -lc 'printf %s "$HOME"' 2>$null) -join "").Trim()
    if (-not $homeLinux) {
        Aviso "nao foi possivel acessar a distro '$distroFinal'"
    } else {
        $destLinux = "$homeLinux/eng-reversa"
        $wslArgs = @("-d", $distroFinal, "--", "bash", "-lc", "cd `"$destLinux`" && ./uninstall.sh -y")
        if ($Purge) {
            $wslArgs[-1] = "cd `"$destLinux`" && ./uninstall.sh -y --purge"
        }
        & wsl.exe @wslArgs
        Info "desinstalacao dentro do WSL concluida"
    }
} else {
    Aviso "o toolkit dentro do WSL foi preservado (use -RemoveWsl para remover)"
}

Write-Host ""
Write-Host "Desinstalacao concluida. Reinicie o cliente de agente."
