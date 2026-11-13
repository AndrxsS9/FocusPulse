<#
.SYNOPSIS
    Compila la app, abre el simulador de Connect IQ y ejecuta FocusPulse AI en fr165
    (o en otro producto del manifest con -TargetDevice).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\run.ps1
    powershell -ExecutionPolicy Bypass -File scripts\run.ps1 -NoBuild
    powershell -ExecutionPolicy Bypass -File scripts\run.ps1 -TargetDevice fr165m
#>
[CmdletBinding()]
param(
    # Usa el bin\FocusPulse.prg existente sin recompilar (tal como se compiló la última vez).
    [switch]$NoBuild,

    # Segundos de espera tras abrir el simulador por primera vez.
    [int]$SimulatorWaitSeconds = 8,

    # Producto del manifest en el que compilar y ejecutar. Por defecto, fr165 (_common.ps1).
    [ValidateSet('fr165', 'fr165m')]
    [string]$TargetDevice = ''
)

. "$PSScriptRoot\_common.ps1"

if ($TargetDevice) {
    $Device = $TargetDevice
}

if (-not $NoBuild) {
    Invoke-Build -OutputFile $AppPrg
} elseif (-not (Test-Path -LiteralPath $AppPrg)) {
    throw "No existe $AppPrg. Ejecuta scripts\build.ps1 primero o quita -NoBuild."
}

Start-Simulator -WaitSeconds $SimulatorWaitSeconds
Invoke-Native (Get-SdkTool 'monkeydo') @($AppPrg, $Device)
