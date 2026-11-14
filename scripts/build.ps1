<#
.SYNOPSIS
    Compila FocusPulse AI para el Forerunner 165 en bin\FocusPulse.prg.

.DESCRIPTION
    Con -Release compila en modo release (sin menú de depuración ni guía de estilo, igual
    que el paquete de la tienda) en bin\FocusPulse-release.prg.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\build.ps1
    powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Release
#>
[CmdletBinding()]
param(
    # Compila en modo release en bin\FocusPulse-release.prg.
    [switch]$Release
)

. "$PSScriptRoot\_common.ps1"

if ($Release) {
    Invoke-Build -OutputFile $ReleasePrg -Release
} else {
    Invoke-Build -OutputFile $AppPrg
}
