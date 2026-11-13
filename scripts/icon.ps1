<#
.SYNOPSIS
    Genera el ícono del launcher de FocusPulse AI (anillo cian + pulso).

.DESCRIPTION
    Dibuja el ícono con System.Drawing a 8x y lo reduce con filtrado bicúbico
    para que los bordes queden suaves. Los colores se leen de
    source\util\Palette.mc, así que el ícono sigue siempre a la paleta.

    No necesita el SDK de Connect IQ. Vuelve a ejecutarlo con -Size cuando se
    confirme el tamaño exacto del launcher del fr165 (ver docs\PENDIENTES.md).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\icon.ps1
    powershell -ExecutionPolicy Bypass -File scripts\icon.ps1 -Size 70
#>
[CmdletBinding()]
param(
    # Lado del ícono en píxeles.
    [ValidateRange(16, 512)]
    [int]$Size = 60,

    # Archivo PNG de salida.
    [string]$Output
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$ProjectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Output) {
    $Output = Join-Path $ProjectRoot 'resources\drawables\launcher_icon.png'
}

# --- Colores desde Palette.mc -------------------------------------------------
$paletteFile = Join-Path $ProjectRoot 'source\util\Palette.mc'
$palette = @{}
foreach ($match in [regex]::Matches((Get-Content -LiteralPath $paletteFile -Raw),
        'const\s+(\w+)\s*=\s*0x([0-9A-Fa-f]{6})\s*;')) {
    $palette[$match.Groups[1].Value] = [Convert]::ToInt32($match.Groups[2].Value, 16)
}

function Get-PaletteColor([string]$Name) {
    if (-not $palette.ContainsKey($Name)) {
        throw "No se encontró la constante $Name en $paletteFile"
    }
    return [System.Drawing.Color]::FromArgb(255, [System.Drawing.Color]::FromArgb($palette[$Name]))
}

$background = Get-PaletteColor 'BACKGROUND'
$track      = Get-PaletteColor 'BORDER_STRONG'
$accent     = Get-PaletteColor 'ACCENT'
$pulse      = Get-PaletteColor 'ACCENT_LIGHT'

# --- Dibujo a 8x --------------------------------------------------------------
$scale = 8
$big = $Size * $scale
$u = $big / 100.0   # unidad: 1/100 del lado

$canvas = New-Object System.Drawing.Bitmap($big, $big, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($canvas)
try {
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    # Disco de fondo casi negro (fuera del disco queda transparente).
    $brush = New-Object System.Drawing.SolidBrush($background)
    $g.FillEllipse($brush, 0, 0, $big, $big)
    $brush.Dispose()

    # Anillo: pista tenue completa + arco cian de 300° desde las 12 en punto.
    $ringPen = 9 * $u
    $ringInset = 9 * $u
    $ringBox = New-Object System.Drawing.RectangleF($ringInset, $ringInset,
        ($big - 2 * $ringInset), ($big - 2 * $ringInset))

    $pen = New-Object System.Drawing.Pen($track, $ringPen)
    $g.DrawEllipse($pen, $ringBox)
    $pen.Dispose()

    $pen = New-Object System.Drawing.Pen($accent, $ringPen)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawArc($pen, $ringBox, -90, 300)
    $pen.Dispose()

    # Pulso tipo ECG cruzando el centro.
    $c = $big / 2.0
    $points = @(
        @(-27, 3), @(-13, 3), @(-8, -4), @(-3, 3), @(1, -22),
        @(7, 20), @(11, -2), @(14, 3), @(27, 3)
    ) | ForEach-Object { New-Object System.Drawing.PointF(($c + $_[0] * $u), ($c + $_[1] * $u)) }

    $pen = New-Object System.Drawing.Pen($pulse, (7 * $u))
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $g.DrawLines($pen, [System.Drawing.PointF[]]$points)
    $pen.Dispose()
}
finally {
    $g.Dispose()
}

# --- Reducción al tamaño final ------------------------------------------------
$icon = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($icon)
try {
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($canvas, 0, 0, $Size, $Size)
}
finally {
    $g.Dispose()
    $canvas.Dispose()
}

try {
    $icon.Save($Output, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $icon.Dispose()
}

Write-Host "Ícono ${Size}x${Size} generado en $Output" -ForegroundColor Green
