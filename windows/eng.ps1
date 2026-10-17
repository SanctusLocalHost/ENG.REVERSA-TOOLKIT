#requires -version 5.1
# ============================================================================
#  ENG. REVERSA - atalho Windows para a CLI do WSL
# ----------------------------------------------------------------------------
#  Encaminha os argumentos para o comando `eng` dentro do WSL.
#  Converte caminhos Windows (C:\pasta) para o formato do WSL (/mnt/c/pasta).
#
#  Instalado em %USERPROFILE%\.local\bin\eng.ps1 por install.ps1.
# ============================================================================
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$EngArgs
)

$ErrorActionPreference = "Stop"

$distro = $env:ENG_WSL_DISTRO
if (-not $distro) { $distro = "Ubuntu" }

$convertidos = New-Object System.Collections.Generic.List[string]
if ($EngArgs) {
    foreach ($a in $EngArgs) {
        if ($a -match '^([A-Za-z]):[\\/](.*)$') {
            $unidade = $Matches[1].ToLowerInvariant()
            $resto = $Matches[2] -replace '\\', '/'
            $convertidos.Add("/mnt/$unidade/$resto")
        } else {
            $convertidos.Add($a)
        }
    }
}

$partes = @()
foreach ($a in $convertidos) {
    $partes += "'" + ($a -replace "'", "'\''") + "'"
}
$linha = "eng " + ($partes -join ' ')

& wsl.exe -d $distro -- bash -lc $linha
exit $LASTEXITCODE
