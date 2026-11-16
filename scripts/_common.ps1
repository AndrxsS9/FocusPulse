# Utilidades compartidas por los scripts de FocusPulse AI.
# Uso desde otro script:  . "$PSScriptRoot\_common.ps1"

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Rutas del proyecto -------------------------------------------------------
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Device      = 'fr165'   # Verificado con el SDK 9.3.0 (también existe fr165m)
$JungleFile  = Join-Path $ProjectRoot 'monkey.jungle'
$BinDir      = Join-Path $ProjectRoot 'bin'
$AppPrg      = Join-Path $BinDir 'FocusPulse.prg'
$TestPrg     = Join-Path $BinDir 'FocusPulse-test.prg'
$ReleasePrg  = Join-Path $BinDir 'FocusPulse-release.prg'
$StorePackage = Join-Path $BinDir 'FocusPulse.iq'

# Nivel de verificación de tipos de monkeyc: 0 ninguno, 1 gradual, 2 informativo, 3 estricto.
$TypeCheckLevel = 3

# --- Llave de desarrollador (SIEMPRE fuera del repo) --------------------------
$KeyDir       = Join-Path $env:USERPROFILE 'Downloads\FocusPulse-keys'
$DeveloperKey = Join-Path $KeyDir 'developer_key.der'

# --- SDK de Connect IQ --------------------------------------------------------
# El SDK Manager guarda aquí la ruta del SDK seleccionado como "actual".
$SdkConfigFile = Join-Path $env:APPDATA 'Garmin\ConnectIQ\current-sdk.cfg'

# Devuelve la carpeta del SDK activo leyendo current-sdk.cfg.
function Get-SdkPath {
    if (-not (Test-Path -LiteralPath $SdkConfigFile)) {
        throw "No se encontró $SdkConfigFile. Instala un SDK con el Connect IQ SDK Manager y márcalo como actual."
    }
    $sdk = (Get-Content -LiteralPath $SdkConfigFile -Raw).Trim()
    if ([string]::IsNullOrWhiteSpace($sdk) -or -not (Test-Path -LiteralPath $sdk)) {
        throw "La ruta del SDK indicada en $SdkConfigFile no existe: '$sdk'"
    }
    return $sdk
}

# Ejecuta un programa externo y falla si devuelve un código distinto de 0.
function Invoke-Native {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$Arguments = @()
    )
    Write-Host "> $FilePath $($Arguments -join ' ')" -ForegroundColor DarkGray
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "El comando terminó con código $($LASTEXITCODE): $FilePath"
    }
}

# Ruta a una herramienta del SDK (monkeyc, monkeydo, connectiq).
function Get-SdkTool([string]$Name) {
    $tool = Join-Path (Get-SdkPath) "bin\$Name.bat"
    if (-not (Test-Path -LiteralPath $tool)) {
        throw "No se encontró la herramienta del SDK: $tool"
    }
    return $tool
}

function Assert-DeveloperKey {
    if (-not (Test-Path -LiteralPath $DeveloperKey)) {
        throw "No se encontró la llave de desarrollador en $DeveloperKey. Ejecuta scripts\setup.ps1 para generarla."
    }
}

# Compila la app para $Device. Con -UnitTest incluye las funciones (:test); con -Release
# compila en modo release (-r): sin el código (:debug), igual que el .iq de la tienda.
function Invoke-Build {
    param(
        [Parameter(Mandatory)][string]$OutputFile,
        [switch]$UnitTest,
        [switch]$Release
    )
    Assert-DeveloperKey
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputFile) | Out-Null

    $monkeycArgs = @('-f', $JungleFile, '-d', $Device, '-o', $OutputFile, '-y', $DeveloperKey, '-w',
                     '-l', $TypeCheckLevel)
    if ($UnitTest) { $monkeycArgs += '-t' }
    if ($Release) { $monkeycArgs += '-r' }

    Invoke-Native (Get-SdkTool 'monkeyc') $monkeycArgs
    Write-Host "Compilado: $OutputFile" -ForegroundColor Green
}

# Abre el simulador si no está corriendo y espera a que arranque.
function Start-Simulator {
    param([int]$WaitSeconds = 8)
    if (Get-Process -Name 'simulator' -ErrorAction SilentlyContinue) { return }

    Write-Host 'Abriendo el simulador de Connect IQ...'
    Start-Process -FilePath (Get-SdkTool 'connectiq') -WindowStyle Hidden
    Start-Sleep -Seconds $WaitSeconds
}

# --- Ajustes de la app en el simulador ----------------------------------------
# El simulador guarda los valores de Application.Properties de cada app en
# GARMIN\APPS\SETTINGS\<NOMBRE>.SET, dentro de %TEMP%\com.garmin.connectiq (NOMBRE es el
# del primer .prg que se instaló con este id: FOCUSPULSE-TEST, FOCUSPULSE o
# FOCUSPULSE-RELEASE). Lo lee al instalar la app con monkeydo, así que escribirlo antes
# equivale a cambiar los ajustes desde Garmin Connect (verificado con el SDK 9.3.0,
# también con la app ya abierta).
#
# Formato (medido con el SDK 9.3.0; enteros big-endian):
#   ABCDABCD, largo (u32) y tabla de textos: cada uno u16 largo (con el 0 final) + UTF-8 + 0
#   DA7ADA7A, largo (u32) y un diccionario: 0B + n (u32) + n pares clave/valor, donde
#     03 + u32 = texto (posición en la tabla), 01 + i32 = número, 09 + u8 = booleano.
$SimGarminDir = Join-Path $env:TEMP 'com.garmin.connectiq\GARMIN'
$SimTextsMagic = [uint32]2882382797   # 0xABCDABCD
$SimDataMagic = [uint32]3665484410    # 0xDA7ADA7A

function Read-UInt32BE([byte[]]$Bytes, [int]$Offset) {
    return ([uint32]$Bytes[$Offset] -shl 24) -bor ([uint32]$Bytes[$Offset + 1] -shl 16) -bor
        ([uint32]$Bytes[$Offset + 2] -shl 8) -bor [uint32]$Bytes[$Offset + 3]
}

function Add-UInt32BE([System.Collections.Generic.List[byte]]$List, [uint32]$Value) {
    $List.Add([byte]($Value -shr 24)); $List.Add([byte](($Value -shr 16) -band 255))
    $List.Add([byte](($Value -shr 8) -band 255)); $List.Add([byte]($Value -band 255))
}

# Diccionario ordenado clave -> valor (número o booleano) a partir de un .SET.
function ConvertFrom-SimProperties([byte[]]$Bytes) {
    if ($Bytes.Length -lt 16 -or (Read-UInt32BE $Bytes 0) -ne $SimTextsMagic) {
        throw 'No es un archivo de ajustes del simulador.'
    }
    $texts = 8
    $data = $texts + [int](Read-UInt32BE $Bytes 4)
    if ((Read-UInt32BE $Bytes $data) -ne $SimDataMagic -or $Bytes[$data + 8] -ne 0x0B) {
        throw 'Archivo de ajustes sin diccionario.'
    }
    $count = [int](Read-UInt32BE $Bytes ($data + 9))
    $p = $data + 13
    $result = [ordered]@{}
    for ($i = 0; $i -lt $count; $i++) {
        if ($Bytes[$p] -ne 0x03) { throw 'Clave que no es un texto.' }
        $at = $texts + [int](Read-UInt32BE $Bytes ($p + 1))
        $length = ([int]$Bytes[$at] -shl 8) -bor $Bytes[$at + 1]
        $key = [Text.Encoding]::UTF8.GetString($Bytes, $at + 2, $length - 1)
        $p += 5
        switch ($Bytes[$p]) {
            0x01 { $value = [int32](Read-UInt32BE $Bytes ($p + 1)); $p += 5 }
            0x09 { $value = [bool]$Bytes[$p + 1]; $p += 2 }
            default { throw "Tipo de valor $($Bytes[$p]) no soportado ($key)." }
        }
        $result[$key] = $value
    }
    return $result
}

# Bytes de un .SET con los valores dados (números enteros y booleanos).
function ConvertTo-SimProperties([System.Collections.IDictionary]$Values) {
    $texts = New-Object 'System.Collections.Generic.List[byte]'
    $data = New-Object 'System.Collections.Generic.List[byte]'
    $data.Add(0x0B); Add-UInt32BE $data $Values.Count
    foreach ($key in $Values.Keys) {
        $data.Add(0x03); Add-UInt32BE $data $texts.Count
        $utf8 = [Text.Encoding]::UTF8.GetBytes([string]$key)
        $length = $utf8.Length + 1
        $texts.Add([byte]($length -shr 8)); $texts.Add([byte]($length -band 255))
        $texts.AddRange($utf8); $texts.Add(0)
        $value = $Values[$key]
        if ($value -is [bool]) {
            $data.Add(0x09); $data.Add([byte][int]$value)
        } elseif ($value -is [int] -or $value -is [long]) {
            $data.Add(0x01); Add-UInt32BE $data ([uint32]([long]$value -band 4294967295L))
        } else {
            throw "Valor no soportado para '$key'."
        }
    }
    $out = New-Object 'System.Collections.Generic.List[byte]'
    Add-UInt32BE $out $SimTextsMagic; Add-UInt32BE $out $texts.Count; $out.AddRange($texts)
    Add-UInt32BE $out $SimDataMagic; Add-UInt32BE $out $data.Count; $out.AddRange($data)
    return , $out.ToArray()
}

# Escribe en el simulador los ajustes de la app: parte de los valores por defecto de la
# definición (<prg>-settings.json), conserva los que ya tenía el simulador y aplica
# $Values encima. Se escribe con todos los nombres con que el simulador puede conocer la
# app (los .SET y .PRG ya instalados, y el del .prg que se va a instalar).
function Set-SimulatorProperties {
    param(
        [Parameter(Mandatory)][string]$SettingsJson,
        [Parameter(Mandatory)][string]$PrgPath,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Values
    )
    $definition = Get-Content -LiteralPath $SettingsJson -Raw -Encoding UTF8 | ConvertFrom-Json
    $settingsDir = Join-Path $SimGarminDir 'APPS\SETTINGS'
    New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null

    $names = @([IO.Path]::GetFileNameWithoutExtension($PrgPath).ToUpperInvariant())
    $names += @(Get-ChildItem -Path $settingsDir -Filter 'FOCUSPULSE*.SET' -ErrorAction SilentlyContinue |
        ForEach-Object { $_.BaseName.ToUpperInvariant() })
    $names += @(Get-ChildItem -Path (Join-Path $SimGarminDir 'APPS\MEDIA') -Filter 'FOCUSPULSE*.PRG' -ErrorAction SilentlyContinue |
        ForEach-Object { $_.BaseName.ToUpperInvariant() })

    foreach ($name in ($names | Sort-Object -Unique)) {
        $file = Join-Path $settingsDir "$name.SET"
        $current = [ordered]@{}
        if (Test-Path -LiteralPath $file) {
            try {
                $current = ConvertFrom-SimProperties ([IO.File]::ReadAllBytes($file))
            } catch {
                Write-Warning "No se pudo leer $file ($($_.Exception.Message)): se parte de los valores por defecto."
            }
        }
        $merged = [ordered]@{}
        foreach ($setting in $definition.settings) {
            $value = $setting.defaultValue
            if ($current.Contains($setting.key) -and ($current[$setting.key] -is [bool]) -eq ($value -is [bool])) {
                $value = $current[$setting.key]
            }
            $merged[$setting.key] = $value
        }
        foreach ($key in $Values.Keys) {
            $merged[$key] = $Values[$key]
        }
        [IO.File]::WriteAllBytes($file, (ConvertTo-SimProperties $merged))
    }
}
