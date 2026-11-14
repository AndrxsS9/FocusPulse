<#
.SYNOPSIS
    Entrena el clasificador de estado (regresión logística multinomial) y exporta sus
    pesos a Monkey C.

.DESCRIPTION
    Hace todo en orden:
      1. crea ml\.venv con Python 3.12 si no existe (o usa el que hay);
      2. instala ml\requirements.txt (versiones fijas);
      3. genera el dataset SINTÉTICO en ml\data\ (generate_dataset.py);
      4. entrena con validación cruzada agrupada por usuario y evalúa v1 frente a v2 sobre
         el mismo conjunto de prueba (train.py): ml\reports\ y ml\models\model_v2.json;
      5. salvo con -NoExport, escribe source\core\ClassifierWeights.mc y los vectores de
         prueba de tests\ (export_weights.py).

    No usa el SDK de Connect IQ. Después de exportar, compila y prueba con
    scripts\build.ps1 y scripts\test.ps1.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\train.ps1
    powershell -ExecutionPolicy Bypass -File scripts\train.ps1 -Seed 7 -NoExport
#>
[CmdletBinding()]
param(
    # Semilla del dataset, de la división en entrenamiento/prueba y del entrenamiento.
    [int]$Seed = 20261114,

    # Entrena y evalúa, pero no toca source\ ni tests\.
    [switch]$NoExport
)

. "$PSScriptRoot\_common.ps1"

$MlDir        = Join-Path $ProjectRoot 'ml'
$VenvDir      = Join-Path $MlDir '.venv'
$Python       = Join-Path $VenvDir 'Scripts\python.exe'
$Requirements = Join-Path $MlDir 'requirements.txt'

# --- 1. Entorno virtual -------------------------------------------------------
if (-not (Test-Path -LiteralPath $Python)) {
    $launcher = Get-Command 'py' -ErrorAction SilentlyContinue
    if (-not $launcher) {
        throw 'No se encontró el lanzador "py". Instala Python 3.12 con: winget install Python.Python.3.12'
    }
    & $launcher.Source -3.12 --version | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'No se encontró Python 3.12. Instálalo con: winget install Python.Python.3.12'
    }
    Write-Host "Creando el entorno virtual en $VenvDir..."
    Invoke-Native $launcher.Source @('-3.12', '-m', 'venv', $VenvDir)
}

# --- 2. Dependencias ----------------------------------------------------------
Invoke-Native $Python @('-m', 'pip', 'install', '--disable-pip-version-check', '-q', '-r', $Requirements)

# --- 3 a 5. Pipeline ----------------------------------------------------------
Push-Location $MlDir
try {
    Invoke-Native $Python @('generate_dataset.py', '--seed', "$Seed")
    Invoke-Native $Python @('train.py', '--seed', "$Seed")
    if ($NoExport) {
        Write-Host 'Sin exportar (-NoExport): source\ y tests\ no cambiaron.' -ForegroundColor Yellow
    } else {
        Invoke-Native $Python @('export_weights.py')
    }
} finally {
    Pop-Location
}

Write-Host "Listo. Informe: $(Join-Path $MlDir 'reports\report.md')" -ForegroundColor Green
