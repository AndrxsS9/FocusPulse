# Arquitectura — FocusPulse AI

Documento vivo. Describe los módulos previstos y el plan por fases. Lo marcado como
*propuesta* puede cambiar al validarlo con el SDK y el dispositivo real.

## Principios

1. **Núcleo puro y testeable.** `source/core` contiene toda la lógica de detección y
   escalado de alertas. No importa `Toybox.WatchUi`, `Toybox.Graphics`, `Toybox.Sensor` ni
   `Toybox.Attention`: recibe muestras como números y devuelve decisiones. Así se prueba con
   `Toybox.Test` y el modo demo usa exactamente el mismo código que el modo real.
2. **Hardware detrás de adaptadores.** Sensores y vibración se envuelven en clases pequeñas
   fuera de `core` (*propuesta*: nueva carpeta `source/platform/`), que traducen entre
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
| `source/util` | `Palette` | Colores del proyecto. | 1 ✅ |
| `source/core` | `MonitorState` | Estado de sesión (activo / en pausa). | 1 ✅ |
| `source/views` | `MainView`, `MainDelegate` | Pantalla inicial; START/STOP y toque alternan el monitoreo. | 1 ✅ |
| `source/core` | `SampleBuffer` | Búfer circular de muestras del acelerómetro. | 2 |
| `source/platform`* | `SensorSource` | `Sensor.registerSensorDataListener`, entrega lotes a `SampleBuffer`. | 2 |
| `source/core` | `FeatureExtractor` | Características por ventana: ángulo de inclinación (gravedad), varianza, *jerk*, caída brusca. | 3 |
| `source/core` | `NodDetector` | Máquina de estados heurística: postura estable → caída de cabeza/muñeca → inmovilidad. Calibración inicial por usuario. | 4 |
| `source/core` | `AlertEscalator` | Decide el nivel de alerta (1 suave → 3 intenso) y cuándo reiniciar. | 5 |
| `source/platform`* | `Haptics` | `Attention.vibrate` con `VibeProfile` según el nivel. | 5 |
| `source/views` | `MonitorView`, `AlertView` | Monitoreo en curso y alerta a pantalla completa que exige confirmación. | 6 |
| `source/core` | `DemoSource` | Genera secuencias sintéticas (cabeceo, micro-sueño) que entran al mismo pipeline. | 7 |
| `resources/settings` | `properties.xml`, `settings.xml` | Sensibilidad, intensidad de vibración, modo demo. | 8 |
| `source/core` | `SessionStats` | Resumen de sesión (duración, eventos) e historial en `Application.Storage`. | 9 |
| `ml/` + `source/core` | `ModelWeights`, `ModelDetector` | Captura de datos, entrenamiento en Python, exportación de parámetros a Monkey C. | 10 |

\* *Propuesta*: la carpeta `source/platform/` no existe todavía; se creará en la fase 2.

## Plan por fases

| Fase | Objetivo |
|---|---|
| 1 | Scaffolding: manifest, jungle, estructura, vista inicial, delegado, scripts, docs. |
| 2 | Captura del acelerómetro y búfer circular. |
| 3 | Extracción de características por ventana. |
| 4 | Detector heurístico de cabeceos/micro-sueño con calibración. |
| 5 | Alertas con vibración progresiva. |
| 6 | Interfaz de monitoreo y pantalla de alerta. |
| 7 | Modo demo interno para simular eventos. |
| 8 | Ajustes de usuario (sensibilidad, intensidad). |
| 9 | Resumen de sesión e historial. |
| 10 | Captura de datos, entrenamiento del modelo en `/ml` y detector basado en modelo. |
| 11 | Rendimiento, memoria, batería y pruebas en dispositivo real. |
| 12 | Preparación para la Connect IQ Store: íconos finales, capturas, textos de tienda es/en, export. |

## Pruebas

- Pruebas unitarias en `tests/` con funciones anotadas `(:test)`; se ejecutan con
  `scripts\test.ps1`.
- Todo módulo de `core` debe tener pruebas. Las fuentes de muestras sintéticas del modo
  demo se reutilizan como datos de prueba del detector.
