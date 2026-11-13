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
# monkeydo devuelve 0 aunque fallen pruebas (verificado con el SDK 9.3.0), así que el
# resultado se decide leyendo la línea de resumen: "PASSED (...)" o "FAILED (...)".
$monkeydo = Get-SdkTool 'monkeydo'
Write-Host "> $monkeydo $TestPrg $Device /t" -ForegroundColor DarkGray
$lines = & $monkeydo $TestPrg $Device '/t' | ForEach-Object {
    $line = "$_"
    Write-Host $line
    $line
}
if ($LASTEXITCODE -ne 0) {
    throw "monkeydo terminó con código $($LASTEXITCODE)."
}

$summary = $lines | Where-Object { $_ -match '^(PASSED|FAILED) \(' } | Select-Object -Last 1
if (-not $summary) {
    throw 'No se encontró el resumen de las pruebas en la salida de monkeydo.'
}
if ($summary -notmatch '^PASSED') {
    throw "Hay pruebas que fallan: $summary"
}
Write-Host "Pruebas correctas: $summary" -ForegroundColor Green
