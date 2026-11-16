# Pendientes de verificar

Las fases 1 y 2 se compilaron, probaron y revisaron en el simulador con el **Connect IQ SDK
9.3.0** (2026-11-12), las fases 3 a 8 el 2026-11-13, las fases 9, 10 y 11 el 2026-11-14,
la fase 12 (versión 1.0.0) el 2026-11-15 y la fase 13B (versión 1.1.0, animaciones del
diseño web) también el 2026-11-15.

El documento tiene tres partes:

1. **Datos confirmados**: lo que se comprobó con el SDK y el simulador.
2. **Requiere reloj real**: lo que solo se puede cerrar con un Forerunner 165 en la muñeca.
3. **Trabajo futuro**: mejoras y tareas que no bloquean la 1.0 (datos reales, publicación).

Al cerrar un punto, muévelo a la sección de datos confirmados o bórralo, y corrige el
código si algo no coincide.

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
- Con el **menú principal abierto**, una alerta del detector se apilaba encima y al
  responderla se volvía al menú. **Resuelto en la fase 12**: la alerta cierra los menús
  (`ViewUnwinder`).

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

### Pulido final y versión 1.0.0 (fase 12, simulador)

- Las **205 pruebas** pasan (11 nuevas: 6 de `SensorWatchdog` y del detector tras un corte,
  3 de `PixelShift`/`RoundLayout.shiftTo` y 2 de contraste). `build.ps1`, `build.ps1
  -Release` y `export.ps1` (fr165 y fr165m) sin advertencias con `-l 3`. Release:
  `FocusPulse-release.prg` 86,9 kB (88,6 antes de sacar de release los auxiliares de
  pruebas y los pesos v1); `bin\FocusPulse.iq` **198,6 kB**, versión 1.0.0.
- Todo sin usar el ratón ni el teclado reales: botones y toques con `PostMessage`, menús
  del simulador con `WM_COMMAND`, capturas con `PrintWindow` y un cambio **temporal y no
  versionado** para que DOWN abriera el menú (mantener UP no funciona por mensajes).
- **Sin datos del sensor**: con el sensor real del simulador (no entrega lotes), la píldora
  pasa a "Sin datos del sensor" a los 5,08 s y la consola de depuración lo registra. Con
  un corte temporal de 8 s cada 30 s en la fuente simulada (cambio no versionado): aviso a
  los 5,06 s del corte, se quita solo con el primer lote y, en inactividad, la siguiente
  alerta llega 7,1 s después del regreso (no en el acto). Con la fatiga en Alto, el aviso
  de sin datos se ve en lugar del de fatiga.
- **Alerta sobre menús**: `popView` **no cambia `WatchUi.getCurrentView()` hasta el
  siguiente ciclo de eventos** (traza: tras un `popView`, `getCurrentView` devolvía el
  mismo objeto), así que no se pueden cerrar los menús en un bucle. `ViewUnwinder` cierra
  una vista cada 50 ms. Verificado con "Probar alerta" (2 vistas), Ajustes → Sensibilidad
  (3), Historial → detalle (3), Modelo IA (2) y Escenario (2): consola "ALERTA cierra N
  vistas", alerta sobre la esfera y, al responder, la esfera.
- **Límite de 3 timers** (doc del SDK: "default 3"): la primera versión tumbó la app con
  *Too Many Timers Error* (fuente simulada + esfera + `ViewUnwinder` + vibración). La
  vibración empieza ahora en el primer cuadro de la alerta, cuando la esfera ya paró su
  timer.
- **Anti quemado**: en capturas de minutos seguidos la batería se movió (0,0) → (2,0) →
  (2,2) px, la secuencia de `PixelShift`.
- **Textos**: todas las pantallas revisadas a 390×390 en español e inglés (capturas en
  `docs/img/`). En inglés se acortaron "Glance at watch", "Long inactivity" y "max
  vibration". Contraste mínimo de los textos importantes: 6,51:1.
- **Alerta en el fr165m**: vista en el simulador del 165 Music (nivel 3, inglés), igual que
  en el fr165.
- **Memoria pico** (*File > View Memory* del simulador, compilación de release, recorrido
  completo: guardia, alertas 1–3, menús, ajustes, historial, resumen): **98,8 kB de
  763,6 kB** en el fr165 y **98,8 kB de 763,6 kB** en el fr165m (13 %). Código 47,5 kB,
  datos 17,8 kB. En depuración la memoria en uso ronda 104–105 kB.

### Animaciones del diseño web (fase 13B, versión 1.1.0, simulador)

- Las **226 pruebas** pasan (21 nuevas: contornos de Bézier, fotogramas clave, ciclo y
  opacidad por estado, titileo de las partículas, `GuardVisuals`, `ButtonFocus`, colores,
  pulso, parpadeo y ondas de la alerta). `build.ps1` y `build.ps1 -Release` sin
  advertencias con `-l 3`.
- **Tiempo de dibujo por cuadro** (compilación de depuración, `FrameStats` en ventanas de
  5 s, fr165, contornos de 48 puntos):

  | Estado | Cuadros/s | Dibujo medio (máx.) |
  |---|---|---|
  | Pausa | 1,2–1,4 | 2,5–8,0 ms (16) |
  | Normal | 12,2–13,4 | 3,2–6,8 ms (16) |
  | Activo (tecleo) | 12,2–13,2 | 3,0–6,7 ms (16) |
  | Somnoliento (inactividad) | 13,0–13,2 | 3,8–4,3 ms (16) |
  | Alerta, niveles 1–3 | 14,7–15,5 | 0,8–2,1 ms (16) |

  El máximo de 16 ms es la resolución de `System.getTimer()` en Windows, no un cuadro lento.
  Muy por debajo de los ≈ 40 ms que obligarían a bajar los puntos por contorno: se quedan
  en 48. Las fases avanzan como se espera: en activo, A sube ≈ 0,14 por ventana de 5,1 s
  (ciclo de 4,5 s) y en normal ≈ 0,57 (ciclo de 9 s).
- **`setPenWidth` y `fillCircle` aceptan `Float`** (`Numeric` en `api.mir`) y el simulador
  los dibuja sin errores: los contornos usan 2,5 / 2 / 2 px y las partículas radios de 2,2 y
  1,6 px tal cual. Los puntos de los contornos también se pasan como `Float` a `drawLine`.
- **Contraste de los colores del diseño web** (WCAG 2.x): nivel 1 #FF8A1F con negro 8,91:1
  → 4,83:1 al 0,72; nivel 3 #E01E1E con blanco 4,80:1 y #6A0000 13,02:1. **Nivel 2:
  #FF5A1F con negro 6,73:1, pero al 0,72 del pulso baja a 3,81:1**, así que se conservó la
  profundidad que ya tenía la app (0,88 → 5,30:1); prueba `alertPulseDimsTowardsBlack`.
- **Nivel 3 gradual**: las referencias `alerta-nivel3.png` y `alerta-nivel3-prueba.png`
  muestran rojos intermedios (≈ #A00A0A), así que el parpadeo cada 0,5 s es un paso gradual
  #E01E1E → #6A0000 → #E01E1E (1 ciclo/s), no un corte. En el simulador se capturaron
  205,24,24 → 156,12,8 → 106,0,0 → 164,12,8 → 213,24,24 (pantalla de 16 bits).
- **Foco del botón**: START, un toque en el botón, UP o DOWN dan el foco durante 1,5 s y se
  ve el borde cian de 2 px (capturas antes, a los 250 ms y a los 2,8 s).
- **Comparaciones** con el diseño web, en release y en español:
  [img/comparacion-guardia.png](img/comparacion-guardia.png) y
  [img/comparacion-alertas.png](img/comparacion-alertas.png). Tras la primera comparación se
  bajó el bloque de la alerta (ícono de radio 30 en y 76, título en `FONT_MEDIUM` en y 134).
- **Guion automático completo (release)**, sin usar el ratón ni el teclado reales (botones
  con `PostMessage`, idioma y *Kill App* con `WM_COMMAND`, capturas con `PrintWindow` y el
  cambio **temporal y no versionado** para que DOWN en pausa abra el menú):
  - **Español**: cabeceo a los 28 s (paso 3, respondida), inactividad a los 47 s (paso 5,
    respondida), paso 6 sin responder: nivel 2, nivel 3 y resumen automático a los 74 s
    (1 min 14 s, 3 episodios, respuesta media 2,3 s, nivel máximo 3 de 3, fatiga Alto, DEMO).
  - **Inglés**: alertas a los 30 y 49 s, la tercera a los 58 s y resumen a los 75 s
    (1 min 15 s, 3 episodes, avg. response 2.7 s, max. level 3 of 3, fatigue High).
  - Todas las pantallas del recorrido se ven sin cortes en los dos idiomas con el orbe, el
    arco, el ping, los dos puntos que parpadean y las alertas nuevas.
- Durante el primer intento en español la ventana del simulador quedó **minimizada** unos
  30 s y `PrintWindow` devolvió capturas vacías: la alerta del paso 5 escaló sin respuesta.
  El ayudante de capturas restaura la ventana sin activarla (`ShowWindow`
  `SW_SHOWNOACTIVATE`) y el recorrido se repitió entero.

#### Lo que no se pudo igualar al diseño web

- **Tipografía**: el reloj solo tiene las fuentes del sistema (Roboto en el simulador, sin
  negrita). La hora, "¡DESPIERTA!", "Pausar guardia" y "Estoy despierto" son negritas
  geométricas en la web; aquí van en regular. Igualarlas exigiría fuentes de mapa de bits
  propias (más memoria y trabajo de diseño).
- **Tamaño de los textos de la alerta**: no hay fuente más pequeña que `FONT_XTINY`
  (30 px de caja), así que "Nivel 1 de 3 · vibración suave" y sobre todo el motivo ocupan
  más que en la web; "Cabeceo / pérdida de tono muscular" va en dos líneas y el bloque queda
  algo más alto y apretado que en la referencia.
- **Esfera**: con el modo demo la fecha se reemplaza por la línea "DEMO · …"; la batería y
  el puntaje llevan espacio antes de "%" ("50 %", formato del idioma); la píldora usa el
  fondo `SURFACE` con borde `BORDER_STRONG` y no el fondo cian tenue de la web.
- **Opacidad**: no hay alfa real en el fr165; toda transparencia (orbe, partículas, arco,
  ping, dos puntos, ondas, pulso) se simula mezclando con el fondo o con negro. Donde un
  elemento con "transparencia" pasa por encima de otro (p. ej. una partícula detrás del
  botón) se ve el color mezclado con el fondo, no con lo que hay debajo.
- **Pulso del nivel 2**: 0,88 en lugar de 0,72 (contraste, arriba).
- **Pantalla de 16 bits**: el simulador redondea los colores (p. ej. #FF8A1F se ve
  255,137,24), así que los degradados del pulso van en escalones pequeños.
- **Foco**: en la web es el foco de teclado o del puntero; en el reloj no hay foco en las
  vistas propias, así que se simula 1,5 s tras START, un toque, UP o DOWN.

## Requiere reloj real

Solo se puede cerrar con un Forerunner 165 (o 165 Music) en la muñeca.

### Sensores y ciclo de vida

- [ ] **Orientación de los ejes** x/y/z con el reloj en la muñeca izquierda y en la derecha
      (telemetría en vivo del menú de depuración). Los escenarios suponen Z ≈ +1 g con la
      esfera hacia arriba y el brazo colgando en (−240, −940, 240); si los signos no
      coinciden, corregir `SimulatedAccelSource` y luego el detector.
- [ ] **Pantalla apagada mientras graba**: que la guardia siga recibiendo lotes a 25 Hz y
      pueda vibrar con la pantalla AMOLED apagada o atenuada. Si el sistema corta los
      lotes, la esfera mostrará "Sin datos del sensor" al encenderla.
- [ ] **App inactiva grabando** (selector de tareas): sigue a 25 Hz gracias a la actividad;
      con *Grabar actividad* apagado baja a ≤ 10 Hz.
- [ ] **Actividad en Garmin Connect**: que aparezca como "Otro" con el nombre "Guardia
      focus" / "Focus guard" y si cuenta para carga de entrenamiento o Body Battery.
- [ ] **Cierre por el sistema con la guardia activa** (batería, otra app, apagado): solo
      corre `onStop`; comprobar que la actividad se guarda y que una alerta abierta deja de
      vibrar.
- [ ] **Ruido del acelerómetro en reposo**: el umbral adaptativo no baja de 25 mg² (σ = 5
      mg); si el ruido real de un brazo inerte lo supera, la quietud nunca llegaría.
- [ ] **Sin datos del sensor**: en qué situaciones reales deja de haber lotes más de 5 s
      (pantalla apagada, app en segundo plano, sensor ocupado) y si el aviso aparece.
- [ ] Desde dónde se lanza la app (menú de apps o glance): las abiertas desde glances se
      cierran solas por tiempo.

### Vibración, luz y sonido

- [ ] **Sentir los tres niveles** sin mirar la pantalla (2×150 ms cada 3 s, 3×300 ms cada
      2 s, 800/200 ms casi continuo) y que el nivel 1 despierte.
- [ ] Que los tramos con `dutyCycle` 0 sean **pausas** (los Forerunner ignoran el
      `dutyCycle`): si vibran, lanzar cada pulso con su propio `Timer` (ojo: límite de 3).
- [ ] Que `stop()` corte la ráfaga en curso (`VibeProfile(0, 10)`).
- [ ] Ajuste *Vibración*: que Suave, Normal y Fuerte se distingan y que Suave nivel 1 (un
      pulso de 150 ms cada 3 s) todavía despierte; si no, subir Suave a 2 pulsos.
- [ ] **Luz con protección contra quemado**: `Attention.backlight(true)` puede lanzar
      `BacklightOnTooLongException` tras ≈ 1 min de alerta; se atrapa. Ver que la alerta
      sigue visible.
- [ ] **Tono**: si suena, a qué volumen y si el `ToneProfile` con silencios de 0 Hz se
      acepta (si no, `Haptics` usa `TONE_ALERT_HI`).
- [ ] Desfase entre la sacudida de la vista y el motor en alertas largas (decenas de ms
      esperables; ahora la vibración arranca ≈ 50 ms después del primer cuadro).

### Interfaz y entrada

- [ ] **Mantener UP** abre el menú principal sin *Depuración* con la app instalada desde el
      `.iq`; DOWN durante la guardia cambia de escenario en modo demo; el modo demo se
      recuerda tras reiniciar el reloj.
- [ ] **Deslizar en la esfera**: un deslizamiento vertical podría llegar como
      `onNextPage` y cambiar de escenario en modo demo; si molesta, atender solo `KEY_DOWN`.
- [ ] Acertar el botón de la esfera (área 242×82 px) y el de la alerta (280×86 px) con el
      reloj puesto y medio dormido; que la píldora no provoque toques no deseados.
- [ ] **Alerta sobre menús en el reloj**: que `ViewUnwinder` cierre los menús nativos igual
      que en el simulador y que el límite de timers del fr165 sea el mismo (3).
- [ ] **Anti quemado**: que el salto de 2 px por minuto no se note al mirar la hora.
- [ ] Fuentes: que `FONT_NUMBER_MEDIUM` (hora), "¡DESPIERTA!" en `FONT_MEDIUM` y las
      etiquetas cortas de *Ajustes* (Menu2 corta a ≈ 13 caracteres junto al interruptor) se
      vean igual que en el simulador (que usa Roboto).
- [ ] "Nivel 3 de 3 · vibración máxima" (≈ 357 px) no queda demasiado cerca del borde.
- [ ] Aviso de fatiga ("descansa 15 min") legible con brillo bajo y en el sitio previsto.
- [ ] **Descanso de 15 min**: que la vista no se cierre sola y que la vibración del final
      se sienta con la pantalla apagada (en el simulador solo se probó el de 30 s).
- [ ] **Hora del historial** tras un cambio de zona horaria o de horario de verano.
- [ ] Brillo bajo y sol: que el arco de escaneo (3 px, cian al 55 %), el orbe tenue y la
      pista `BORDER` se distingan sin restar legibilidad, y que `ORANGE`, `ORANGE_DEEP` y
      `RED_INTENSE` se distingan entre sí (desde la 1.1.0 `ORANGE_DEEP` es #FF5A1F, más
      cerca del rojo).
- [ ] **Orbe del diseño web en AMOLED**: que los contornos de 2–2,5 px con opacidad 0,35–0,6
      y las partículas de 1,6–2,2 px se vean (o no molesten) con brillo bajo, y que el
      parpadeo de los dos puntos de la hora no distraiga.
- [ ] **Grosores y radios con decimales** (`setPenWidth(2,5)`, `fillCircle` de 2,2 y 1,6
      px, `drawLine` con `Float`): el simulador los acepta; confirmar que el firmware del
      fr165 también, y cómo los redondea.
- [ ] **UP y DOWN en la esfera** enfocan el botón (borde cian 1,5 s): que UP no tenga en el
      reloj otro uso del sistema que el usuario eche de menos.

### Rendimiento y batería

- [ ] **Batería** de una guardia larga con el orbe a ≈ 12 cuadros/s (desde la 1.1.0, 3
      contornos de 48 puntos, 16 partículas, arco y ping) frente a
      `ANIMATIONS_ENABLED = false` (1 cuadro/s), más la grabación (25 Hz + FIT). Según el
      resultado: bajar la tasa con la pantalla atenuada, apagar la animación tras unos
      minutos sin mirar o hacer que "Animaciones reducidas" también baje la tasa.
- [ ] **Tiempo de dibujo** en la CPU del fr165 (en el simulador, 3–7 ms por cuadro de la
      esfera y 1–2 ms de la alerta): si un cuadro supera ≈ 40 ms, bajar
      `OrbModel.SEGMENT_POINTS` (12 → 8, 32 puntos por contorno) o la tasa, o usar un
      `BufferedBitmap` para la capa fija.
- [ ] **Memoria en el reloj** frente a los 98,8 kB medidos en el simulador.
- [ ] Si `setStroke`/`setFill` (alfa real) existen en el firmware (en el simulador no): si
      sí, valorar usarlos con un `has`.

## Trabajo futuro

No necesita el reloj para empezar, o es una mejora que no bloquea la 1.0.

### Datos reales y modelo

- [ ] **Grabar datos de muñeca reales** con `SensorLogging` y etiquetas (vídeo o pulsador),
      importarlos con `ml/import_real.py` y reentrenar: los pesos v2 y los umbrales del
      detector (400 mg, 35°, 50 mg de calma, piso de 25 mg²) salen de datos sintéticos.
- [ ] **Leer el FIT de `SensorLogging`** en `ml/import_real.py` (`load_fit`, hoy
      `NotImplementedError`) y añadir el FIT SDK de Garmin para Python a los requisitos.
- [ ] Reproducir ese FIT en el simulador (*Activity Data > FIT/GPX Playable File*) para
      probar el sensor real con datos de muñeca.
- [ ] **Confirmación por IA con datos reales**: revisar el retardo (2 lotes) y el umbral
      (p(Normal) < 0,35); si un brazo dormido real tarda más en parecer Inerte se perderían
      alertas de cabeceo (la inactividad las cubriría a los 60 s).
- [ ] **Sensibilidad Baja / Alta** (440/340 mg, 45/28°, ×1,5/×0,75): validar con datos reales.
- [ ] **Mirar la hora**: 12 de 48 episodios difíciles todavía tienen algún lote Cabeceo en
      v2; valorar características nuevas (dirección final de la gravedad).
- [ ] **Cabeceos lentos**: el detector solo ve el 61 % de los cabeceos sintéticos y v2 tiene
      un recall de Cabeceo de 0,48 (v1: 0,58). Entrenar la decisión del evento.
- [ ] **Umbrales del predictor de fatiga** (30 min, 3 episodios, 1 s de tendencia, nivel 3):
      salen de criterio; revisarlos con guardias reales.

### Interfaz

- [ ] Decidir si la hora necesita una fuente personalizada y si su costo en memoria cabe.
- [ ] Con el modo demo la esfera no muestra la fecha; valorar dónde ponerla.
- [ ] *Detector en vivo* (depuración) solo se revisó en español en el fr165.
- [ ] Forzar en el simulador la píldora "Sensor no disponible" y la batería baja en rojo
      (*Settings > Set Battery Status*), y ver la hora en 12 h con una hora que la distinga.
- [ ] Recuperar "toma un descanso de 15 min" completo en el aviso de fatiga (caja más alta o
      un ícono).
- [ ] Si se añade un producto sin `playTone`, usar un `settings.xml` por producto (hoy el
      ajuste *Sonido* se muestra siempre en Garmin Connect).
- [ ] Los textos `StyleGuide*`, `TypeRole*` y `Debug*` también se empaquetan en release (los
      recursos no admiten `(:debug)`); separarlos con rutas de recursos por compilación si
      la memoria lo pidiera (hoy sobra: 13 % de uso).

### Publicación y entorno

- [ ] **Copia de seguridad de la llave** `%USERPROFILE%\Downloads\FocusPulse-keys\` fuera
      del equipo: sin ella no se pueden publicar actualizaciones.
- [ ] El `id` de la app (`6600d3c23b8a4e89827e17ef16db01e8`) **no debe cambiar** después de
      publicar.
- [ ] Subir `bin\FocusPulse.iq` a la Connect IQ Store con la ficha de
      [STORE.md](STORE.md) (cuenta de desarrollador, versión **1.2.0** = `AppInfo.VERSION`) y
      revisar en el formulario los requisitos actuales de ícono, capturas y textos.
- [ ] Ver el ícono de 54×54 en el menú de apps del simulador y del reloj.
- [ ] **Editor de ajustes del simulador**: depende del nombre con que el simulador registró
      la app (FOCUSPULSE-TEST en este equipo); si tras *Reset All App Data* dice "No settings
      file found", volver a ejecutar `run.ps1`.
- [ ] Con el acelerómetro del simulador (*Activity Data*, vectores de 1 g al azar) el
      detector daría cabeceos continuos; para la sustentación, usar la fuente simulada.
