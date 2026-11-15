<#
.SYNOPSIS
    Genera las fuentes propias en mapa de bits (BMFont) de resources\fonts\ a partir de las
    TTF de assets\fonts\.

.DESCRIPTION
    Llama a scripts\make_fonts.py con el Python de ml\.venv (Pillow, fijado en
    ml\requirements.txt). Convierte Space Grotesk, Inter y JetBrains Mono (licencia SIL OFL
    1.1) a .fnt + .png con antialias, en los tamaños del diseño y solo con los glifos que
    usa la app, y escribe resources\fonts\fonts.xml.

    Es reproducible: con las mismas TTF y la misma versión de Pillow, git status queda
    limpio después. Con -Check solo comprueba que los textos de strings.xml caben en el
    juego de caracteres (no escribe nada).

    No usa el SDK de Connect IQ. Después, compila con scripts\build.ps1.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\make_fonts.ps1
    powershell -ExecutionPolicy Bypass -File scripts\make_fonts.ps1 -Check
#>
[CmdletBinding()]
param(
    # Solo comprueba los caracteres de strings.xml, sin generar las fuentes.
    [switch]$Check
)

. "$PSScriptRoot\_common.ps1"

$Python = Join-Path $ProjectRoot 'ml\.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $Python)) {
    throw "No existe $Python. Crea el entorno con scripts\train.ps1 (instala ml\requirements.txt)."
}

$arguments = @('-I', (Join-Path $PSScriptRoot 'make_fonts.py'))
if ($Check) { $arguments += '--check' }
Invoke-Native $Python $arguments
