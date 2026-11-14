# Pendientes de verificar

Las fases 1 y 2 se compilaron, probaron y revisaron en el simulador con el **Connect IQ SDK
9.3.0** (2026-11-12), las fases 3 a 8 el 2026-11-13 y las fases 9, 10 y 11 el 2026-11-14. La primera sección resume lo que quedó confirmado; el resto del
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

### Alerta háptica (fase 7, simulador)

- Las **124 pruebas** pasan (24 nuevas). `build.ps1` y `export.ps1` (fr165 y fr165m) sin
  advertencias con `-l 3`.
- Recorrido en el fr165, en **español e inglés**, con la fuente simulada y la consola de la
  compilación de depuración (`ALERTA …` y `EVENTO …`):
  - **Cabeceo:** evento a los 6,0 s → alerta de nivel 1 "Cabeceo / pérdida de tono
    muscular" / "Head nod / loss of muscle tone".
  - **Inactividad:** evento a los 8,0 s → alerta "Inactividad prolongada" / "Prolonged
    inactivity".
  - Con la alerta abierta llegaron inactividades a los 16 y 27 s y **se ignoraron** (ninguna
    alerta nueva). Tras descartar, la siguiente llegó a los 38 s: el refractario se respeta.
  - **START** y un **toque en el botón** cierran la alerta y vuelven a la esfera; un toque
    fuera del botón y **BACK no hacen nada** (BACK sí funciona en el menú justo después, así
    que la tecla llegó). Tras descartar con la guardia activa, el puntaje queda en 70 (en la
    esfera se ve 68 % un segundo después, porque el clasificador sigue en Inerte); con la
    guardia en pausa no cambia.
  - **Niveles 1, 2 y 3** desde "Probar alerta nivel N": colores, textos y botón sin cortes
    en ambos idiomas. Ráfagas contadas al descartar: 8 en 22,6 s (nivel 1, cada 3 s) y 7 en
    12,2 s (nivel 2, cada 2 s): el temporizador repite al ritmo previsto.
  - Pulso del fondo (rojo intenso ↔ rojo oscuro en el nivel 3) y sacudida vistos en capturas
    seguidas. La entrada de 300 ms es demasiado rápida para capturarla; con la duración
    alargada a 3 s (cambio temporal, no versionado) se vio el disco creciendo desde el centro.
  - Memoria con la alerta abierta: **68 de 764 kB**.
- **Cómo se ve la vibración en el simulador (SDK 9.3.0, Windows):** no se ve. Ni la ventana
  ni la imagen del reloj se mueven (medido: posición de la ventana muestreada cada 5 ms
  durante el nivel 3 y píxeles de la correa iguales en 6 capturas), y la barra de estado no
  tiene indicador de vibración. Para comprobarla:
  1. la **consola** de la compilación de depuración escribe al abrir cada alerta
     `ALERTA nivel N: vibración [tramos] cada P ms, tono …, luz …` (o `vibración no (sin
     motor o apagada en el reloj)`), y al descartar `ALERTA descartada en T ms (R ráfagas)`;
  2. la **barra de estado** pasa de "☀ Off" a "☀ Default" al abrirse la alerta: es
     `Attention.backlight(true)`;
  3. *Settings > Vibrate* desmarcado → la consola dice `vibración no` y la alerta sigue,
     solo visual, con luz y tono (verificado);
  4. la **sacudida** de la propia alerta sigue el mismo patrón que el motor.
  El sonido de los tonos no se comprobó (no se escuchó la salida de audio del equipo); la
  consola confirma que el fr165 tiene `playTone`, `ToneProfile` y *Settings > Tones* activado.
- Automatizar el simulador: la pantalla está escalada al 125 %, así que `GetWindowRect` y
  `SetCursorPos` usan coordenadas lógicas y una captura de pantalla completa, físicas
  (× 1,25). Los menús del simulador (*Settings*) no se exponen por UI Automation.

### Modo demo (fase 8, simulador)

- Las **142 pruebas** pasan (18 nuevas: 7 de `DemoConfig`, 1 de `DemoStore` con el
  `Application.Storage` del simulador, 4 de `Toast` y la regla de DOWN, 6 de
  `DemoScript`). `build.ps1`, `build.ps1 -Release` y `export.ps1` (fr165 y fr165m) sin
  advertencias con `-l 3`.
- Recorrido con la **compilación de release** (`run.ps1 -Release`) en el fr165, en
  **español e inglés**:
  - **Mantener UP** abre el menú principal *FocusPulse AI* y no tiene la entrada
    *Depuración*. En la compilación de depuración sí está, abre el menú de siempre, y su
    selector de fuente cambia el mismo ajuste ("Simular cabeceo" → "DEMO · Cabeceo").
  - **Modo demo**: START cambia el interruptor ("Sensor real" ↔ "Datos simulados"), el
    menú se rehace con *Escenario*, *Guion automático* y *Probar alerta* y el foco sigue
    en el interruptor. **Se recuerda al volver a abrir la app** (Storage).
  - **Escenario**: submenú con los 4 escenarios y el foco en el actual; el subtítulo del
    menú se actualiza al elegir.
  - **DOWN**: en pausa no hace nada; con la guardia activa recorre normal → tecleo →
    cabeceo → inactividad → normal con el aviso "Escenario / …", que ya no está a los
    1,8 s. "Inactividad prolongada" y "Prolonged inactivity" bajan de fuente y caben.
  - **Guion automático** completo en los dos idiomas: "Guion 1/5 · Normal" con
    "Calibrando…", 2/5 tecleo a los 10 s, 3/5 cabeceo a los 20 s y su alerta antes de los
    33 s. **Sin responder durante 15 s el guion siguió esperando.** Tras "Estoy despierto",
    4/5 normal, 5/5 inactividad a los 8 s y su alerta; al responder, aviso "Guion
    automático / Completado" ("Auto script / Complete") y "DEMO · Normal".
    Cancelar desde el menú ("Detener · paso 1/5") y pausando la guardia vuelve a
    "DEMO · …".
  - **Probar alerta**: niveles 1, 2 y 3 se abren sobre la esfera y START vuelve a ella.
  - **Acerca de**: nombre, "Versión 0.8.0" y la descripción. La primera versión cortaba la
    descripción con "…" (la caja llegaba muy abajo, donde el círculo es estrecho): se
    acortó el texto y se subió el bloque.
  - **Desactivar el modo demo con la guardia activa**: desaparecen los ítems de la demo,
    vuelve la fecha, el puntaje se reinicia a 88 y queda "Calibrando…" con el sensor real,
    sin errores; DOWN deja de cambiar nada. Sin *Activity Data* el acelerómetro del
    simulador no entrega lotes, así que la calibración no termina (comportamiento
    conocido de la fase 3).
  - Las líneas de la esfera más largas caben en `dateY`: "Guion 2/5 · Tecleo activo",
    "Script 2/5 · Active typing", "Guion 5/5 · Inactividad".
- `test.ps1` deja el simulador sin dispositivo ("CIQ Simulator" vacío): hay que volver a
  cargar la app con `run.ps1`. Está en [GUIA_DEMO.md](GUIA_DEMO.md).
- Automatizar los clics: `SetForegroundWindow` no siempre da el foco al simulador desde
  otro proceso; un clic en la barra de título lo asegura antes de pulsar botones.

### Escalamiento, fatiga, descanso, resumen e historial (fase 9, simulador)

- Las **167 pruebas** pasan (25 nuevas: 5 de escalamiento y 1 de nivel máximo en
  `AlertLog`, 7 de `FatiguePredictor`, 4 de `BreakTimer` y la cuenta regresiva, 7 de
  `GuardSummary`/`SessionHistory`/`HistoryStore` con el Storage del simulador, y el paso
  nuevo del guion; el recorrido completo del guion con el detector se amplió a 6 pasos).
  `build.ps1`, `build.ps1 -Release` y `export.ps1` (fr165 y fr165m) sin advertencias con
  `-l 3`. Release: `FocusPulse-release.prg` 73,8 kB, `FocusPulse.iq` 176 kB.
- Recorrido con la **compilación de release** (`run.ps1 -Release`) en el fr165, en
  **español e inglés**:
  - **Escalamiento:** "Probar alerta → Nivel 1" con la guardia en pausa: naranja nivel 1 →
    naranja intenso "Nivel 2 de 3 · vibración media" → rojo "Nivel 3 de 3 · vibración
    máxima", sin cerrarse; a los 40 s seguía en el 3. BACK no la cerró; START sí. En la
    compilación de depuración: "sube al nivel 2 a los 6031 ms" y "al nivel 3 a los
    12109 ms" (demo), y "ALERTA descartada en 25531 ms, nivel máximo 3".
  - **Aviso de fatiga:** escenario de inactividad, 3 alertas respondidas → la consola pasa
    a "fatiga 2" y la esfera muestra "Micro-sueños repetidos / descansa 15 min" ("Repeated
    micro-sleeps / take a 15 min break") en lugar del puntaje y la píldora. La primera
    versión ("toma un descanso de 15 min") se cortaba contra el borde redondo: se acortó y
    se bajó la caja ([DISENO.md](DISENO.md) §5.4).
  - **Descanso:** tocando el aviso y desde el menú (*Tomar descanso*): anillo cian que se
    vacía, 0:30 → "Descanso terminado" + "Reanudar guardia"; START y el toque en el botón
    reanudan (vuelve a "Calibrando…" y el aviso desaparece). BACK a mitad de cuenta
    cancela y reanuda.
  - **Resumen al pausar:** con episodios y con más de 1 min, se abre; una guardia de 3 s
    sin episodios no lo muestra ni la guarda. Tras un descanso completo, el resumen de esa
    guardia dice "Fatiga: Bajo" con sus 5 episodios. START vuelve a la esfera.
  - **Historial:** subtítulo "3 guardias", lista "14 nov · 12:02 / 1 min 11 s · 3
    episodios" ("Nov 14 · 12:02 / … · 3 episodes"), detalle con la fecha de título; se
    conserva al volver a abrir la app. *Borrar historial* → *Cancelar* no borra;
    *Confirmar* deja "Aún no hay guardias" ("No guards yet") y actualiza el subtítulo.
  - **Guion automático completo** en los dos idiomas: "Guion 1/6 · Normal" … paso 6 sin
    responder: nivel 2 a los 6 s, nivel 3 a los 12 s, y 4 s después la guardia se pausa sola
    y se abre el resumen (1 min 11 s, 3 episodios, respuesta media 1,9 s, nivel máximo 3 de
    3, fatiga Alto, DEMO).
- **Cambiar el idioma del simulador** (*Settings > Language*) con la app abierta no cambia
  sus textos: se cargan al iniciar la app; hay que volver a cargarla
  (`run.ps1 -Release -NoBuild`). Una vez el clic en el idioma no se aplicó y hubo que
  repetirlo. Está en [GUIA_DEMO.md](GUIA_DEMO.md).
- Con el **menú principal abierto**, una alerta del detector se apila encima; al
  responderla se vuelve al menú, no a la esfera (comportamiento de `pushView`, ya existía
  en la fase 8). No molesta en la demo, pero ver el punto de la sección 3.

### IA entrenada (fase 10, Python y simulador)

- **Python 3.12.10** instalado con `winget install Python.Python.3.12` (en el equipo ya había
  3.14; el pipeline usa 3.12 con `py -3.12`). `ml\.venv` con numpy 2.5.4, pandas 3.1.1,
  scikit-learn 1.9.1 y matplotlib 3.11.2 (`ml\requirements.txt`).
- `scripts\train.ps1` corre de punta a punta en ≈ 30 s y es **reproducible**: con la semilla
  por defecto, `git status` queda limpio después (pesos, vectores, informe y PNG idénticos).
  `-Seed 7 -NoExport` también funciona (y no toca `source\` ni `tests\`).
- Las **172 pruebas** pasan (5 nuevas y varias ajustadas). `build.ps1` y `build.ps1 -Release`
  sin advertencias con `-l 3`.
- **Python y el reloj calculan lo mismo**: en 1 600 muestras fijas coinciden los 64 eventos
  del detector y las características de 62 ventanas (diferencia máxima 8 × 10⁻⁶ grados en la
  inclinación, 0 en el resto); las probabilidades de 16 ventanas, con diferencia < 10⁻⁶.
- **`monkeyc -t -l 3` revienta con `java.lang.StackOverflowError`** con un arreglo literal de
  ≈ 1 600 elementos (la compilación normal sí pasa). `ml/test_vectors.py` parte los arreglos
  en filas de 100.
- Los números de `ClassifierWeights.mc` se escriben como `Float` en notación decimal (el
  `float32` más corto, sin exponente): compilan sin errores con `-l 3`.
- Resultado en Python (12 usuarios sintéticos de prueba, [IA.md](IA.md) §8): exactitud 89,7 %
  (v1) → 93,3 % (v2); falsos cabeceos en 16 → 12 de 48 episodios difíciles. En el reloj, la
  matriz de los escenarios del simulador pasa de 93,1 % a 98,4 %.
- Recorrido en el simulador (fr165), con una traza temporal del clasificador por lote en la
  consola (no versionada):
  - **Depuración, español**, escenarios con DOWN: tecleo (Activo) → cabeceo (Normal →
    Cabeceo 0,51 y 0,64 con la caída pendiente → evento a los 6,0 s → alerta respondida →
    Inerte) → inactividad → **mirar la hora: 31 de 31 lotes Normal, 0 eventos** → normal →
    **tecleo → normal: ningún lote Cabeceo ni evento**. Al pausar, resumen (2 episodios).
  - **Release, español e inglés**: **guion automático completo**: cabeceo a los 26 s (paso 3,
    respondido), inactividad a los 45 s (paso 5, respondida), paso 6 sin responder hasta el
    nivel 3 y resumen automático (1 min 12 s / 1 min 13 s, 3 episodios, nivel máximo 3 de 3,
    fatiga Alto / High).
  - **Inglés**: mirar la hora 32 de 32 lotes Normal, 0 eventos; "DEMO · Glance" cabe en la
    esfera.
  - Pantalla **Modelo IA** en los dos idiomas: "Modelo IA / v2" en el menú (entre *Historial*
    y *Acerca de*); versión, "Regresión logística · 4 clases", exactitud 93,3 % (93.3%),
    falsos cabeceos 25,0 % (25.0%) y "Entrenado con datos sintéticos" en dos líneas. La
    primera versión cortaba la nota con "…": se subió el bloque y se le dio altura para dos
    líneas. BACK vuelve al menú.
- **Automatizar el simulador sin tocar el ratón del usuario**: `PrintWindow` captura la
  ventana aunque esté tapada, y los clics simples se pueden enviar con
  `PostMessage(WM_LBUTTONDOWN/UP)` a la ventana hija en coordenadas lógicas (el simulador no
  es consciente del DPI). Los comandos de la barra de menús se envían con `WM_COMMAND`:
  idioma español 6078, inglés 6064, *Kill App* 6005. **La pulsación larga (mantener UP) no
  funciona por mensajes** (ni con `SetKeyboardState`): el simulador lee el estado físico del
  ratón. Para el recorrido, un cambio temporal y no versionado hacía que DOWN en pausa
  abriera el menú.

### Ajustes, confirmación por IA y transición de la demo (fase 11, Python y simulador)

- Las **194 pruebas** pasan (22 nuevas). `build.ps1`, `build.ps1 -Release` y `export.ps1`
  (fr165 y fr165m) sin advertencias con `-l 3`. Release: `FocusPulse-release.prg` 87,0 kB,
  `FocusPulse.iq` 201,5 kB. `scripts\train.ps1` sigue siendo reproducible (pesos, vectores e
  informes idénticos) y ahora corre también `ml\confirmation.py`.
- **Confirmación por IA, Python** ([IA.md](IA.md) §12): esperar 2 lotes y exigir p(Normal)
  suavizada < 0,35 (elegido con el entrenamiento). Prueba: falsos cabeceos al mirar la hora
  **15 → 3 de 24**, cabeceos reales **22 → 22 de 36**, otros falsos 0 → 0; la alerta de
  cabeceo llega 2 s más tarde.
- **Transición de la demo**: cambiar de cabeceo a inactividad ya no da sacudida (≈ 38 mg
  frente a 1 228) ni cabeceo de más. La matriz de confusión del reloj (v2) queda en 1 032 de
  1 050 (98,3 %; antes 1 033).
- Recorrido en el simulador (fr165), sin usar el ratón ni el teclado reales: botones y
  toques con `PostMessage` a la ventana del simulador, menús con `WM_COMMAND`, capturas con
  `PrintWindow`, y un cambio **temporal y no versionado** para que DOWN en pausa abriera el
  menú (mantener UP no funciona por mensajes):
  - **Ajustes** (depuración, español): el menú principal muestra "Ajustes · Sensibilidad:
    Media"; los submenús abren con el foco en el valor actual y el subtítulo se actualiza.
    Cada cambio llega a la consola ("AJUSTES sensibilidad 2, vibración 0, …") y **se
    conserva al volver a abrir la app** (Kill App y `run.ps1 -NoBuild`).
  - Las etiquetas "Animaciones reducidas" y "Confirmación por IA" se cortaban con "…" junto
    al interruptor y el texto del aviso "Alerta solo visual" también: se acortaron
    ("Animaciones: Reducidas/Completas", "Confirmar IA") y se subió el bloque del aviso.
    Revisado en español e inglés ("Animations", "AI confirm", "Record activity").
  - **Aviso de alerta solo visual**: Vibración Apagada + Sonido apagado abre la pantalla
    de aviso y el subtítulo dice "Apagada · solo visual"; al iniciar la guardia sale el
    aviso de 3 s "Alerta solo visual / Sin vibración ni sonido". La alerta dice "Nivel 1 de 3
    · sin vibración" y la consola "vibración no (apagada en el ajuste …), tono no (ajuste
    Sonido apagado)".
  - **Editor de ajustes del simulador** (*File > Edit Persistent Storage > Edit
    Application.Properties data*, el equivalente a Garmin Connect): al principio decía "No
    settings file found for this app"; busca `GARMIN\Settings\<NOMBRE>-settings.json`,
    con NOMBRE = **FOCUSPULSE-TEST** (el simulador conserva el nombre del primer .prg
    instalado con este id), y `monkeydo /a` solo envía un archivo. `run.ps1` ahora copia el
    JSON con los tres nombres. Con él, el editor mostró los 6 ajustes con sus valores;
    desactivar *AI confirmation* y **Save** con la guardia abierta llegó a
    `onSettingsChanged` y se aplicó en el acto (consola "confirmación IA false"), y
    volver a activarlo también.
  - **Animaciones reducidas**: orbe sin partículas. Alerta de nivel 3 con vibración
    Fuerte: el título no se mueve (x = 177 px en 8 cuadros seguidos) frente a ±6 px con
    animaciones completas (171 ↔ 183). Mismo rojo y mismos textos.
  - **Confirmación**: con la sensibilidad media, cabeceo → evento a los 43,0 s, "CABECEO
    confirmado por el modelo a los 45,0 s: p(Normal) 0,14" y alerta. Con sensibilidad
    **Alta** (el giro de 366 mg ya abre la caída), *mirar la hora* dio eventos CABECEO
    **descartados** (p(Normal) 0,70 y 0,59) y **ninguna alerta**; con la confirmación
    desactivada desde el editor, alerta a los 7 s.
  - **Cabeceo → inactividad con DOWN**: solo la alerta de inactividad, ningún cabeceo.
  - **Guion automático completo (release)**, español e inglés: alertas en los pasos 3
    (≈ 28 s) y 5 (≈ 48 s), paso 6 sin responder hasta el nivel 3 y resumen automático
    (1 min 15 s / 1 min 14 s, 3 episodios, nivel máximo 3 de 3, fatiga Alto / High).
  - Al terminar, el simulador quedó en español con los ajustes por defecto.

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
- [ ] **Sentir la vibración real en el reloj** (fase 7). Los 3 niveles ya están diseñados
      solo con duración, pulsos y pausas ([DISENO.md](DISENO.md) §5.3). En el fr165:
      - que se **distinguen** los tres sin mirar la pantalla (2×150 ms cada 3 s, 3×300 ms
        cada 2 s, 800/200 ms casi continuo) y que el nivel 1 no sea tan suave que no
        despierte;
      - que los tramos con `dutyCycle` 0 sean **pausas** y no vibración: los Forerunner
        ignoran el `dutyCycle`; si los 0 vibran, el patrón entero sería un zumbido continuo
        y habría que lanzar cada pulso con su propio `Timer`;
      - que `stop()` **corte la ráfaga en curso** (`VibeProfile(0, 10)`): en el nivel 3
        quedan hasta 3,8 s de vibración si una llamada nueva no reemplaza a la anterior;
      - que se siente con la **pantalla apagada o atenuada** y con la app inactiva grabando
        (ver los puntos de arriba sobre `Attention` denegada).
- [ ] **Luz con protección contra quemado**: `Attention.backlight(true)` en cada ráfaga
      puede lanzar `BacklightOnTooLongException` tras ≈ 1 min de alerta en el AMOLED. Se
      atrapa; comprobar en el reloj que la alerta sigue visible y que no se apaga la pantalla.
- [ ] **Tono en el fr165**: si el reloj suena de verdad (tiene `playTone` según el SDK), con
      qué volumen, y si el `ToneProfile` con silencios de 0 Hz se acepta (si lanza
      `InvalidOptionsException`, `Haptics` pasa a `TONE_ALERT_HI`). El ajuste "Sonido"
      (fase 11) permite apagarlo; el sonido del simulador no se escuchó.
- [ ] **Niveles del ajuste "Vibración" en el reloj** (fase 11): que Suave, Normal y Fuerte
      se distinguen y que Suave nivel 1 (un pulso de 150 ms cada 3 s) todavía despierta. Si
      no, subir Suave a 2 pulsos.
- [ ] **"Sonido" en otros relojes**: `settings.xml` muestra siempre el ajuste porque los dos
      productos (fr165, fr165m) tienen `playTone`; el menú del reloj lo esconde si no hay
      altavoz. Si se añade un producto sin `playTone`, usar un `settings.xml` por producto.
- [ ] La sacudida de la vista se calcula desde el inicio de la alerta y la vibración desde
      el `Timer` de `Haptics`: en una alerta larga podrían desfasarse unas decenas de ms.
      Mirarlo en el reloj; si se nota, que la vista lea el ciclo de `Haptics`.
- [ ] Desde dónde lanza el usuario la app en el fr165 (menú de apps o glance), para evitar el
      cierre por tiempo de las apps abiertas desde glances.
- [ ] **Modo demo en el reloj real** (fase 8): que mantener UP abra el menú principal, que
      DOWN durante la guardia llegue como `onNextPage` y cambie de escenario, y que el modo
      se recuerde tras reiniciar el reloj (`Storage`).

- [ ] **Validar el detector y el modelo con datos de muñeca reales** (fase 12, con
      `SensorLogging`): la sacudida de 400 mg, los 35° de inclinación, los 50 mg de
      "calma" y el piso de 25 mg² salen de escenarios simulados, y los **pesos v2 se
      entrenaron solo con datos sintéticos** ([IA.md](IA.md) §9). Grabar con etiquetas
      (vídeo o pulsador), importar con `ml/import_real.py` y reentrenar.
- [ ] **Leer el FIT de `SensorLogging`** en `ml/import_real.py` (`load_fit`, hoy
      `NotImplementedError`): falta un archivo real del reloj para escribirlo y probarlo, y
      añadir el FIT SDK de Garmin para Python a los requisitos.
- [ ] **Ruido del acelerómetro del fr165 en reposo**: el umbral adaptativo no baja de
      25 mg² (σ = 5 mg). Si el ruido real de un brazo inerte supera eso, la quietud nunca
      llegaría para quien calibró moviéndose poco.
- [ ] **Confirmación por IA con datos reales** (fase 11): con datos sintéticos baja los
      falsos cabeceos al mirar la hora de 15 a 3 de 24 sin perder cabeceos, a cambio de 2 s
      de retraso. Revisar en el reloj el retardo (2 lotes) y el umbral (p(Normal) < 0,35):
      si un brazo dormido real tarda más en parecer Inerte, se perderían alertas de
      cabeceo (la inactividad las cubriría a los 60 s). Los 3 falsos que quedan son lecturas
      con el brazo casi inmóvil ([IA.md](IA.md) §12).
- [ ] **Sensibilidad Baja / Alta** (fase 11): los valores (440/340 mg, 45/28°, ×1,5/×0,75)
      salen de criterio y del dataset sintético (recall 17 / 22 / 30 de 36). Validarlos con
      datos reales.
- [ ] **Mirar la hora en el clasificador v2**: todavía 12 de 48 episodios difíciles (todos de
      mirar la hora) tienen algún lote Cabeceo, y al leer p(Inerte) sube hasta ≈ 0,4. Con
      datos reales, valorar características nuevas (dirección final de la gravedad).
- [ ] **Cabeceos lentos**: el detector solo ve el 61 % de los cabeceos sintéticos (caídas por
      debajo de 400 mg) y v2 tiene un recall de Cabeceo de 0,48 (v1: 0,58). Revisar con datos
      reales si la caída real es tan brusca como la simulada.
- [ ] Con el acelerómetro del simulador (*Activity Data*, vectores de 1 g al azar) el
      detector daría cabeceos continuos. No se probó; para la sustentación, usar la fuente
      simulada.

## 3. Interfaz

- [ ] **Menú Ajustes en el reloj real** (fase 11): que las etiquetas cortas caben igual que
      en el simulador (Menu2 corta a unos 13 caracteres junto al interruptor) y que el
      subtítulo "Apagada · solo visual" se lee entero.
- [ ] **Editor de ajustes del simulador**: depende del nombre con que el simulador registró
      la app (FOCUSPULSE-TEST en este equipo). Si tras *Reset All App Data* vuelve a decir
      "No settings file found", ejecutar `run.ps1` otra vez (copia el JSON con los tres
      nombres) o ver el nombre del `.SET` en `%TEMP%\com.garmin.connectiq\GARMIN\APPS\SETTINGS`.
- [ ] **Animaciones reducidas y batería**: el ajuste quita partículas y la sacudida, pero el
      orbe sigue a ≈ 12 cuadros/s. Si la medición de batería de la fase 13 lo pide, que
      también baje la tasa de redibujo.

- [ ] **Decidir si la hora necesita una fuente personalizada** para acercarse a la demo web,
      y si su costo en memoria es aceptable dentro de los 768 KB.
- [ ] En el **reloj real**, si `FONT_NUMBER_MEDIUM` (la hora) se ve igual que en el
      simulador, que usa Roboto TTF para todo. El porcentaje de la esfera usa `FONT_SMALL`
      (fuente de texto) para no depender de que las numéricas traigan `%`.
- [ ] En la alerta, "¡DESPIERTA!" cabe en `FONT_LARGE` en el simulador (se elige con
      `Draw.fittingFont`) y "Estoy despierto" va en `BODY` en el botón de 258 px (fase 7).
      Revisar en el reloj que ambos se ven igual.
- [ ] La línea "Nivel 3 de 3 · vibración máxima" (≈ 357 px) y "Level 3 of 3 · maximum
      vibration" (≈ 373 px) pasan del ancho seguro de 340 px; caben en la pantalla porque la
      alerta no tiene anillo. Ver en el reloj que no se acercan demasiado al borde curvo; si
      molesta, partir la línea en dos o abreviar.
- [ ] Probar con el reloj puesto que el botón de la alerta (área 280×86 px) se acierta
      medio dormido, y que nadie la cierra sin querer con BACK o deslizando (se consumen).
- [ ] Ver la alerta en el **fr165m**: solo se revisó en el fr165 (misma pantalla).
- [ ] **Pausar con la alerta abierta** no tiene camino en la interfaz (la alerta tapa la
      esfera y consume BACK); solo pasa al cerrar la app el sistema (`onStop` → `shutdown`)
      o si falla el cambio de fuente. Lo cubren `alertCancelClosesWithoutResponse` y el
      código de `GuardController.pause`/`shutdown`; comprobar en el reloj que un cierre
      del sistema durante una alerta detiene la vibración.
- [ ] Ver en el simulador la píldora **"Sensor no disponible"** (ámbar) y la batería baja
      en rojo (≤ 15 %, *Settings > Set Battery Status*). No se forzaron en la fase 4: el
      acelerómetro del simulador siempre se registra bien.
- [ ] Ver la hora en **12 h y 24 h** con una hora que las distinga (antes de las 10 o
      después de las 13; *Settings > Time Display*). En la revisión eran las 11, igual en
      ambos formatos; el formato lo cubren las pruebas de `ClockFormat`.
- [ ] En el reloj real: que el toque en el botón (área de 248×76 px) se acierte con el reloj
      puesto, y que la píldora, cuyo borde inferior queda 3 px dentro del área táctil del
      botón, no provoque toques no deseados.
- [ ] **Deslizar en la esfera** (pantalla táctil): en el reloj real, un deslizamiento
      vertical podría llegar como `onNextPage`/`onPreviousPage`. Con el modo demo y la
      guardia activa, deslizar hacia arriba cambiaría de escenario. En el simulador solo se
      probaron los botones; si molesta, atender solo `KEY_DOWN` en `onKey`.
- [ ] Con el **sensor real** y sin lotes (el simulador sin *Activity Data*, o un sensor que
      no entrega datos), la píldora se queda en "Calibrando…" para siempre. Valorar un
      aviso "Sin datos del sensor" tras unos segundos sin lotes (fase 12).
- [ ] Con el modo demo activo la esfera **no muestra la fecha** (su línea pasa a "DEMO ·
      escenario"). Aceptable para la demo; revisar si en el reloj se quiere la fecha en
      algún otro sitio.
- [ ] **Quemado AMOLED:** la hora en `TEXT` y la línea "DEMO · …" (cian) no se mueven. Para guardias
      largas, valorar un desplazamiento de unos píxeles cada minuto (fase 12). El orbe y las
      partículas sí se mueven, pero en pausa quedan fijos (tenues).
- [ ] Revisar *Detector en vivo* en **inglés** y en el **fr165m**: solo se vio en español
      en el fr165. Los textos en inglés son más cortos o iguales.
- [ ] Ver en el reloj real que el arco de escaneo (3 px, cian al 55 %) y el orbe tenue en
      pausa se distinguen con brillo bajo, y que el orbe no resta legibilidad a la hora al
      sol.

- [ ] **Alerta encima del menú** (fase 9): si llega un evento con el menú principal (o el
      historial) abierto, la alerta se apila encima y, al responder, se vuelve al menú. En
      el reloj la guardia normalmente corre con la esfera a la vista; valorar cerrar los
      menús al abrir una alerta del detector.
- [ ] **Aviso de fatiga en el reloj**: que "descansa 15 min" / "take a 15 min break" caben
      igual que en el simulador (`FONT_XTINY` a 2 líneas en 300×72 px) y que el aviso
      ámbar se lee con brillo bajo. Valorar recuperar la frase completa "toma un descanso de
      15 min" con una caja más alta (tapando la fecha) o un ícono.
- [ ] **Descanso de 15 min en el reloj real**: que la vista de descanso no se cierre sola
      (la pantalla AMOLED se apaga antes) y que la vibración suave del final se sienta con
      la pantalla apagada. En el simulador solo se probó el de 30 s.
- [ ] **Umbrales del predictor de fatiga** (30 min, 3 episodios, 1 s de tendencia, nivel 3):
      salen de criterio, no de datos. Revisarlos con guardias reales
      ([DETECTOR.md](DETECTOR.md) §8.6).
- [ ] **Hora del historial**: se guarda `Time.now()` al iniciar la guardia (segundos Unix) y
      se muestra en la hora local actual del reloj. Comprobar en el reloj que cambia bien
      tras un cambio de zona horaria o de horario de verano.

## 4. Compilación y memoria

- [ ] **Batería de la animación (fase 12):** medir en el reloj real el consumo de una guardia
      larga con el orbe a ≈12 cuadros/s frente a `ANIMATIONS_ENABLED = false` (1 cuadro/s),
      además del de grabar la actividad (25 Hz + FIT). Según el resultado, bajar la tasa con
      la pantalla atenuada, apagar la animación tras unos minutos sin mirar el reloj o
      hacer que "Animaciones reducidas" (fase 11) también baje la tasa.
- [ ] Tiempo de dibujo **en el reloj real**: el simulador corre en el PC y no refleja la CPU
      del fr165. Si un cuadro supera unos 60 ms, reducir `OrbModel.POINTS` (36 → 24) o la
      tasa, o dibujar la capa fija (pista del anillo, partículas en pausa) en un
      `BufferedBitmap`.
- [ ] Comprobar en el reloj si `setStroke`/`setFill` (alfa real) existen en el firmware; si
      sí, valorar usarlos con un `has` en lugar de la mezcla precalculada.
- [ ] Comprobar **en el reloj**, con la app instalada desde el `.iq`, que mantener UP abre el
      menú principal **sin** la entrada *Depuración*. En el simulador ya se vio con
      `run.ps1 -Release` (mismo `-r` que el `.iq`).
- [ ] `ClassifierWeightsV1` (24 `Float`, solo referencia) y las auxiliares sin `(:test)` de
      `FeatureMatchTest.mc`/`StateClassifierTest.mc` (`flattenRows`, `foldV1Weights`,
      `FEATURE_TOLERANCE`) entran también en release. Los vectores de prueba grandes
      (`FeatureVectors`, `ModelVectors`) son clases `(:test)` y no entran.
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

- [ ] `AppInfo.VERSION` ("0.11.0", visible en *Acerca de*) debe coincidir con la versión que
      se escriba al subir el paquete: el manifest de Connect IQ no lleva versión.

- [ ] Ver el ícono de 54×54 en el menú de apps del simulador y del reloj: que el pulso se
      lea a tamaño real.
- [ ] Revisar los requisitos actuales de la Connect IQ Store: ícono, capturas y descripción
      en español e inglés.
