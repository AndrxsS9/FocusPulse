# Utilidades compartidas por los scripts de FocusPulse AI.
# Uso desde otro script:  . "$PSScriptRoot\_common.ps1"

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Rutas del proyecto -------------------------------------------------------
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Device      = 'fr165'   # PENDIENTE: confirmar id exacto con el SDK Manager
$JungleFile  = Join-Path $ProjectRoot 'monkey.jungle'
$BinDir      = Join-Path $ProjectRoot 'bin'
$AppPrg      = Join-Path $BinDir 'FocusPulse.prg'
$TestPrg     = Join-Path $BinDir 'FocusPulse-test.prg'
$StorePackage = Join-Path $BinDir 'FocusPulse.iq'

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

# Ruta a una herramienta del SDK (monkeyc, monkeydo, connectiq).
function Get-SdkTool([string]$Name) {
    $tool = Join-Path (Get-SdkPath) "bin\$Name.bat"
    if (-not (Test-Path -LiteralPath $tool)) {
        throw "No se encontró la herramienta del SDK: $tool"
    }
    return $tool
}

function Assert-DeveloperKey {
    if (-not (Test-Path -LiteralPath $DeveloperKey)) {
        throw "No se encontró la llave de desarrollador en $DeveloperKey. Ejecuta scripts\setup.ps1 para generarla."
    }
}

# Compila la app para $Device. Con -UnitTest incluye las funciones (:test).
function Invoke-Build {
    param(
        [Parameter(Mandatory)][string]$OutputFile,
        [switch]$UnitTest
    )
    Assert-DeveloperKey
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputFile) | Out-Null

    $monkeycArgs = @('-f', $JungleFile, '-d', $Device, '-o', $OutputFile, '-y', $DeveloperKey, '-w')
    if ($UnitTest) { $monkeycArgs += '-t' }

    Invoke-Native (Get-SdkTool 'monkeyc') $monkeycArgs
    Write-Host "Compilado: $OutputFile" -ForegroundColor Green
}

# Abre el simulador si no está corriendo y espera a que arranque.
function Start-Simulator {
    param([int]$WaitSeconds = 8)
    if (Get-Process -Name 'simulator' -ErrorAction SilentlyContinue) { return }

    Write-Host 'Abriendo el simulador de Connect IQ...'
    Start-Process -FilePath (Get-SdkTool 'connectiq') -WindowStyle Hidden
    Start-Sleep -Seconds $WaitSeconds
}
