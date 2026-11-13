# Arquitectura — FocusPulse AI

Documento vivo. Describe los módulos previstos y el plan por fases. Lo marcado como
*propuesta* puede cambiar al validarlo con el SDK y el dispositivo real.

## Principios

1. **Núcleo puro y testeable.** `source/core` contiene toda la lógica de detección y
   escalado de alertas. No importa `Toybox.WatchUi`, `Toybox.Graphics`, `Toybox.Sensor` ni
   `Toybox.Attention`: recibe muestras como números y devuelve decisiones. Así se prueba con
   `Toybox.Test` y el modo demo usa exactamente el mismo código que el modo real.
2. **Hardware detrás de adaptadores.** Sensores y vibración se envuelven en clases pequeñas
   fuera de `core` (carpeta `source/platform/`, aceptada para la fase 3), que traducen entre
   `Toybox` y los tipos simples del núcleo.
3. **UI delgada.** Vistas y delegados solo leen estado y envían órdenes; no calculan nada.
4. **AMOLED primero.** Fondo `0x07090C`, poca superficie encendida, sin animaciones
   continuas innecesarias (batería y quemado de píxeles).

## Flujo de datos

Implementado en la fase 3 (fuentes → motor → snapshot). Lo que va después del snapshot
(detector, alertas) llega en las fases 5 y 6.

```
   source/platform                         source/core
 ┌──────────────────────┐
 │ RealAccelSource      │  Sensor.registerSensorDataListener
 │ 25 Hz, lotes de 1 s  │  solo acelerómetro, mg ──┐
 └──────────────────────┘                         │  callback de lote
 ┌──────────────────────┐                         │  (xs, ys, zs, timestampMs)
 │ SimulatedAccelSource │  Timer 1 s, 25 muestras ─┤
 │ normal · tecleo ·    │  mismo formato           │
 │ cabeceo · inactividad│                          ▼
 │ · manual             │                 ┌─────────────────┐
 └──────────────────────┘                 │ TelemetryEngine │ reparte el tiempo por
            ▲                             │                 │ muestra, mide los Hz
            │ start / stop                └────────┬────────┘ efectivos y el pico
 ┌──────────┴───────────┐                          │ push(x, y, z, t)    del lote
 │ GuardController      │                          ▼
 │ (source/app)         │                 ┌─────────────────┐
 │ MonitorState         │                 │  SlidingWindow  │ 2 s = 50 muestras:
 │ + SessionRecorder    │◀── snapshot() ──│  + RingBuffer   │ media y varianza de la
 │ (ActivityRecording)  │                 └────────┬────────┘ magnitud (incremental),
 └──────────┬───────────┘                          │          sacudida, quietud
            │                                      ▼
            ▼                            ┌───────────────────┐
   MainView / TelemetryDebugView         │ TelemetrySnapshot │ x, y, z, varianza,
   (source/views)                        └─────────┬─────────┘ sacudida, quietud, Hz…
                                                   ▼
                                     NodDetector → AlertEscalator → Haptics / vistas
                                               (fases 5–7)
```

- **Las dos fuentes entregan el mismo lote**: arreglos `x`, `y`, `z` en mili‑g y la marca
  de tiempo (ms) de la última muestra. El motor no sabe de dónde vienen, así que el modo
  demo usa exactamente el mismo código que el sensor real.
- **El tiempo entra como parámetro** (`System.getTimer()` en la app, valores fijos en las
  pruebas): el núcleo no lee el reloj.
- `GuardController` arranca la fuente al iniciar la guardia y, si el ajuste
  `recordActivity` está activo (por defecto), la grabación. Al pausar o salir detiene
  ambas y guarda la actividad.

### Características de la ventana (fase 3)

| Característica | Definición | Constante |
|---|---|---|
| Media y varianza | De la magnitud √(x²+y²+z²) en mg enteros. La suma y la suma de cuadrados van en `Long`, así que sumar la muestra nueva y restar la que sale es exacto, sin deriva. | `WINDOW_SAMPLES = 50` (2 s × 25 Hz) |
| Sacudida | Mayor módulo de Δ vectorial entre muestras consecutivas dentro de las 10 últimas. El snapshot añade el pico del último lote, para no perder un pico del principio del lote de 25. | `JERK_SAMPLES = 10` |
| Quietud | Segundos seguidos con la ventana llena y varianza < umbral. Empieza a contar cuando toda la ventana está quieta (≈2 s de retraso). | `STILL_VARIANCE_MAX = 100 mg²` (σ = 10 mg) |
| Hz efectivos | Muestras recibidas después del primer lote / tiempo desde él. | — |

**Limitaciones conocidas:**

- La varianza de la **magnitud** no ve los giros puros: si la muñeca rota sin acelerar, la
  magnitud sigue en ≈1 g y la varianza no cambia. Lo detecta la sacudida, y la inclinación
  respecto a la gravedad (fase 4) cubrirá los cambios de postura.
- El tecleo también da sacudidas de más de 400 mg. El detector de la fase 5 no puede usar
  la sacudida sola, sino **sacudida seguida de quietud**.

### Firmas de los escenarios simulados

Medidas con `tests/SimulatedAccelSourceTest.mc` y en la telemetría en vivo del simulador:

| Escenario | Señal (mg) | Varianza | Sacudida | Quietud |
|---|---|---|---|---|
| Normal | (40, −180, 975) ± 70 | ≈ 2 100 mg² | ≈ 160–190 | no |
| Tecleo | X/Y ± 250, Z 960 ± 220 | ≈ 17 000–19 000 mg² | 450–650 | no |
| Inactividad | (22, −18, 996) ± 4 | ≈ 5–7 mg² | < 15 | sí, desde los 2 s |
| Cabeceo | 3 s de movimiento normal en (0, 0, 980); caída de 12 muestras (≈0,5 s, con un tramo brusco de 5) hasta (−240, −940, 240); reposo ± 4 | alta → ≈ 6 mg² | pico ≈ 466 en la caída | sí, ≈2 s después |
| Manual | X/Y/Z fijos (por defecto 0, 0, 1000) ± 4 | ≈ 5 mg² | < 15 | sí |

El ruido sale de un generador congruencial con semilla (no de `Math.rand`), así que las
pruebas son reproducibles.

## Módulos

| Carpeta | Módulo | Responsabilidad | Fase |
|---|---|---|---|
| `source/app` | `FocusPulseApp` | Punto de entrada, ciclo de vida, cableado de dependencias. | 1 ✅ |
| `source/util` | `Palette` | Tokens de color (constantes). | 1 ✅, 2 ✅ |
| `source/core` | `MonitorState` | Estado de sesión (activo / en pausa). | 1 ✅ |
| `source/views` | `MainView`, `MainDelegate` | Pantalla inicial; START/STOP y toque alternan el monitoreo. | 1 ✅ |
| `source/core` | `AlertnessColors` | Banda y color según el puntaje de alerta, colores del orbe IA y de la alerta por nivel. | 2 ✅ |
| `source/util` | `Typography`, `RoundLayout`, `Rect` | Roles tipográficos, geometría de la pantalla redonda y áreas táctiles. | 2 ✅ |
| `source/util` | `Draw` | Texto centrado, anillo de progreso, píldora, botón grande, indicador de página. | 2 ✅ |
| `source/views` | `StyleGuideView`, `StyleGuideDelegate` | Guía de estilo oculta, solo en depuración (`(:debug)`). | 2 ✅ |
| `source/core` | `RingBuffer` | Búfer circular de tamaño fijo: x, y, z (mg) y magnitud. | 3 ✅ |
| `source/core` | `SlidingWindow` | Ventana de 2 s: media y varianza incrementales de la magnitud, sacudida, segundos de quietud. | 3 ✅ |
| `source/core` | `TelemetryEngine`, `TelemetrySnapshot` | Recibe lotes con marca de tiempo, alimenta la ventana, mide los Hz efectivos y expone el snapshot. | 3 ✅ |
| `source/platform` | `AccelSource` | Interfaz común de las fuentes (`start`, `stop`, callback de lote). | 3 ✅ |
| `source/platform` | `RealAccelSource` | `Sensor.registerSensorDataListener`, solo acelerómetro, 25 Hz, lotes de 1 s. Si el sensor falta, `start()` devuelve `false`. | 3 ✅ |
| `source/platform` | `SimulatedAccelSource` | Escenarios del modo demo (normal, tecleo, cabeceo, inactividad, manual) con el mismo formato de lote. | 3 ✅ |
| `source/platform` | `SessionRecorder` | `ActivityRecording` (`SPORT_GENERIC`): crear, iniciar, detener, guardar o descartar. Permiso `Fit`. | 3 ✅ |
| `source/app` | `GuardController`, `AppSettings` | Inicia y pausa la guardia: fuente + grabación según el ajuste `recordActivity`. | 3 ✅ |
| `source/views` | `DebugMenu`, `TelemetryDebugView` | Menú de depuración (`(:debug)`): telemetría en vivo, selector de fuente y escenario, guía de estilo. | 3 ✅ |
| `resources/settings` | `recordActivity` | "Grabar guardia como actividad" (activado por defecto), editable desde Garmin Connect. | 3 ✅ |
| `source/core` | `FeatureExtractor` | Inclinación respecto a la gravedad y caída brusca, sobre la ventana de la fase 3. | 4 |
| `source/core` | `NodDetector` | Máquina de estados heurística: postura estable → caída de cabeza/muñeca → inmovilidad. Calibración inicial por usuario. | 5 |
| `source/core` | `AlertEscalator` | Decide el nivel de alerta (1 suave → 3 intenso) y cuándo reiniciar. | 6 |
| `source/platform` | `Haptics` | `Attention.vibrate` con `VibeProfile` según el nivel. | 6 |
| `source/views` | `MonitorView`, `AlertView` | Monitoreo en curso y alerta a pantalla completa que exige confirmación. | 7 |
| `source/views` | Modo demo | Pantalla del modo demo sobre `SimulatedAccelSource`; sustituye al selector de depuración. | 8 |
| `resources/settings` | `properties.xml`, `settings.xml` | Sensibilidad, intensidad de vibración, modo demo (junto a `recordActivity`). | 9 |
| `source/core` | `SessionStats` | Resumen de sesión (duración, eventos) e historial en `Application.Storage`. | 10 |
| `ml/` + `source/core` | `ModelWeights`, `ModelDetector` | Captura de datos, entrenamiento en Python, exportación de parámetros a Monkey C. | 11 |

`source/platform/` es la carpeta de adaptadores de hardware (sensores, grabación,
vibración), creada en la fase 3. Igual que las vistas, puede importar `Toybox.Sensor`,
`Toybox.ActivityRecording`, `Toybox.Timer` y `Toybox.Attention`; `core` nunca importa nada
de `platform`. `SimulatedAccelSource` vive aquí porque usa `Timer`, pero su generador
(`nextBatch`) no depende del temporizador y se prueba con `Toybox.Test`.

`AlertnessColors` vive en `core` porque es lógica pura (puntaje → color) y se prueba con
`Toybox.Test`. Solo depende de `Palette`, que es un módulo de constantes sin imports.
El sistema de diseño completo está en [DISENO.md](DISENO.md).

## Restricciones del dispositivo

Confirmadas con el SDK 9.3.0 (detalle en [PENDIENTES.md](PENDIENTES.md)). Afectan al diseño de
los módulos de las fases siguientes:

| Restricción | Consecuencia |
|---|---|
| Acelerómetro hasta 100 Hz, lotes de hasta 4 s, valores en mili‑g. **Sin giroscopio.** | `RealAccelSource` pide 25 Hz (menos batería que 100 Hz) y solo baja si `getMaxSampleRateForSensorType(:accelerometer)` da menos; si da 0, la fuente no está disponible. `FeatureExtractor` solo usa el acelerómetro: la inclinación sale de la gravedad, no de la velocidad angular. |
| Los Forerunner **ignoran el `dutyCycle`** de `VibeProfile`: la vibración siempre tiene la misma fuerza. Hay de 1 a 8 perfiles por llamada. | `Haptics` distingue los niveles 1–3 por duración, número de pulsos y pausas, no por intensidad. El ajuste "intensidad de vibración" de la fase 9 cambia el patrón, no la fuerza. |
| Si la app pasa a **inactiva** sin grabar una actividad, los sensores bajan a 10 Hz o fallan y la vibración queda denegada. | **Decidido en la fase 3:** la guardia graba una actividad (`SessionRecorder`, permiso `Fit`) por defecto, y el ajuste `recordActivity` lo desactiva. `TelemetryEngine` mide los Hz efectivos para detectar la bajada a 10 Hz. |
| El simulador 9.3.0 **se cierra con un error** si la app termina con una sesión de `ActivityRecording` todavía grabando, aunque `onStop` la guarde. | `MainDelegate.onBack` detiene y guarda la guardia antes de que la app empiece a cerrarse; `onStop` lo repite como respaldo. |
| fr165 y fr165m comparten pantalla, teclas, sensores y API 5.2.0. | Un solo código para ambos productos; `scripts\build.ps1` compila para `fr165` y `export.ps1` para los dos. |

## Plan por fases

| Fase | Objetivo |
|---|---|
| 1 | Scaffolding: manifest, jungle, estructura, vista inicial, delegado, scripts, docs. |
| 2 | Sistema de diseño: paleta, tipografía, layout redondo, utilidades de dibujo, textos es/en, ícono y guía de estilo. |
| 3 | Telemetría del acelerómetro (real + simulada), ventana de características y grabación de la guardia. ✅ |
| 4 | Extracción de características por ventana. |
| 5 | Detector heurístico de cabeceos/micro-sueño con calibración. |
| 6 | Alertas con vibración progresiva. |
| 7 | Interfaz de monitoreo y pantalla de alerta. |
| 8 | Modo demo interno para simular eventos. |
| 9 | Ajustes de usuario (sensibilidad, intensidad). |
| 10 | Resumen de sesión e historial. |
| 11 | Captura de datos, entrenamiento del modelo en `/ml` y detector basado en modelo. |
| 12 | Rendimiento, memoria, batería y pruebas en dispositivo real. |
| 13 | Preparación para la Connect IQ Store: íconos finales, capturas, textos de tienda es/en, export. |

La fase 2 se insertó como sistema de diseño, así que las fases siguientes se corrieron un
número respecto al plan inicial.

## Pruebas

- Pruebas unitarias en `tests/` con funciones anotadas `(:test)`; se ejecutan con
  `scripts\test.ps1`.
- Todo módulo de `core` debe tener pruebas. Las fuentes de muestras sintéticas del modo
  demo se reutilizan como datos de prueba del detector.
- Fase 3: 42 pruebas en total; las nuevas cubren `RingBuffer`, `SlidingWindow`,
  `TelemetryEngine` y la firma de cada escenario de `SimulatedAccelSource`.
