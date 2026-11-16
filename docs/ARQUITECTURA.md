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

Implementado en la fase 3 (fuentes → motor → snapshot) y la fase 6 (detector, línea base,
clasificador) y la fase 7 (alerta a pantalla completa con vibración). El algoritmo del
detector está explicado en [DETECTOR.md](DETECTOR.md) y la alerta en [DISENO.md](DISENO.md) §5.3.

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
                         DrowsinessDetector + Baseline (fase 6) → evento y estado
                                                   ▼
                         StateClassifier (fase 6; pesos v2 entrenados, fase 10) → p(Activo, Normal, Cabeceo, Inerte)
                                                   ▼
                         NodConfirmation (fase 11) → el CABECEO espera 2 s y abre la alerta solo si p(Normal) < 0,35
                                                   ▼
                         AlertnessScore → anillo y porcentaje · OrbModel → orbe
                         AlertController (fase 7) → AlertView + Haptics → AlertLog
                           escala 1 → 2 → 3 sin respuesta (fase 9)        │ episodios
                                                   ▼                         ▼
                         FatiguePredictor (fase 9) → aviso de fatiga → BreakView
                         al pausar: GuardSummary → SummaryView · SessionHistory → Storage
```

- **Las dos fuentes entregan el mismo lote**: arreglos `x`, `y`, `z` en mili‑g y la marca
  de tiempo (ms) de la última muestra. El motor no sabe de dónde vienen, así que el modo
  demo usa exactamente el mismo código que el sensor real.
- **El tiempo entra como parámetro** (`System.getTimer()` en la app, valores fijos en las
  pruebas): el núcleo no lee el reloj.
- **Sin datos del sensor (fase 12).** `SensorWatchdog` cuenta el tiempo desde el último
  lote; los timers de la esfera y de la alerta lo revisan. Pasados 5 s la píldora muestra
  "Sin datos del sensor" (ámbar) y el detector no recibe nada. Con el primer lote de vuelta,
  `GuardController.onSensorDataBack` vacía la ventana y el detector olvida la quietud, así
  que la inactividad vuelve a contar desde cero.
- **Alerta sobre menús (fase 12).** Si una alerta se abre con menús encima de la esfera,
  `ViewUnwinder` los cierra y luego se apila la alerta; al responder se vuelve a la esfera.
  El reloj admite **3 timers** a la vez (fuente simulada, vista y vibración), así que la
  vibración arranca en el primer cuadro de la alerta.
- `GuardController` arranca la fuente al iniciar la guardia y, si el ajuste
  `recordActivity` está activo (por defecto), la grabación. Al pausar o salir detiene
  ambas y guarda la actividad.
- **Ajustes (fase 11).** `AppSettings` (source/app) es el único que lee y escribe
  `Application.Properties`; devuelve un `Settings` (source/core) ya validado.
  `GuardController.applySettings` lo reparte: sensibilidad → `DrowsinessDetector`
  (`DetectorThresholds`), confirmación → `NodConfirmation`, vibración y sonido → `Haptics`;
  las vistas leen `settings()` (animaciones reducidas). Se aplica al abrir la app, al
  cambiar algo en *Ajustes* y en `onSettingsChanged` (Garmin Connect), sin reiniciar la
  guardia.

```
 Garmin Connect / editor del simulador ─┐        menú Ajustes (SettingsMenu)
              onSettingsChanged         │                 │ AppSettings.save
                                        ▼                 ▼
                          Application.Properties (properties.xml)
                                        │ AppSettings.load → Settings (core)
                                        ▼
                          GuardController.applySettings
          ┌──────────────────┬──────────────────┬───────────────────┬──────────────────┐
  DetectorThresholds   NodConfirmation    Haptics (vibración,     MainView / AlertView
  (sensibilidad)       (confirmación IA)  sonido)                 (animaciones reducidas)
```

### Características de la ventana (fase 3)

| Característica | Definición | Constante |
|---|---|---|
| Media y varianza | De la magnitud √(x²+y²+z²) en mg enteros. La suma y la suma de cuadrados van en `Long`, así que sumar la muestra nueva y restar la que sale es exacto, sin deriva. | `WINDOW_SAMPLES = 50` (2 s × 25 Hz) |
| Sacudida | Mayor módulo de Δ vectorial entre muestras consecutivas dentro de las 10 últimas. El snapshot añade el pico del último lote, para no perder un pico del principio del lote de 25. | `JERK_SAMPLES = 10` |
| Quietud | Segundos seguidos con la ventana llena y varianza < umbral. Empieza a contar cuando toda la ventana está quieta (≈2 s de retraso). El detector usa su propio umbral adaptativo (≤ 100 mg², fase 6). | `STILL_VARIANCE_MAX = 100 mg²` (σ = 10 mg) |
| Gravedad (fase 6) | Media de cada eje en la ventana, con sumas enteras exactas. El ángulo entre dos gravedades es el cambio de inclinación. | `Tilt.angleDegrees` |
| Hz efectivos | Muestras recibidas después del primer lote / tiempo desde él. | — |

**Limitaciones conocidas:**

- La varianza de la **magnitud** no ve los giros puros: si la muñeca rota sin acelerar, la
  magnitud sigue en ≈1 g y la varianza no cambia. Lo detecta la sacudida, y desde la fase 6
  la inclinación (gravedad media de la ventana, `Tilt`) cubre los cambios de postura.
- El tecleo también da sacudidas de más de 400 mg. Por eso el detector de la fase 6 no
  usa la sacudida sola, sino **sacudida seguida de quietud y cambio de inclinación**.

### Firmas de los escenarios simulados

Medidas con `tests/SimulatedAccelSourceTest.mc` y en la telemetría en vivo del simulador:

| Escenario | Señal (mg) | Varianza | Sacudida | Quietud |
|---|---|---|---|---|
| Normal | (40, −180, 975) ± 70, ruido triangular | ≈ 600–800 mg² | ≈ 70 | no |
| Tecleo | X/Y ± 250, Z 960 ± 220 | ≈ 17 000–19 000 mg² | 450–650 | no |
| Inactividad | (22, −18, 996) ± 4 | ≈ 5–7 mg² | < 15 | sí, desde los 2 s |
| Cabeceo | 3 s de movimiento normal en (0, 0, 980); caída de 12 muestras (≈0,5 s, con un tramo brusco de 5) hasta (−240, −940, 240); reposo ± 4 | alta → ≈ 6 mg² | pico ≈ 466 en la caída | sí, ≈2 s después |
| Manual | X/Y/Z fijos (por defecto 0, 0, 1000) ± 4 | ≈ 5 mg² | < 15 | sí |
| Mirar la hora (fase 10) | Ciclo de 12 s: 4 s normal, giro de 80° en 0,32 s (módulo constante + ±300 mg de subir el brazo), 6 s leyendo en (14, 930, 346) ± 16 triangular, bajada de 0,6 s | ≈ 600 → ≈ 43 mg² leyendo | 366 en el giro | sí al leer, con 80° de inclinación |

**Cambio de escenario (fase 11).** Con la fuente en marcha, `setScenario` desliza la
gravedad desde la postura actual (media móvil de las muestras) hasta la postura base del
escenario nuevo en `TRANSITION_SAMPLES` = 38 muestras (≈ 1,5 s), conservando su ruido. Sin
transición, pasar de cabeceo a inactividad era un salto de ≈ 1 200 mg y 75° que el detector
tomaba por otro cabeceo.

El ruido sale de un generador congruencial con semilla (no de `Math.rand`), así que las
pruebas son reproducibles.

## Módulos

| Carpeta | Módulo | Responsabilidad | Fase |
|---|---|---|---|
| `source/app` | `FocusPulseApp` | Punto de entrada, ciclo de vida, cableado de dependencias. | 1 ✅ |
| `source/util` | `Palette` | Tokens de color (constantes). | 1 ✅, 2 ✅ |
| `source/core` | `MonitorState` | Estado de sesión (activo / en pausa). | 1 ✅ |
| `source/views` | `MainView`, `MainDelegate` | Esfera principal: anillo de alerta, batería, hora, fecha (o línea del modo demo), puntaje, píldora de estado, botón de guardia con hit-testing y aviso breve. Anatomía en [DISENO.md](DISENO.md) §5.1. | 1 ✅, 4 ✅, 8 ✅ |
| `source/core` | `AlertnessScore` | Puntaje de alerta (0–100). Desde la fase 6 se acerca a la media de los niveles de cada clase pesada por las probabilidades del clasificador, a +3 / −2 puntos por segundo como mucho. | 4 ✅, 6 ✅ |
| `source/util` | `ClockFormat` | Hora en 24 h / 12 h y porcentaje de batería. | 4 ✅ |
| `source/core` | `AlertnessColors` | Banda y color según el puntaje de alerta, colores del orbe IA y de la alerta por nivel. | 2 ✅ |
| `source/util` | `Typography`, `RoundLayout`, `Rect` | Roles tipográficos (desde la fase 14, fuentes propias en mapa de bits cargadas una vez), geometría de la pantalla redonda y áreas táctiles. | 2, 14 ✅ |
| `source/util` | `Draw` | Texto centrado, anillo de progreso, píldora, botón grande, indicador de página. | 2 ✅ |
| `source/views` | `StyleGuideView`, `StyleGuideDelegate` | Guía de estilo oculta, solo en depuración (`(:debug)`). | 2 ✅ |
| `source/core` | `RingBuffer` | Búfer circular de tamaño fijo: x, y, z (mg) y magnitud. | 3 ✅ |
| `source/core` | `SlidingWindow` | Ventana de 2 s: media y varianza incrementales de la magnitud, sacudida, segundos de quietud. | 3 ✅ |
| `source/core` | `TelemetryEngine`, `TelemetrySnapshot` | Recibe lotes con marca de tiempo, alimenta la ventana, mide los Hz efectivos y expone el snapshot. | 3 ✅ |
| `source/platform` | `AccelSource` | Interfaz común de las fuentes (`start`, `stop`, callback de lote). | 3 ✅ |
| `source/platform` | `RealAccelSource` | `Sensor.registerSensorDataListener`, solo acelerómetro, 25 Hz, lotes de 1 s. Si el sensor falta, `start()` devuelve `false`. | 3 ✅ |
| `source/platform` | `SimulatedAccelSource` | Genera los escenarios (`AccelScenario`, en `core` desde la fase 8: normal, tecleo, cabeceo, inactividad, manual y, desde la fase 10, mirar la hora) con el mismo formato de lote. | 3 ✅, 10 ✅ |
| `source/platform` | `SessionRecorder` | `ActivityRecording` (`SPORT_GENERIC`): crear, iniciar, detener, guardar o descartar. Permiso `Fit`. | 3 ✅ |
| `source/app` | `GuardController`, `AppSettings` | Inicia y pausa la guardia: fuente + grabación según el ajuste `recordActivity`. | 3 ✅ |
| `source/views` | `DebugMenu`, `TelemetryDebugView` | Menú de depuración (`(:debug)`): telemetría en vivo, selector de fuente y escenario, guía de estilo. | 3 ✅ |
| `resources/settings` | `recordActivity` | "Grabar guardia como actividad" (activado por defecto), editable desde Garmin Connect. | 3 ✅ |
| `source/core` | `TrigTable` | Senos y cosenos precalculados con 1° de resolución. | 5 ✅ |
| `source/core` | `OrbModel`, `OrbState` | Orbe IA: 3 anillos orgánicos, 16 partículas, estado (pausa / normal / activo / somnoliento) y velocidad por estado. | 5 ✅ |
| `source/util` | `ColorMath`, `FrameStats` | Mezcla de colores con el fondo (transparencia simulada) y medición de cuadros por segundo y tiempo de dibujo. | 5 ✅ |
| `source/views` | `MainView` (orbe, arco, latido) | Dibujo animado a ≈12 cuadros/s con la guardia activa; ver [DISENO.md](DISENO.md) §5.2. | 5 ✅ |
| `source/core` | `Tilt` | Ángulo entre dos vectores de gravedad (media de cada eje en la ventana). | 6 ✅ |
| `source/core` | `DrowsinessDetector` | Eventos CABECEO (sacudida > 400 mg + quietud antes de 5 s + inclinación > 35°) e INACTIVIDAD (quietud ≥ 60 s, 8 s en demo), refractario de 10 s, estados calibrando / vigilando / caída detectada / evento. | 6 ✅ |
| `source/core` | `Baseline` | Línea base del usuario en ln(varianza + 1): calibración de 30 s (5 s demo), EMA lenta y umbral de quietud adaptativo. | 6 ✅ |
| `source/core` | `StateClassifier`, `ClassifierWeights` | Regresión logística multiclase (Activo, Normal, Cabeceo, Inerte) con probabilidades suavizadas. El orbe y el puntaje usan su salida. Desde la fase 10, pesos v2 entrenados con datos sintéticos y estandarización plegada (z = COEF · x + INTERCEPT); `ClassifierWeights.mc` lo genera `ml/export_weights.py`. Ver [IA.md](IA.md). | 6 ✅, 10 ✅ |
| `source/core` | `ClassifierWeightsV1` | Pesos v1 a mano (fase 6), sin plegar, solo como referencia: los leen `ml/evaluate.py` y la matriz de confusión v1/v2 de las pruebas. | 10 ✅ |
| `ml/` | `generate_dataset.py`, `features.py`, `train.py`, `evaluate.py`, `export_weights.py`, `test_vectors.py`, `import_real.py` | Pipeline de entrenamiento (`scripts\train.ps1`): dataset sintético con negativos difíciles, características idénticas al reloj, división por usuario, validación cruzada agrupada, regresión logística, informe v1/v2 y exportación a Monkey C. `import_real.py`: esqueleto para datos reales. | 10 ✅ |
| `source/views` | `ModelInfoView` | Pantalla *Modelo IA* del menú principal: versión, tipo, exactitud, falsos cabeceos y "Entrenado con datos sintéticos". | 10 ✅ |
| `source/views` | `DetectorDebugView` | Detector en vivo (`(:debug)`): estado, barras de probabilidad, línea base, umbral, último evento y su hora. | 6 ✅ |
| `source/core` | `AlertController` | Estado de la alerta: inactiva → activa (nivel 1–3, motivo, inicio) → descartada (tiempo de respuesta) o cancelada (pausa). Ignora eventos con una alerta abierta. | 7 ✅ |
| `source/core` | `VibePatterns`, `AlertVisuals` | Patrón de vibración por nivel (≤ 8 tramos, periodo de repetición) y curvas de la alerta: pulso de brillo (< 1 ciclo/s), entrada con rebote y sacudida sincronizada con el motor. | 7 ✅ |
| `source/core` | `AlertLog`, `AlertRecord` | Episodios de la guardia: alertas del detector con su hora, tiempo de respuesta (o ninguno) y nivel máximo; en memoria, 32 como mucho. | 7 ✅, 9 ✅ |
| `source/core` | `FatiguePredictor` | Fatiga Bajo / Moderado / Alto por reglas explicables ([DETECTOR.md](DETECTOR.md) §8). | 9 ✅ |
| `source/core` | `BreakTimer` | Cuenta regresiva del descanso guiado (15 min, 30 s en demo). | 9 ✅ |
| `source/core` | `GuardSummary`, `SessionHistory` | Resumen de una guardia y las 10 últimas, con su formato de Storage versionado. | 9 ✅ |
| `source/app` | `HistoryStore` | Historial en `Application.Storage` (como `DemoStore`). | 9 ✅ |
| `source/views` | `BreakView`, `SummaryView`, `HistoryMenu`, `SummaryText` | Descanso guiado, resumen y detalle, lista del historial y formatos. | 9 ✅ |
| `source/platform` | `Haptics` | `Attention.vibrate` con `VibeProfile` según el patrón, repetido con un `Timer`; respeta `vibrateOn`, enciende la luz y toca un tono por pulso si hay tonos. | 7 ✅ |
| `source/views` | `AlertView`, `AlertDelegate` | Alerta a pantalla completa: "¡DESPIERTA!", nivel, motivo y "Estoy despierto" (botón o START; BACK no la cierra). Ver [DISENO.md](DISENO.md) §5.3. | 7 ✅ |
| `source/core` | `AlertController` (escalamiento) | Sin respuesta, la alerta sube del nivel 1 (suave) al 3 (máxima) cada 10 s (6 s en demo). Vive en `AlertController`; no hay un módulo `AlertEscalator` aparte. | 9 ✅ |
| `source/core` | `DemoConfig` | Modo demo activo o no y escenario: decide la fuente (simulada o real), la calibración (5 s / 30 s) y la inactividad (8 s / 60 s), el ciclo de escenarios de DOWN y su diccionario para `Storage`. | 8 ✅ |
| `source/core` | `DemoScript` | Guion automático de 5 pasos (normal 10 s → tecleo 10 s → cabeceo hasta responder → normal 8 s → inactividad hasta responder); se congela con una alerta abierta y se cancela en cualquier momento. | 8 ✅ |
| `source/core` | `Toast`, `ToastKind` | Aviso breve de 1,5 s (cambio de escenario, fin del guion); la vista pone el texto. | 8 ✅ |
| `source/app` | `DemoStore`, `AppInfo` | `DemoConfig` en `Application.Storage` (se recuerda entre arranques); versión visible. | 8 ✅ |
| `source/app` | `GuardController` (modo demo) | Aplica `DemoConfig`, reinicia la guardia activa al cambiar de modo sin cortar la grabación, corre el guion con los lotes y las alertas, y atiende DOWN. | 8 ✅ |
| `source/views` | `MainMenu`, `ScenarioMenu`, `TestAlertMenu`, `AboutView`, `DemoText` | Menú principal (mantener UP, también en release): modo demo, escenario, guion automático, probar alerta (niveles 1–3), historial, modelo IA, acerca de y, solo en depuración, el menú de depuración. | 8 ✅, 10 ✅ |
| `source/core` | `Settings`, `SensitivityLevel`, `VibrationLevel` | Ajustes de usuario validados (valores por defecto, rangos) y el aviso de alerta solo visual. Lógica pura. | 11 ✅ |
| `source/core` | `DetectorThresholds` | Sacudida, inclinación e inactividad por sensibilidad (Baja / Media / Alta); Media = valores de las fases 6–10. Ver [DETECTOR.md](DETECTOR.md) §3.6. | 11 ✅ |
| `source/core` | `NodConfirmation` | El modelo confirma los cabeceos: espera 2 lotes y exige p(Normal) suavizada < 0,35; la inactividad pasa directa. Umbral elegido con `ml/confirmation.py`. Ver [DETECTOR.md](DETECTOR.md) §3.7 e [IA.md](IA.md) §12. | 11 ✅ |
| `source/core` | `VibePatterns` (ajuste) | Patrón por nivel **y** por ajuste de vibración (Suave / Normal / Fuerte), solo con número y duración de pulsos, máximo 4 pulsos (7 tramos). | 11 ✅ |
| `source/core` | `AlertVisuals` (reducidas) | Con animaciones reducidas: sin sacudida y pulso el doble de lento. | 11 ✅ |
| `source/app` | `AppSettings` | Único lector y escritor de `Application.Properties` (load / save). `FocusPulseApp.onSettingsChanged` aplica los cambios de Garmin Connect en caliente. | 3 ✅, 11 ✅ |
| `source/platform` | `Haptics` (ajustes) | Vibración según el ajuste (Apagada no enciende el motor), tonos solo con el ajuste Sonido y `Attention has :playTone`. | 11 ✅ |
| `source/views` | `SettingsMenu`, `NoFeedbackView` | Pantalla *Ajustes* del menú principal (Menu2: submenús de sensibilidad y vibración, interruptores) y aviso "Alerta solo visual". | 11 ✅ |
| `resources/settings` | `properties.xml`, `settings.xml` | Sensibilidad, vibración, sonido, animaciones reducidas, confirmación por IA y grabar actividad, editables desde Garmin Connect. | 3 ✅, 11 ✅ |
| `ml/` | `confirmation.py` | Reproduce la regla y la confirmación sobre el dataset sintético, elige retardo y umbral con el entrenamiento y mide el efecto (también por sensibilidad). | 11 ✅ |
| `ml/` + `source/core` | `ClassifierWeights` | Captura de datos **reales** con `SensorLogging`, reentrenamiento con `import_real.py` y decisión del evento entrenada. | futuro |
| `source/core` | `SensorWatchdog` | Más de 5 s sin lotes con la guardia activa → "sin datos"; al volver, `DrowsinessDetector.onDataGap` olvida la quietud, la caída y la postura (un corte no cuenta como inactividad). | 12 ✅ |
| `source/views` | `ViewUnwinder` | Cierra los menús abiertos (una vista cada 50 ms: `popView` no cambia `getCurrentView` hasta el siguiente ciclo) antes de apilar una alerta sobre la esfera. | 12 ✅ |
| `source/util` | `PixelShift`, `RoundLayout.shiftTo` | Anti quemado: la esfera entera se desplaza cada minuto por 9 posiciones (±2 px, media cero). | 12 ✅ |
| `source/core` | `OrbModel` (diseño web) | 3 contornos de Bézier del diseño web muestreados una vez en 48 puntos, rotación y escala no uniforme por fotogramas clave, ciclo y opacidad por estado, partículas que titilan con la paleta en rotación. | 13B ✅ |
| `source/core` | `GuardVisuals` | Curvas de la esfera con la guardia activa: arco de escaneo (radio 164, 16°, 2,8 s), ping de la píldora (1× → 2,6×, 0,8 → 0 en 1,6 s) y parpadeo de los dos puntos de la hora. | 13B ✅ |
| `source/core` | `ButtonFocus` | Foco del botón grande de la esfera: 1,5 s tras START, un toque, UP o DOWN (borde cian). | 13B ✅ |
| `source/core` | `AlertVisuals`, `AlertnessColors` (diseño web) | Pulso de 1,4 / 0,7 s hacia negro (nivel 2 limitado a 0,88 por contraste), parpadeo gradual #E01E1E ↔ #6A0000 cada 0,5 s y ondas del ícono (1× → 1,25× en 1,1 s, la segunda 0,55 s después). | 13B ✅ |

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
| Los Forerunner **ignoran el `dutyCycle`** de `VibeProfile`: la vibración siempre tiene la misma fuerza. Hay de 1 a 8 perfiles por llamada. | `Haptics` distingue los niveles 1–3 por duración, número de pulsos y pausas, no por intensidad. El ajuste "Vibración" (fase 11) cambia el patrón (Suave / Normal / Fuerte), no la fuerza. |
| Si la app pasa a **inactiva** sin grabar una actividad, los sensores bajan a 10 Hz o fallan y la vibración queda denegada. | **Decidido en la fase 3:** la guardia graba una actividad (`SessionRecorder`, permiso `Fit`) por defecto, y el ajuste `recordActivity` lo desactiva. `TelemetryEngine` mide los Hz efectivos para detectar la bajada a 10 Hz. |
| El simulador 9.3.0 **se cierra con un error** si la app termina con una sesión de `ActivityRecording` todavía grabando, aunque `onStop` la guarde. | `MainDelegate.onBack` detiene y guarda la guardia antes de que la app empiece a cerrarse; `onStop` lo repite como respaldo. |
| fr165 y fr165m comparten pantalla, teclas, sensores y API 5.2.0. | Un solo código para ambos productos; `scripts\build.ps1` compila para `fr165` y `export.ps1` para los dos. |

## Plan por fases

| Fase | Objetivo |
|---|---|
| 1 | Scaffolding: manifest, jungle, estructura, vista inicial, delegado, scripts, docs. |
| 2 | Sistema de diseño: paleta, tipografía, layout redondo, utilidades de dibujo, textos es/en, ícono y guía de estilo. |
| 3 | Telemetría del acelerómetro (real + simulada), ventana de características y grabación de la guardia. ✅ |
| 4 | Esfera principal: anillo de alerta, batería, hora, fecha, puntaje provisional, píldora, botón de guardia y marca DEMO. ✅ |
| 5 | Orbe IA animado, arco de escaneo y punto que late. ✅ |
| 6 | Inclinación, detector de cabeceos e inactividad, línea base adaptativa y clasificador v1. ✅ |
| 7 | Alerta a pantalla completa con vibración por niveles, luz y tono; "Estoy despierto" con tiempo de respuesta. ✅ |
| 8 | Modo demo oficial (también en release): menú principal, escenarios con DOWN, guion automático, probar alerta y acerca de; guía de la sustentación. ✅ |
| 9 | Escalamiento de la alerta, predictor de fatiga por reglas, descanso guiado, resumen de la guardia e historial persistente; guion con escalamiento. ✅ |
| 10 | IA entrenada: dataset sintético, entrenamiento en Python (regresión logística), exportación de pesos v2, métricas v1/v2, pantalla *Modelo IA* y escenario *mirar la hora*. ✅ |
| 11 | Ajustes de usuario (sensibilidad, vibración por pulsos, sonido, animaciones reducidas, confirmación por IA, grabar actividad) en el reloj y en Garmin Connect; confirmación de los cabeceos por el modelo; transición suave entre escenarios de la demo. ✅ |
| 12 | Pulido final y **versión 1.0.0**: aviso sin datos del sensor, alerta sobre menús, anti quemado, revisión de textos y contraste, limpieza, material de la tienda, guía de sustentación, export. ✅ |
| 13B | **Versión 1.1.0**: estados animados iguales al diseño web: orbe de Bézier con su movimiento, estados y paletas, partículas, arco de escaneo, ping, dos puntos que parpadean, botón de 220×60 con foco, y alertas con los colores, el pulso, el parpadeo y las ondas de la web; comparaciones en `docs/img/`. ✅ |
| 14 | **Versión 1.2.0**: fuentes propias del diseño web (Space Grotesk, Inter y JetBrains Mono en mapa de bits, `scripts\make_fonts.ps1`), batería, fecha siempre visible, etiqueta transitoria del modo demo, píldora y alerta con las medidas de la web; comparaciones y capturas de la tienda rehechas. ✅ |
| 13 | Pruebas en el reloj real: ejes del acelerómetro, vibración, pantalla apagada, batería, CPU y memoria ([PENDIENTES.md](PENDIENTES.md), "Requiere reloj real"). |
| 15 | Datos reales con `SensorLogging`, reentrenamiento y decisión del evento entrenada; publicación en la Connect IQ Store. |

En la fase 4 se adelantó la esfera principal (antes en la 7) para la sustentación en el
simulador; las características de inclinación pasan a la fase 6 junto al detector.

La fase 2 se insertó como sistema de diseño, así que las fases siguientes se corrieron un
número respecto al plan inicial. En la fase 9 se adelantaron el resumen y el historial
(antes en la 10) junto al escalamiento y la fatiga; los ajustes de usuario pasan a la 10.
En la fase 10 se adelantó el entrenamiento del modelo, con datos sintéticos; los ajustes
pasan a la 11 y los datos reales a la 12. En la fase 12 se adelantó la preparación de la
tienda (antes en la 14) y se cerró la versión 1.0.0; las pruebas en el reloj y los datos
reales pasan a las fases 13 y 14 (trabajo futuro). La fase 13B (versión 1.1.0) se insertó
antes de las pruebas en el reloj para igualar las animaciones al diseño web, y la fase 14
(versión 1.2.0) se usó para las fuentes propias; los datos reales y la publicación pasan a
la 15.

## Pruebas

- Pruebas unitarias en `tests/` con funciones anotadas `(:test)`; se ejecutan con
  `scripts\test.ps1`.
- Todo módulo de `core` debe tener pruebas. Las fuentes de muestras sintéticas del modo
  demo se reutilizan como datos de prueba del detector.
- Fase 3: 42 pruebas en total; las nuevas cubren `RingBuffer`, `SlidingWindow`,
  `TelemetryEngine` y la firma de cada escenario de `SimulatedAccelSource`.
- Fase 5: 74 pruebas; las nuevas cubren `TrigTable`, `OrbModel` (radio máximo,
  determinismo, velocidad por estado, paleta en 60/59/35/34, brillo de partículas),
  `ColorMath` y `FrameStats`.
- Fase 4: 57 pruebas; las nuevas cubren `AlertnessScore` (dirección según el escenario,
  límites, pausa, independencia de dt), `ClockFormat` y el hit-testing del botón.
- Fase 6: 100 pruebas. `tests/DetectorRig.mc` (clase `(:test)`, fuera de la compilación
  normal) pasa secuencias completas de la fuente simulada por motor → detector →
  clasificador → puntaje con el tiempo controlado. Las nuevas cubren `Tilt`,
  `DrowsinessDetector` (eventos, falsos positivos, refractario, pausa), `Baseline`,
  `StateClassifier` (con una matriz de confusión que se escribe en el registro) y el
  puntaje y el orbe a partir del clasificador. Ver [DETECTOR.md](DETECTOR.md) §6.
- Fase 7: 124 pruebas. Las nuevas cubren `AlertController` (evento → nivel 1, eventos
  ignorados con la alerta abierta, tiempo de respuesta, cancelar al pausar), `VibePatterns`
  (≤ 8 tramos positivos, ráfaga dentro del periodo, niveles crecientes sin intensidad),
  `AlertVisuals` y `alertPulseColor` (pulso más lento que 3 Hz, contraste ≥ 4,5:1 en todo
  el ciclo, rebote de entrada, sacudida solo con el motor encendido), `AlertLog`,
  `AlertnessScore.raiseTo` y el área táctil del botón de la alerta.
- Fase 8: 142 pruebas. Las nuevas cubren `DemoConfig` (tiempos de cada modo iguales a los
  del detector, ciclo de escenarios, persistencia y datos inválidos), `DemoStore` con el
  `Application.Storage` del simulador, `Toast` y la regla de DOWN, y `DemoScript` (orden y
  duración de los pasos, congelado con alerta, espera sin respuesta, cancelación y un
  recorrido completo con `DetectorRig`: alertas en los pasos 3 y 5, fin a los 48 s).
- Fase 9: 167 pruebas (escalamiento, fatiga, descanso, resumen e historial).
- Fase 10: 172 pruebas. Las nuevas comprueban que Python y el reloj calculan las mismas
  características y probabilidades (`featuresMatchPythonVectors`,
  `classifierMatchesPythonProbabilities`, con vectores generados en `ml/`), la firma del
  escenario *mirar la hora* y que no da eventos, y el formato de la pantalla *Modelo IA*. La
  matriz de confusión compara v1 y v2 en el reloj. Ver [IA.md](IA.md) §11.
- Fase 11: 194 pruebas. Las nuevas cubren `Settings` (valores por defecto, valores
  inválidos, alerta solo visual), `AppSettings` con el `Application.Properties` del
  simulador, `DetectorThresholds` (Media = valores de siempre, orden, inactividad 12/8/6 s,
  el cabeceo simulado con las tres sensibilidades), `VibePatterns` por ajuste, animaciones
  reducidas, el aviso de 3 s, `NodConfirmation` (sola y en la cadena: cabeceo real con
  alerta, mirar la hora tras teclear descartado, desactivada como antes, inactividad sin
  modelo) y el cambio de escenario sin cabeceo de más. El recorrido del guion con
  `DetectorRig` pasa ya por la confirmación.
- Fase 12: 205 pruebas. Las nuevas cubren `SensorWatchdog` (aviso a los 5 s, una sola vez,
  fin del corte con y sin `check`, pausa) y el detector tras un corte (sin inactividad falsa
  en 60 s y en demo), `PixelShift` (posiciones, saltos, media cero, una por minuto) y
  `RoundLayout.shiftTo`, y el contraste ≥ 4,5:1 de los textos de la esfera y de todas las
  bandas del puntaje. Los auxiliares de `tests/` van anotados `(:debug)` y no entran en
  release.
- Fase 13B: 226 pruebas. Las nuevas cubren los contornos de Bézier (puntos de cada curva,
  cerrados, orgánicos, siempre dentro del anillo de alerta), los fotogramas clave y el
  orden escala → rotación, el ciclo y la opacidad por estado sin saltos al cambiar, el
  titileo de las partículas (0,1–1, desfase, colores, radios), `GuardVisuals` (arco, ping,
  dos puntos), `ButtonFocus` (pulsación, teclas, vuelta del contador) y el botón de 220×60,
  y la alerta del diseño web (colores, periodos, parpadeo del nivel 3, mezcla con negro,
  contraste del nivel 2, ondas y ≈ 15 cuadros/s).
- Fase 14: 231 pruebas. Las nuevas cubren la escala de fuentes de `Typography.smaller` (las
  del sistema bajan hasta `FONT_XTINY`, las numéricas no bajan, toda escala termina), la
  elección de JetBrains Mono para las cifras solas (`Typography.isNumeric`), las
  abreviaturas de días y meses (`ClockFormat.listItem`) y el contraste de `TEXT_SOFT` y de
  las píldoras nuevas; el aviso de escenario dura 2 s.
