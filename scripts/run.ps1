<#
.SYNOPSIS
    Compila la app, abre el simulador de Connect IQ y ejecuta FocusPulse AI en fr165.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\run.ps1
    powershell -ExecutionPolicy Bypass -File scripts\run.ps1 -NoBuild
#>
[CmdletBinding()]
param(
    # Usa el bin\FocusPulse.prg existente sin recompilar.
    [switch]$NoBuild,

    # Segundos de espera tras abrir el simulador por primera vez.
    [int]$SimulatorWaitSeconds = 8
)

. "$PSScriptRoot\_common.ps1"

if (-not $NoBuild) {
    Invoke-Build -OutputFile $AppPrg
} elseif (-not (Test-Path -LiteralPath $AppPrg)) {
    throw "No existe $AppPrg. Ejecuta scripts\build.ps1 primero o quita -NoBuild."
}

Start-Simulator -WaitSeconds $SimulatorWaitSeconds
Invoke-Native (Get-SdkTool 'monkeydo') @($AppPrg, $Device)
