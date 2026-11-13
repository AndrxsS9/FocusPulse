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

```
 ┌──────────────┐     ┌──────────────┐
 │ SensorSource │     │  DemoSource  │   ← fuentes de muestras (platform / core)
 │ (acelerómetro│     │ (eventos     │
 │  real 25 Hz) │     │  sintéticos) │
 └──────┬───────┘     └──────┬───────┘
        └─────────┬──────────┘
                  ▼
          ┌──────────────┐
          │ SampleBuffer │   búfer circular de x/y/z            (core)
          └──────┬───────┘
                 ▼
        ┌──────────────────┐
        │ FeatureExtractor │ inclinación, varianza, jerk… por ventana (core)
        └────────┬─────────┘
                 ▼
          ┌──────────────┐
          │   Detector   │  heurístico → luego modelo entrenado (core)
          └──────┬───────┘
                 ▼
         ┌───────────────┐
         │ AlertEscalator│  niveles de alerta progresivos     (core)
         └──────┬────────┘
        ┌───────┴────────┐
        ▼                ▼
   ┌─────────┐     ┌───────────┐
   │ Haptics │     │  Vistas   │   vibración (platform) / pantalla (views)
   └─────────┘     └───────────┘
```

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
| `source/core` | `SampleBuffer` | Búfer circular de muestras del acelerómetro. | 3 |
| `source/platform` | `SensorSource` | `Sensor.registerSensorDataListener`, entrega lotes a `SampleBuffer`. | 3 |
| `source/core` | `FeatureExtractor` | Características por ventana: ángulo de inclinación (gravedad), varianza, *jerk*, caída brusca. | 4 |
| `source/core` | `NodDetector` | Máquina de estados heurística: postura estable → caída de cabeza/muñeca → inmovilidad. Calibración inicial por usuario. | 5 |
| `source/core` | `AlertEscalator` | Decide el nivel de alerta (1 suave → 3 intenso) y cuándo reiniciar. | 6 |
| `source/platform` | `Haptics` | `Attention.vibrate` con `VibeProfile` según el nivel. | 6 |
| `source/views` | `MonitorView`, `AlertView` | Monitoreo en curso y alerta a pantalla completa que exige confirmación. | 7 |
| `source/core` | `DemoSource` | Genera secuencias sintéticas (cabeceo, micro-sueño) que entran al mismo pipeline. | 8 |
| `resources/settings` | `properties.xml`, `settings.xml` | Sensibilidad, intensidad de vibración, modo demo. | 9 |
| `source/core` | `SessionStats` | Resumen de sesión (duración, eventos) e historial en `Application.Storage`. | 10 |
| `ml/` + `source/core` | `ModelWeights`, `ModelDetector` | Captura de datos, entrenamiento en Python, exportación de parámetros a Monkey C. | 11 |

`source/platform/` queda **aceptada** como carpeta de adaptadores de hardware (sensores,
vibración). Se crea en la fase 3 con `SensorSource`. Igual que las vistas, puede importar
`Toybox.Sensor` y `Toybox.Attention`; `core` nunca importa nada de `platform`.

`AlertnessColors` vive en `core` porque es lógica pura (puntaje → color) y se prueba con
`Toybox.Test`. Solo depende de `Palette`, que es un módulo de constantes sin imports.
El sistema de diseño completo está en [DISENO.md](DISENO.md).

## Restricciones del dispositivo

Confirmadas con el SDK 9.3.0 (detalle en [PENDIENTES.md](PENDIENTES.md)). Afectan al diseño de
los módulos de las fases siguientes:

| Restricción | Consecuencia |
|---|---|
| Acelerómetro hasta 100 Hz, lotes de hasta 4 s, valores en mili‑g. **Sin giroscopio.** | `SensorSource` pide la frecuencia con `getMaxSampleRateForSensorType(:accelerometer)` y una frecuencia de trabajo menor (25 Hz) para ahorrar batería. `FeatureExtractor` solo usa el acelerómetro: la inclinación sale de la gravedad, no de la velocidad angular. |
| Los Forerunner **ignoran el `dutyCycle`** de `VibeProfile`: la vibración siempre tiene la misma fuerza. Hay de 1 a 8 perfiles por llamada. | `Haptics` distingue los niveles 1–3 por duración, número de pulsos y pausas, no por intensidad. El ajuste "intensidad de vibración" de la fase 9 cambia el patrón, no la fuerza. |
| Si la app pasa a **inactiva** sin grabar una actividad, los sensores bajan a 10 Hz o fallan y la vibración queda denegada. | `FocusPulseApp` debe atender `onActive`/`onInactive`. Hay que decidir si la guardia graba una actividad (`ActivityRecording`, permiso `Fit`). |
| fr165 y fr165m comparten pantalla, teclas, sensores y API 5.2.0. | Un solo código para ambos productos; `scripts\build.ps1` compila para `fr165` y `export.ps1` para los dos. |

## Plan por fases

| Fase | Objetivo |
|---|---|
| 1 | Scaffolding: manifest, jungle, estructura, vista inicial, delegado, scripts, docs. |
| 2 | Sistema de diseño: paleta, tipografía, layout redondo, utilidades de dibujo, textos es/en, ícono y guía de estilo. |
| 3 | Captura del acelerómetro y búfer circular. |
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
