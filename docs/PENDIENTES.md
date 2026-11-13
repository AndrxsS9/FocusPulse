# Pendientes de verificar

Las fases 1 y 2 se compilaron, probaron y revisaron en el simulador con el **Connect IQ SDK
9.3.0** (2026-11-12), y las fases 3, 4, 5 y 6 el 2026-11-13. La primera sección resume lo que quedó confirmado; el resto del
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

### Esfera principal (fase 4, simulador)

- Las **57 pruebas** pasan (15 nuevas: `AlertnessScore`, `ClockFormat` y el hit-testing del
  botón). `build.ps1` y `export.ps1` sin advertencias.
- La esfera se revisó en el **fr165 y el fr165m** (`run.ps1 -TargetDevice fr165m`), en
  **español e inglés**: nada se corta contra el borde redondo. Anatomía y medidas en
  `DISENO.md` §5.1.
- Con la fuente simulada, el anillo y el porcentaje **bajan en inactividad** (88 → 60 %
  cian → 24 % rojo en unos 30 s) y **suben con tecleo** (24 → 45 % ámbar en unos 10 s).
- **Entrada táctil:** en el fr165, START y cualquier toque llegan primero a `onSelect`; con
  `onSelect` devolviendo `true`, `onTap` no se llamaba nunca (verificado con mensajes en
  consola). La esfera devuelve `false` y decide en `onKey` (`KEY_ENTER`) y `onTap`. Medido:
  toque en el botón = (196, 308), toque en la hora = (196, 166). START y el toque en el botón
  alternan la guardia; un toque fuera no hace nada.
- **Refresco:** 1 redibujo/s en pausa, 5/s con la guardia activa; ninguno entre *Force
  onHide* y *Force onShow* (6,8 s sin ticks) y se reanuda solo.
- La guía de estilo sigue bien con las nuevas zonas de `RoundLayout`.
- El escenario simulado **normal** daba una varianza de ≈2 000 mg² con ruido uniforme de
  ±70 mg, por encima del umbral de actividad alta del puntaje (1 500 mg²): el puntaje lo
  trataba como tecleo. Ahora usa ruido triangular dentro de ±70 mg (≈600–800 mg²).

### Orbe IA y animación (fase 5, simulador)

- Las **74 pruebas** pasan (17 nuevas: `TrigTable`, `OrbModel`, `ColorMath`, `FrameStats`).
- **`Dc.setStroke` / `Dc.setFill` no existen en el fr165** en tiempo de ejecución: la app se
  cerró con *Symbol Not Found Error: Could not find symbol 'setStroke'*, aunque
  `compiler.json` diga `alphaBlendingSupport: true` y la doc lo liste. La transparencia se
  simula mezclando el color con el fondo (`ColorMath.blend`).
- Medido con `FrameStats` (ventanas de 5 s, salida de consola de la compilación de
  depuración), misma sesión del simulador cambiando el escenario desde el menú de
  depuración. El tiempo del orbe confirma la velocidad de cada estado:

  | Estado | Cuadros/s | Dibujo medio (máx.) | Tiempo del orbe por cada 5 s |
  |---|---|---|---|
  | Pausa | 1,2–1,6 | 4–13 ms (16) | 0 (quieto) |
  | Normal | 12,6–13,2 | 3,4–8,1 ms (16) | ≈ 5,1 s (1×) |
  | Tecleo (activo) | 12,4–13,4 | 3,4–6,0 ms (16) | ≈ 10,3 s (2×) |
  | Inactividad (somnoliento) | 12,2–13,2 | 9–12,7 ms (32) | ≈ 1,8 s (0,36×) |
  | fr165m, inactividad | 12,2–13,2 | 6,9–12 ms (16) | ≈ 1,8 s |

  Pasan algo más de 12 cuadros/s porque cada lote de telemetría (1 por segundo) pide su
  propio redibujo. `System.getTimer()` en Windows avanza a saltos de ≈16 ms, así que el
  máximo de 16 o 32 ms es la resolución del reloj, no un cuadro lento. Con un periodo de
  83 ms queda mucho margen; no hizo falta bajar N ni los cuadros por segundo, ni usar un
  `BufferedBitmap`. Memoria de la app en el simulador: **44 de 764 kB**.
- En inactividad el orbe pasó de cian a ámbar y a rojo (captura a 0 %) a cámara lenta; en
  tecleo siguió cian y al doble de velocidad. El arco gira y el punto late (capturas en dos
  momentos del ciclo con el halo de distinto tamaño). No tapa la hora.
- El paso por ámbar quedó en el registro (estado somnoliento) pero no en una captura: la
  paleta en 60/59/35/34 la cubren las pruebas.

### Detector de somnolencia (fase 6, simulador)

- Las **100 pruebas** pasan (26 nuevas). `build.ps1` y `export.ps1` sin advertencias.
  Las secuencias de 2 minutos (120 lotes, 3 000 muestras) no disparan el *watchdog* del
  simulador.
- Una clase anotada `(:test)` (`DetectorRig`) compila en las dos compilaciones y queda
  fuera de la normal. Una función sin `(:test)` que la use rompe la compilación normal
  (`Undefined symbol`), así que los auxiliares que la necesitan son métodos de la clase.
- Recorrido en *Detector en vivo* (fr165, español), con los tiempos medidos en la consola
  (`EVENTO … a los N s de iniciar`): inactividad a los **8,0 s**; cabeceo a los **6,0 s**
  con 76° de inclinación, pasando por "Caída detectada"; tecleo y movimiento normal sin
  eventos en 20 s; "Calibrando…" en la píldora los primeros 5 s; al pausar, el detector y
  el clasificador vuelven a cero y el último evento sigue a la vista. Detalle en
  [DETECTOR.md](DETECTOR.md) §6.3.
- En `FONT_XTINY` la línea superior de la vista (y ≈ 58 px) admite unos 18 caracteres:
  "Caída · verificando quietud" no cabía y quedó "Caída detectada".

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

- [ ] **Validar el detector con datos de muñeca reales** (fase 11 o antes, con
      `SensorLogging`): la sacudida de 400 mg, los 35° de inclinación, los 50 mg de
      "calma", el piso de 25 mg² del umbral y los pesos del clasificador salen de
      escenarios simulados.
- [ ] **Ruido del acelerómetro del fr165 en reposo**: el umbral adaptativo no baja de
      25 mg² (σ = 5 mg). Si el ruido real de un brazo inerte supera eso, la quietud nunca
      llegaría para quien calibró moviéndose poco.
- [ ] **Falso positivo posible: girar la muñeca para mirar la hora y quedarse leyendo**
      (sacudida + inclinación > 35° + magnitud constante). Probarlo en el reloj; si
      dispara, exigir la dirección de la caída ([DETECTOR.md](DETECTOR.md) §7).
- [ ] Con el acelerómetro del simulador (*Activity Data*, vectores de 1 g al azar) el
      detector daría cabeceos continuos. No se probó; para la sustentación, usar la fuente
      simulada.

## 3. Interfaz

- [ ] **Decidir si la hora necesita una fuente personalizada** para acercarse a la demo web,
      y si su costo en memoria es aceptable dentro de los 768 KB.
- [ ] En el **reloj real**, si `FONT_NUMBER_MEDIUM` (la hora) se ve igual que en el
      simulador, que usa Roboto TTF para todo. El porcentaje de la esfera usa `FONT_SMALL`
      (fuente de texto) para no depender de que las numéricas traigan `%`.
- [ ] "Estoy despierto" baja a `FONT_XTINY` en un botón de 226 px. En la pantalla de alerta
      (fase 7) hay espacio para un botón más ancho. ("Iniciar guardia" en `FONT_TINY` se ve
      bien en la esfera: decidido en la fase 4.)
- [ ] En la pantalla de alerta, "¡DESPIERTA!" en `FONT_LARGE` mide casi todo el ancho
      seguro. Revisarlo en el reloj y usar `Draw.fittingFont` si hace falta.
- [ ] Ver en el simulador la píldora **"Sensor no disponible"** (ámbar) y la batería baja
      en rojo (≤ 15 %, *Settings > Set Battery Status*). No se forzaron en la fase 4: el
      acelerómetro del simulador siempre se registra bien.
- [ ] Ver la hora en **12 h y 24 h** con una hora que las distinga (antes de las 10 o
      después de las 13; *Settings > Time Display*). En la revisión eran las 11, igual en
      ambos formatos; el formato lo cubren las pruebas de `ClockFormat`.
- [ ] En el reloj real: que el toque en el botón (área de 248×76 px) se acierte con el reloj
      puesto, y que la píldora, cuyo borde inferior queda 3 px dentro del área táctil del
      botón, no provoque toques no deseados.
- [ ] **Quemado AMOLED:** la hora en `TEXT` y la marca DEMO no se mueven. Para guardias
      largas, valorar un desplazamiento de unos píxeles cada minuto (fase 12). El orbe y las
      partículas sí se mueven, pero en pausa quedan fijos (tenues).
- [ ] Revisar *Detector en vivo* en **inglés** y en el **fr165m**: solo se vio en español
      en el fr165. Los textos en inglés son más cortos o iguales.
- [ ] Ver en el reloj real que el arco de escaneo (3 px, cian al 55 %) y el orbe tenue en
      pausa se distinguen con brillo bajo, y que el orbe no resta legibilidad a la hora al
      sol.

## 4. Compilación y memoria

- [ ] **Batería de la animación (fase 12):** medir en el reloj real el consumo de una guardia
      larga con el orbe a ≈12 cuadros/s frente a `ANIMATIONS_ENABLED = false` (1 cuadro/s),
      además del de grabar la actividad (25 Hz + FIT). Según el resultado, bajar la tasa con
      la pantalla atenuada, apagar la animación tras unos minutos sin mirar el reloj o
      ofrecer el ajuste "Animaciones reducidas".
- [ ] Tiempo de dibujo **en el reloj real**: el simulador corre en el PC y no refleja la CPU
      del fr165. Si un cuadro supera unos 60 ms, reducir `OrbModel.POINTS` (36 → 24) o la
      tasa, o dibujar la capa fija (pista del anillo, partículas en pausa) en un
      `BufferedBitmap`.
- [ ] Comprobar en el reloj si `setStroke`/`setFill` (alfa real) existen en el firmware; si
      sí, valorar usarlos con un `has` en lugar de la mezcla precalculada.
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
