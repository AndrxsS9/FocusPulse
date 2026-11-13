<#
.SYNOPSIS
    Prepara el entorno de desarrollo de FocusPulse AI.

.DESCRIPTION
    1. Instala la extensión Monkey C de VS Code (garmin.monkey-c).
    2. Genera la llave de desarrollador en %USERPROFILE%\Downloads\FocusPulse-keys
       si todavía no existe. Nunca sobrescribe una llave existente y nunca la crea
       dentro del repositorio.
    3. Informa si Java y el Connect IQ SDK están disponibles.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\setup.ps1
#>
[CmdletBinding()]
param(
    # No intenta instalar la extensión de VS Code.
    [switch]$SkipExtension
)

. "$PSScriptRoot\_common.ps1"

function Install-MonkeyCExtension {
    $code = Get-Command code -ErrorAction SilentlyContinue
    if (-not $code) {
        Write-Warning "No se encontró 'code' en el PATH. Instala la extensión garmin.monkey-c manualmente desde VS Code."
        return
    }
    Write-Host 'Instalando la extensión Monkey C de VS Code...'
    Invoke-Native $code.Source @('--install-extension', 'garmin.monkey-c')
}

function Find-OpenSsl {
    $cmd = Get-Command openssl -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $gitOpenSsl = 'C:\Program Files\Git\usr\bin\openssl.exe'
    if (Test-Path -LiteralPath $gitOpenSsl) { return $gitOpenSsl }

    throw 'No se encontró OpenSSL. Instala Git for Windows o agrega openssl al PATH.'
}

# Aborta si la ruta indicada queda dentro del repositorio.
function Assert-OutsideRepo([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\') + '\'
    $root = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\') + '\'
    if ($full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        throw "La carpeta de llaves ($Path) está dentro del repositorio. La llave nunca debe versionarse."
    }
}

function New-DeveloperKey {
    Assert-OutsideRepo $KeyDir

    if (Test-Path -LiteralPath $DeveloperKey) {
        Write-Host "La llave ya existe en $DeveloperKey. No se modifica."
        return
    }

    New-Item -ItemType Directory -Force -Path $KeyDir | Out-Null
    $openssl = Find-OpenSsl
    $pem = Join-Path $KeyDir 'developer_key.pem'

    if (Test-Path -LiteralPath $pem) {
        Write-Host "Se reutiliza la llave PEM existente ($pem); no se sobrescribe."
    } else {
        Write-Host 'Generando llave RSA de 4096 bits...'
        Invoke-Native $openssl @('genrsa', '-out', $pem, '4096')
    }

    Write-Host 'Convirtiendo la llave a formato DER (PKCS#8)...'
    Invoke-Native $openssl @('pkcs8', '-topk8', '-inform', 'PEM', '-outform', 'DER',
                             '-in', $pem, '-out', $DeveloperKey, '-nocrypt')

    Write-Host "Llave creada en $DeveloperKey" -ForegroundColor Green
    Write-Warning 'Haz una copia de seguridad de esta llave: sin ella no podrás publicar actualizaciones de la app en la Connect IQ Store.'
}

function Show-Environment {
    $java = Get-Command java -ErrorAction SilentlyContinue
    if ($java) {
        Write-Host "Java: $($java.Source)"
    } else {
        Write-Warning 'Java no está en el PATH. Instala un JDK (17 o superior).'
    }

    if (Test-Path -LiteralPath $SdkConfigFile) {
        Write-Host "Connect IQ SDK: $(Get-SdkPath)"
    } else {
        Write-Warning "Connect IQ SDK no instalado ($SdkConfigFile no existe). Usa el SDK Manager para instalar un SDK y el dispositivo $Device."
    }
}

if (-not $SkipExtension) { Install-MonkeyCExtension }
New-DeveloperKey
Show-Environment
