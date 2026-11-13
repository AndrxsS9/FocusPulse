<#
.SYNOPSIS
    Genera el paquete bin\FocusPulse.iq para subir a la Connect IQ Store.

.DESCRIPTION
    Compila en modo release (-r) para todos los productos del manifest y firma
    con la llave de desarrollador. Usa SIEMPRE la misma llave: la tienda rechaza
    actualizaciones firmadas con una llave distinta.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\export.ps1
#>
[CmdletBinding()]
param()

. "$PSScriptRoot\_common.ps1"

Assert-DeveloperKey
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

Invoke-Native (Get-SdkTool 'monkeyc') @(
    '-e', '-r', '-w',
    '-l', $TypeCheckLevel,
    '-f', $JungleFile,
    '-o', $StorePackage,
    '-y', $DeveloperKey
)

Write-Host "Paquete para la tienda: $StorePackage" -ForegroundColor Green
