# Pendientes de verificar

Las fases 1 y 2 se compilaron, probaron y revisaron en el simulador con el **Connect IQ SDK
9.3.0** (2026-11-12), y la fase 3 el 2026-11-13. La primera sección resume lo que quedó confirmado; el resto del
documento lista **solo lo que sigue abierto**. Al cerrar un punto, muévelo a la sección de
datos confirmados o bórralo, y corrige el código si algo no coincide.

## Datos confirmados (SDK 9.3.0)

### Dispositivo (`Devices\fr165\compiler.json` y `simulator.json`)

| Dato | fr165 | fr165m |
|---|---|---|
| Nombre | Forerunner® 165 | Forerunner® 165 Music |
| Nivel de API | 5.2.0 | 5.2.0 |
| Pantalla | 390×390 redonda, AMOLED, 16 bpp, 325 ppi | igual |
| Táctil | sí (`isTouch`); el toque se traduce a `onSelect` | igual |
| Teclas | START (`onSelect`), BACK, UP (`previousPage`), mantener UP = `onMenu`, DOWN (`nextPage`) | igual |
| Acelerómetro | sí, hasta **100 Hz** | igual |
| Magnetómetro | sí, hasta 50 Hz | igual |
| Giroscopio | **no** (sin `maxGyroRate`, que sí aparece en relojes con giroscopio) | igual |
| Ícono del launcher | **54×54** | 54×54 |
| Memoria de `watch-app` | 768 KB | 768 KB |

`manifest.xml` declara ambos productos con `minApiLevel="5.2.0"`. El permiso `Sensor` basta
para leer el acelerómetro (la app lo consultó en el simulador sin errores).

### Acelerómetro (`Sensor.registerSensorDataListener`, doc del SDK)

- Opciones: `:period` en segundos, **máximo 4 s**; `:accelerometer => { :enabled, :sampleRate,
  :includePitch, :includeRoll, :includePower, :includeTimestamps }`.
- Cada lote trae `period × sampleRate` muestras por eje (p. ej. 1 s a 25 Hz = 25 muestras).
- Unidades: `x`, `y`, `z` como `Array<Number>` en **mili‑g** (1000 = 1 g). `pitch`/`roll` en
  grados si se piden.
- Frecuencia máxima: usar `Sensor.getMaxSampleRateForSensorType(:accelerometer)`, que da
  **100** en el fr165. `Sensor.getMaxSampleRate()` da 50, porque es el límite general del
  sistema y no el del acelerómetro.
- Solo puede haber un listener registrado; un segundo registro reemplaza al anterior.

### Vibración (`Attention.vibrate`, doc del SDK)

- `Attention has :vibrate` es `true` en el fr165.
- `vibrate()` recibe de **1 a 8** `VibeProfile(dutyCycle 0–100, length en ms)` y los
  reproduce en orden.
- **Los Forerunner no admiten patrones de intensidad**: el `dutyCycle` se ignora y siempre
  vibran con la misma fuerza. Los niveles "suave / media / máxima" se tendrán que hacer con
  **duración, número de pulsos y pausas**, no con intensidad.

### Ciclo de vida y pantalla apagada (doc del SDK)

- Una app abierta desde la **lista de glances** se cierra sola tras un tiempo. Abierta desde
  el **menú de actividades/apps** no tiene ese límite y el usuario debe salir a mano.
- Con el selector de tareas (API ≥ 4.2) la app puede pasar a **inactiva** (`onInactive`).
  Si no está grabando una actividad, en ese estado:
  - los sensores de alta frecuencia bajan a **10 Hz como máximo** o pueden fallar;
  - **`Attention` (la vibración) queda denegada**.
- La doc no dice qué pasa al apagarse la pantalla AMOLED con la app en primer plano. Queda
  abierto (sección 2).

### Compilación, pruebas y simulador

- `build.ps1`, `test.ps1` y `export.ps1` compilan sin errores ni advertencias con verificación
  de tipos **estricta (`-l 3`)**. El export genera el `.iq` para fr165 y fr165m.
- Las **20 pruebas** pasan: 3 de `MonitorState`, 9 de `AlertnessColors` y 8 de `RoundLayout`.
- `monkeydo /t` devuelve 0 aunque fallen pruebas; `test.ps1` ahora decide por la línea
  `PASSED`/`FAILED`.
- En el simulador:
  - la vista principal se ve centrada;
  - START y un toque alternan pausa/guardia **una sola vez**;
  - BACK cierra la app;
  - mantener UP abre la guía de estilo y BACK vuelve desde ella.
- Las 7 páginas de la guía de estilo se revisaron en inglés y en español, sin solapamientos.
  Se ven bien ¡, ñ, ·, … y tildes.
- Alturas de fuente medidas en el fr165: ver `DISENO.md` §3.

### Telemetría y grabación (fase 3, simulador)

- Las **42 pruebas** pasan (22 nuevas: `RingBuffer`, `SlidingWindow`, `TelemetryEngine` y
  firmas de los escenarios simulados). `build.ps1` y `export.ps1` siguen sin advertencias
  con `-l 3`; el código `(:debug)` (menú, telemetría, selector) no entra en release.
- **Frecuencia efectiva medida: 25,0 Hz** de 25 pedidos, tanto con la fuente simulada como
  con el acelerómetro del simulador (1850 muestras en 74 lotes de 1 s, ≈75 s).
- El **acelerómetro del simulador no entrega lotes** por sí solo: el registro funciona pero
  llegan 0 muestras. Hay que abrir *Simulation > Activity Data*, dejar *Data Source* en
  *Data Simulation* y pulsar ▶. Esos datos son vectores de 1 g en direcciones al azar
  (varianza de la magnitud ≈0, sacudida > 1 700 mg), útiles solo para ver que llegan lotes.
  Para datos con sentido se usa la fuente simulada del menú de depuración.
- `ActivityRecording` funciona en el simulador: la sesión aparece en *Activity Data* (los
  controles del temporizador pasan a *Stop/Pause*) y los FIT se guardan en
  `%TEMP%\com.garmin.connectiq\GARMIN\Activities\`.
- **El simulador se cierra con un error** (`0xc0000005` en `simulator.exe`) si la app termina
  con una sesión **todavía grabando**, aunque `onStop` llame a `stop()` y `save()`. Pausar
  antes de salir lo evita. Por eso `MainDelegate.onBack` detiene y guarda la guardia antes de
  devolver el control al sistema; verificado: START → BACK ya no tumba el simulador.

## 1. Entorno

- [ ] **Hacer copia de seguridad de la llave** `%USERPROFILE%\Downloads\FocusPulse-keys\`
      fuera del equipo. Sin ella no se pueden publicar actualizaciones.
- [ ] El `id` de la app (`6600d3c23b8a4e89827e17ef16db01e8`) **no debe cambiar** después de
      publicar en la tienda (recordatorio permanente).

## 2. Sensores y vibración (antes de las fases 3 y 6)

- [ ] **Orientación de los ejes** x/y/z del acelerómetro con el reloj puesto en la muñeca
      izquierda y en la derecha, en el reloj real (telemetría en vivo del menú de depuración).
      Los escenarios simulados suponen Z ≈ +1 g con la esfera hacia arriba y el brazo
      colgando en (−240, −940, 240); si los signos no coinciden, corregir las constantes de
      `SimulatedAccelSource` (y luego el detector).
- [ ] **Pantalla apagada mientras graba**: con la guardia activa (grabando actividad), si
      la `watch-app` sigue recibiendo lotes a 25 Hz y puede vibrar cuando la pantalla AMOLED
      se apaga o atenúa. Mirar los Hz efectivos en la telemetría al volver a encender la
      pantalla. El simulador no lo reproduce.
- [ ] **App inactiva grabando** (selector de tareas): confirmar en el reloj que sigue a
      25 Hz gracias a la actividad, y que con `recordActivity` desactivado baja a ≤10 Hz.
- [ ] **Actividad en Garmin Connect**: que aparezca como "Otro" con el nombre
      "Guardia focus"/"Focus guard", y ver si cuenta para carga de entrenamiento, Body
      Battery o minutos de intensidad (`SPORT_GENERIC` se eligió por ser el más neutro).
- [ ] **Cierre por el sistema con la guardia activa** (batería, otra app, apagado): en ese
      caso solo corre `onStop`, que es justo el camino que tumba el simulador. Comprobar en
      el reloj que la actividad se guarda.
- [ ] Reproducir en el simulador un FIT grabado en el reloj con `SensorLogging` (*Activity
      Data > FIT/GPX Playable File*) para probar el sensor real con datos de muñeca reales.
- [ ] Diseñar los 3 niveles de vibración solo con duración, pulsos y pausas (máximo 8
      `VibeProfile` por llamada), y comprobar en el reloj que se distinguen.
- [ ] Desde dónde lanza el usuario la app en el fr165 (menú de apps o glance), para evitar el
      cierre por tiempo de las apps abiertas desde glances.

## 3. Interfaz (fase 7)

- [ ] **Decidir si la hora necesita una fuente personalizada** para acercarse a la demo web,
      y si su costo en memoria es aceptable dentro de los 768 KB.
- [ ] En el **reloj real**, si `FONT_NUMBER_*` dibuja `%` y letras. El simulador usa Roboto
      TTF para todo y no sirve para comprobarlo. Mientras tanto el `%` va aparte en `LABEL`.
- [ ] "Iniciar guardia" baja a `FONT_TINY` y "Estoy despierto" a `FONT_XTINY` en el botón de
      226 px. En la pantalla de alerta hay espacio para un botón más ancho, y en la principal se
      puede revisar la posición. Decidirlo al diseñar esas pantallas.
- [ ] "Monitoreo en pausa" en `FONT_SMALL` ocupa casi todo el ancho de la vista principal
      actual. Se rehace en la fase 7 con `RoundLayout`.
- [ ] En la pantalla de alerta, "¡DESPIERTA!" en `FONT_LARGE` mide casi todo el ancho
      seguro. Revisarlo en el reloj y usar `Draw.fittingFont` si hace falta.

## 4. Compilación y memoria

- [ ] Consumo de batería de una guardia larga grabando actividad (25 Hz + FIT) frente a sin
      grabar (fase 12).
- [ ] Comprobar en tiempo de ejecución que el `.prg` release no contiene la guía de estilo ni
      el menú de depuración: mantener UP en la app instalada desde el `.iq` no debe abrir nada.
- [ ] Las funciones auxiliares sin `(:test)` de `tests/` (`colorsMatch`, `insideCircle`) y
      los textos `StyleGuide*`/`TypeRole*`/`Debug*` se empaquetan también en release. Medir con el
      perfilador de memoria del simulador si el costo importa (fase 12).

## 5. AMOLED y accesibilidad (reloj real)

- [ ] `ORANGE`, `ORANGE_DEEP` y `RED_INTENSE` se distinguen entre sí en el reloj; en el
      simulador sí se distinguen.
- [ ] La pista `BORDER` del anillo se ve sin llamar la atención con brillo bajo.
- [ ] El botón grande (226×54 px, área táctil 248×76 px) se acierta con el reloj puesto y la
      mano en movimiento.

## 6. Ícono y tienda (fase 13)

- [ ] Ver el ícono de 54×54 en el menú de apps del simulador y del reloj: que el pulso se
      lea a tamaño real.
- [ ] Revisar los requisitos actuales de la Connect IQ Store: ícono, capturas y descripción
      en español e inglés.
