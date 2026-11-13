# Utilidades compartidas por los scripts de FocusPulse AI.
# Uso desde otro script:  . "$PSScriptRoot\_common.ps1"

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Rutas del proyecto -------------------------------------------------------
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Device      = 'fr165'   # PENDIENTE: confirmar id exacto con el SDK Manager

# --- Llave de desarrollador (SIEMPRE fuera del repo) --------------------------
$KeyDir       = Join-Path $env:USERPROFILE 'Downloads\FocusPulse-keys'
$DeveloperKey = Join-Path $KeyDir 'developer_key.der'

# --- SDK de Connect IQ --------------------------------------------------------
# El SDK Manager guarda aquí la ruta del SDK seleccionado como "actual".
$SdkConfigFile = Join-Path $env:APPDATA 'Garmin\ConnectIQ\current-sdk.cfg'

# Devuelve la carpeta del SDK activo leyendo current-sdk.cfg.
function Get-SdkPath {
    if (-not (Test-Path -LiteralPath $SdkConfigFile)) {
        throw "No se encontró $SdkConfigFile. Instala un SDK con el Connect IQ SDK Manager y márcalo como actual."
    }
    $sdk = (Get-Content -LiteralPath $SdkConfigFile -Raw).Trim()
    if ([string]::IsNullOrWhiteSpace($sdk) -or -not (Test-Path -LiteralPath $sdk)) {
        throw "La ruta del SDK indicada en $SdkConfigFile no existe: '$sdk'"
    }
    return $sdk
}

# Ejecuta un programa externo y falla si devuelve un código distinto de 0.
function Invoke-Native {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$Arguments = @()
    )
    Write-Host "> $FilePath $($Arguments -join ' ')" -ForegroundColor DarkGray
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "El comando terminó con código $($LASTEXITCODE): $FilePath"
    }
}
