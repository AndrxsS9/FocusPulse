<#
.SYNOPSIS
    Compila FocusPulse AI con las pruebas unitarias (-t) y las ejecuta en el simulador.

.DESCRIPTION
    Las pruebas son funciones anotadas con (:test) en la carpeta tests\ y usan Toybox.Test.
    El resultado aparece en esta consola.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\test.ps1
#>
[CmdletBinding()]
param(
    # Segundos de espera tras abrir el simulador por primera vez.
    [int]$SimulatorWaitSeconds = 8
)

. "$PSScriptRoot\_common.ps1"

Invoke-Build -OutputFile $TestPrg -UnitTest
Start-Simulator -WaitSeconds $SimulatorWaitSeconds

# En Windows, monkeydo usa /t para ejecutar las pruebas en lugar de la app.
Invoke-Native (Get-SdkTool 'monkeydo') @($TestPrg, $Device, '/t')
