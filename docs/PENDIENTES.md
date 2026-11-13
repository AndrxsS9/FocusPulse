# Pendientes de verificar al instalar el SDK

Las fases 1 y 2 se escribieron **sin el Connect IQ SDK instalado**: nada se ha compilado ni
probado en el simulador. Esta lista recoge lo que hay que comprobar en cuanto el SDK esté listo.
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

- [ ] El botón **START/STOP** dispara `onSelect()` y alterna a "Guardia activa" (cian).
      (En la fase 2 el texto de `StatusActive` pasó de "Monitoreo activo" a "Guardia activa".)
- [ ] El **toque** dispara `onTap()` una sola vez (sin doble alternancia vía `onSelect`).
- [ ] **BACK** sale de la app (comportamiento por defecto).

## 6. Pruebas (`scripts\test.ps1`)

- [ ] La sintaxis `monkeydo <prg> fr165 /t` es correcta en Windows.
- [ ] Las 3 pruebas de `tests/MonitorStateTest.mc` pasan.
- [ ] Comprobar si `monkeydo` devuelve código de salida distinto de 0 cuando una prueba falla
      (si no, el script no detecta fallos y hay que analizar la salida).

## 7. Sensores y vibración (antes de la fase 3)

- [ ] El fr165 soporta `Sensor.registerSensorDataListener` con acelerómetro: frecuencia de
      muestreo máxima (¿25 Hz?), tamaño de lote por periodo, unidades (mili-g) y orientación
      de los ejes.
- [ ] `Attention has :vibrate` en el fr165 y límites de `VibeProfile` (duración/intensidad).
- [ ] Si la app sigue recibiendo datos del acelerómetro cuando la pantalla AMOLED se apaga o
      entra en bajo consumo, y si el sistema cierra la `watch-app` por inactividad.

## 8. Ícono y tienda

- [ ] Tamaño exacto del ícono del launcher del fr165 (`launcherIcon` en
      `Devices\fr165\compiler.json`). El ícono actual (anillo cian + pulso) es de 60×60;
      si el tamaño es otro, regenerarlo con `scripts\icon.ps1 -Size <n>` en lugar de dejar
      que el compilador lo escale.
- [ ] Ver el ícono en el launcher del simulador: que el pulso se lea a tamaño real y que el
      disco oscuro no choque con el fondo del menú de apps.
- [ ] `scripts\export.ps1` genera `bin\FocusPulse.iq` (`monkeyc -e -r` sin `-d`).
- [ ] Revisar requisitos actuales de la Connect IQ Store (ícono, capturas, descripción es/en).

## 9. Sistema de diseño (fase 2)

### Compilación

- [ ] `AlertnessColors.bandForScore` devuelve el enum con nombre `as AlertnessBand`. Si el
      compilador no acepta enums con nombre como tipo, cambiar a `as Number`.
- [ ] `const JUSTIFY_CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER`
      en el módulo `Draw` compila como constante y `drawText` acepta su tipo.
- [ ] Las constantes de clase de `RoundLayout` se pueden leer desde fuera como
      `RoundLayout.MIN_TOUCH` (lo usan las pruebas).
- [ ] El tipo `FontType` en las firmas de `Draw` y `Array<FontDefinition>` en
      `StyleGuideView` se resuelven con `import Toybox.Graphics` (si no, calificar como
      `Graphics.FontType` / `Graphics.FontDefinition`).
- [ ] `Number.format("%06X")` imprime el hex en mayúsculas con ceros a la izquierda en la
      página de paleta.
- [ ] La anotación `(:debug)` en las clases `StyleGuideView`/`StyleGuideDelegate` y en
      `MainDelegate.onMenu` las excluye de `scripts\export.ps1` (release, `-r`) y las incluye
      en `build.ps1`/`run.ps1`/`test.ps1`.
- [ ] Las funciones auxiliares sin `(:test)` de `tests/` (`colorsMatch`, `insideCircle`)
      compilan también en el build normal, porque `tests` está en `sourcePath`. Si molestan
      en release, mover las pruebas a una ruta solo de pruebas en `monkey.jungle`.
- [ ] Los textos de la guía de estilo (`StyleGuide*`, `TypeRole*`) se empaquetan también en
      release aunque la vista no exista; medir si el costo en memoria importa.

### Pruebas

- [ ] Pasan las 9 pruebas de `tests/AlertnessColorsTest.mc` y las 8 de
      `tests/RoundLayoutTest.mc`.

### Simulador y tipografía

- [ ] Alturas reales de `FONT_NUMBER_MEDIUM`, `FONT_NUMBER_MILD`, `FONT_LARGE`,
      `FONT_MEDIUM`, `FONT_SMALL` y `FONT_XTINY` en el fr165; ajustar `Typography` si la hora
      queda demasiado grande o pequeña frente al orbe (radio 97 px).
- [ ] **Decidir si la hora necesita una fuente personalizada** (bitmap o vectorial) para
      acercarse a la demo web, y si su costo en memoria es aceptable.
- [ ] Si `FONT_NUMBER_*` incluye `%`; si no, el porcentaje de alerta se dibuja como número
      en `NUMBER` y `%` en `LABEL`.
- [ ] Las fuentes del sistema muestran `¡`, `…`, `·`, `ñ` y vocales con tilde.
- [ ] Textos largos que no caben en una línea dentro de la zona segura (p. ej.
      "Micro-sueños repetidos · toma un descanso de 15 min", "Cabeceo / pérdida de tono
      muscular"): en la fase de interfaz usar `WatchUi.TextArea` o partirlos en líneas.

### Guía de estilo y dibujo

- [ ] La pulsación larga de UP dispara `onMenu()` en el fr165, y qué control del simulador la
      reproduce.
- [ ] Ninguna página se solapa: título contra las muestras de la paleta, franjas de alerta
      contra el botón, píldora contra el botón en la página de componentes.
- [ ] `drawArc` con `ARC_CLOCKWISE` de 90° a `(450 - sweep) % 360` dibuja el avance en
      sentido horario desde las 12, y los extremos redondos (`roundCap`) coinciden con los
      bordes del arco.
- [ ] `setAntiAlias` existe en el fr165 y mejora los bordes del anillo y del botón.

### AMOLED y accesibilidad

- [ ] En el simulador y luego en el reloj: `ORANGE`, `ORANGE_DEEP` y `RED_INTENSE` se
      distinguen entre sí; la pista `BORDER` del anillo se ve sin llamar la atención.
- [ ] El texto claro sobre `RED_INTENSE` (4,47:1) se lee bien en el reloj; si no, usar
      blanco puro solo en esa pantalla.
- [ ] Áreas táctiles: el botón grande (226×54 px, área táctil 248×76 px) se acierta con el
      reloj puesto y la mano en movimiento.
