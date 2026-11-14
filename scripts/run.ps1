<#
.SYNOPSIS
    Compila la app, abre el simulador de Connect IQ y ejecuta FocusPulse AI en fr165
    (o en otro producto del manifest con -TargetDevice).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\run.ps1
    powershell -ExecutionPolicy Bypass -File scripts\run.ps1 -NoBuild
    powershell -ExecutionPolicy Bypass -File scripts\run.ps1 -TargetDevice fr165m
    powershell -ExecutionPolicy Bypass -File scripts\run.ps1 -Release
#>
[CmdletBinding()]
param(
    # Usa el bin\FocusPulse.prg existente sin recompilar (tal como se compiló la última vez).
    [switch]$NoBuild,

    # Segundos de espera tras abrir el simulador por primera vez.
    [int]$SimulatorWaitSeconds = 8,

    # Producto del manifest en el que compilar y ejecutar. Por defecto, fr165 (_common.ps1).
    [ValidateSet('fr165', 'fr165m')]
    [string]$TargetDevice = '',

    # Compila y ejecuta la versión release (bin\FocusPulse-release.prg): la misma app que
    # se publica, sin el código (:debug). Es la que se usa en la sustentación.
    [switch]$Release
)

. "$PSScriptRoot\_common.ps1"

if ($TargetDevice) {
    $Device = $TargetDevice
}

$prg = if ($Release) { $ReleasePrg } else { $AppPrg }

if (-not $NoBuild) {
    Invoke-Build -OutputFile $prg -Release:$Release
} elseif (-not (Test-Path -LiteralPath $prg)) {
    throw "No existe $prg. Ejecuta scripts\build.ps1 primero o quita -NoBuild."
}

Start-Simulator -WaitSeconds $SimulatorWaitSeconds

# El compilador deja junto al .prg la definición de los ajustes (<prg>-settings.json, sale
# de resources\settings\). Se envía al simulador para que su editor de ajustes (File >
# Edit Persistent Storage > Edit Application.Properties data, el equivalente a la app
# Garmin Connect) los muestre; sin él dice "No settings file found for this app".
# El editor busca GARMIN\Settings\<NOMBRE>-settings.json, donde NOMBRE es el del primer
# .prg que se instaló con este id de app (SDK 9.3.0: suele ser FOCUSPULSE-TEST, de
# test.ps1), y "monkeydo /a" solo envía un archivo. Por eso se copia directamente al
# sistema de archivos del simulador (%TEMP%\com.garmin.connectiq\GARMIN, el mismo donde
# guarda los FIT) con los tres nombres de .prg que generan los scripts.
$settingsJson = [IO.Path]::ChangeExtension($prg, $null).TrimEnd('.') + '-settings.json'
$simSettingsDir = Join-Path $env:TEMP 'com.garmin.connectiq\GARMIN\Settings'
if ((Test-Path -LiteralPath $settingsJson) -and (Test-Path -LiteralPath $simSettingsDir)) {
    foreach ($name in @('FOCUSPULSE', 'FOCUSPULSE-RELEASE', 'FOCUSPULSE-TEST')) {
        Copy-Item -LiteralPath $settingsJson -Destination (Join-Path $simSettingsDir "$name-settings.json") -Force
    }
}
Invoke-Native (Get-SdkTool 'monkeydo') @($prg, $Device)
