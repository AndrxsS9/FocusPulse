<#
.SYNOPSIS
    Compila FocusPulse AI para el Forerunner 165 en bin\FocusPulse.prg.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\build.ps1
#>
[CmdletBinding()]
param()

. "$PSScriptRoot\_common.ps1"

Invoke-Build -OutputFile $AppPrg
