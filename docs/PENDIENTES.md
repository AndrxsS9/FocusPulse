# Pendientes de verificar al instalar el SDK

La fase 1 se escribió **sin el Connect IQ SDK instalado**: nada se ha compilado ni probado
en el simulador. Esta lista recoge lo que hay que comprobar en cuanto el SDK esté listo.
Marca cada punto al verificarlo y corrige el código o este documento si algo no coincide.

## 1. Instalación

- [ ] Instalar el **Connect IQ SDK Manager**, descargar el SDK más reciente y marcarlo como actual.
- [ ] Descargar el dispositivo **Forerunner 165** desde el SDK Manager.
- [ ] Comprobar que existe `%APPDATA%\Garmin\ConnectIQ\current-sdk.cfg` y que contiene solo la
      ruta del SDK (los scripts la leen con `Trim()`; si el formato es otro, ajustar
      `Get-SdkPath` en `scripts/_common.ps1`).
- [ ] Ejecutar `scripts\setup.ps1`: instala `garmin.monkey-c` y genera la llave en
      `%USERPROFILE%\Downloads\FocusPulse-keys\`.
- [ ] **Hacer copia de seguridad de la llave** fuera del equipo.

## 2. Manifest y producto

- [ ] **Id exacto del producto**: confirmar que es `fr165` (carpeta en
      `%APPDATA%\Garmin\ConnectIQ\Devices\`). Decidir si se agrega también la variante
      **`fr165m`** (Forerunner 165 Music).
- [ ] **`minApiLevel`**: se fijó `3.4.0` de forma conservadora. Revisar el nivel de API real del
      fr165 en `Devices\fr165\compiler.json` y subirlo si se necesitan APIs más nuevas.
- [ ] Confirmar que el permiso `Sensor` es el único necesario para el acelerómetro.
- [ ] El `id` de la app (`6600d3c23b8a4e89827e17ef16db01e8`) **no debe cambiar** después de
      publicar en la tienda.

## 3. Compilación (`scripts\build.ps1`)

- [ ] Compila sin errores ni advertencias relevantes con `-w`.
- [ ] Firma de `getInitialView()`: se usó `as [Views] or [Views, InputDelegates]` (SDK 7+).
      Con un SDK anterior cambiar a `as Array<Views or InputDelegates>?`.
- [ ] Las constantes de clase (`const GAP`, `const ACCENT_WIDTH` en `MainView`) compilan.
- [ ] Los recursos en subcarpetas (`resources/strings/`, `resources/drawables/`) se detectan.
- [ ] `resources-spa/` se detecta por convención. Si no, agregar a `monkey.jungle`:
      `base.lang.spa = resources-spa`.
- [ ] La compilación normal (sin `-t`) excluye las funciones `(:test)` de `tests/` y el
      `import Toybox.Test` no rompe el build.
- [ ] Probar el nivel de verificación de tipos (`-l 1`/`-l 2`) y decidir cuál fijar en los scripts.

## 4. Simulador (`scripts\run.ps1`)

- [ ] El nombre del proceso del simulador es `simulator` (lo usa `Start-Simulator` para no
      abrirlo dos veces) y 8 s de espera bastan para que `monkeydo` se conecte.
- [ ] La vista inicial se ve centrada en 390×390: "FocusPulse AI", línea cian y
      "Monitoreo en pausa" (con el simulador en español) o "Monitoring paused" (en inglés).
- [ ] Revisar tamaños de `FONT_MEDIUM` y `FONT_SMALL` en el fr165 y la separación `GAP`.
- [ ] Los colores de la paleta se ven correctos en AMOLED.

## 5. Entrada

- [ ] El botón **START/STOP** dispara `onSelect()` y alterna a "Monitoreo activo" (cian).
- [ ] El **toque** dispara `onTap()` una sola vez (sin doble alternancia vía `onSelect`).
- [ ] **BACK** sale de la app (comportamiento por defecto).

## 6. Pruebas (`scripts\test.ps1`)

- [ ] La sintaxis `monkeydo <prg> fr165 /t` es correcta en Windows.
- [ ] Las 3 pruebas de `tests/MonitorStateTest.mc` pasan.
- [ ] Comprobar si `monkeydo` devuelve código de salida distinto de 0 cuando una prueba falla
      (si no, el script no detecta fallos y hay que analizar la salida).

## 7. Sensores y vibración (antes de la fase 2)

- [ ] El fr165 soporta `Sensor.registerSensorDataListener` con acelerómetro: frecuencia de
      muestreo máxima (¿25 Hz?), tamaño de lote por periodo, unidades (mili-g) y orientación
      de los ejes.
- [ ] `Attention has :vibrate` en el fr165 y límites de `VibeProfile` (duración/intensidad).
- [ ] Si la app sigue recibiendo datos del acelerómetro cuando la pantalla AMOLED se apaga o
      entra en bajo consumo, y si el sistema cierra la `watch-app` por inactividad.

## 8. Ícono y tienda

- [ ] Tamaño exacto del ícono del launcher del fr165 (en `compiler.json`). El provisional
      `resources/drawables/launcher_icon.png` es de 60×60; el compilador avisa si lo escala.
- [ ] `scripts\export.ps1` genera `bin\FocusPulse.iq` (`monkeyc -e -r` sin `-d`).
- [ ] Revisar requisitos actuales de la Connect IQ Store (ícono, capturas, descripción es/en).
