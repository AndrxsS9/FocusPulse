# FocusPulse AI

Aplicación nativa de **Garmin Connect IQ** (Monkey C) para el **Forerunner 165** y **165 Music**
(pantalla redonda AMOLED de 390×390, táctil + botones).

FocusPulse AI detecta **micro-sueños y cabeceos** a partir del acelerómetro del reloj y
despierta al usuario con **vibraciones progresivas**. Incluye un **modo demo** para
simular eventos sin necesidad de dormirse frente al reloj.

> Estado: **Fase 11 — Ajustes y confirmación por IA**. La pantalla inicial es la esfera de guardia: anillo de
> nivel de alerta en el borde, batería, hora, fecha, porcentaje de alerta, píldora de estado
> y botón grande "Iniciar guardia" (START o un toque en el botón). Detrás de la hora, un orbe
> IA de 3 anillos orgánicos cambia de color con el puntaje y de velocidad con la actividad
> (quieto en pausa, el doble con tecleo, cámara lenta al quedarse quieto); con la guardia
> activa gira un arco de escaneo y el punto de estado late. Durante la guardia se lee el
> acelerómetro a 25 Hz (o una fuente simulada, marcada como "DEMO"). Tras unos segundos de
> calibración ("Calibrando…"), el detector reconoce **cabeceos** (sacudida, quietud y caída
> del brazo) e **inactividad prolongada**, y un clasificador (Activo, Normal, Cabeceo,
> Inerte) mueve el puntaje y el orbe. Sus pesos (v2) salen de una **regresión logística
> entrenada en Python con datos sintéticos** y exportada a Monkey C (`ml/`, `scripts\train.ps1`,
> [docs/IA.md](docs/IA.md)). Cada evento abre una **alerta a pantalla completa**
> "¡DESPIERTA!" con vibración por pulsos, luz y tono, que solo se cierra con "Estoy despierto"
> (botón o START; BACK no la cierra). Los cabeceos los **confirma el modelo** 2 s después
> antes de abrir la alerta (descarta, por ejemplo, mirar la hora justo tras teclear).
> **Mantener UP** abre el menú principal, también en
> release: *Modo demo* (fuente simulada, calibración de 5 s e inactividad a 8 s; se
> recuerda entre arranques), *Escenario*, *Guion automático* y *Probar alerta* (solo con el
> modo demo), *Ajustes*, *Historial*, *Modelo IA* (versión y métricas del clasificador, "Entrenado
> con datos sintéticos") y *Acerca de*. Con el modo demo y la guardia activa, **DOWN** pasa
> al siguiente escenario (normal, tecleo, cabeceo, inactividad, mirar la hora). Ver [docs/GUIA_DEMO.md](docs/GUIA_DEMO.md) (sustentación),
> [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md), [docs/DETECTOR.md](docs/DETECTOR.md),
> [docs/IA.md](docs/IA.md) y [docs/DISENO.md](docs/DISENO.md).

## Requisitos

| Herramienta | Detalle |
|---|---|
| **JDK** | Java 17 o superior en el `PATH` (`java -version`). |
| **Connect IQ SDK Manager** | Descárgalo desde developer.garmin.com/connect-iq/sdk. Con él instala **un SDK** (márcalo como actual) y los dispositivos **Forerunner 165 (`fr165`)** y **165 Music (`fr165m`)**. Probado con el SDK 9.3.0. |
| **VS Code + Monkey C** | Extensión `garmin.monkey-c` (la instala `setup.ps1`). Opcional pero recomendada. |
| **Llave de desarrollador** | Archivo `developer_key.der` en `%USERPROFILE%\Downloads\FocusPulse-keys\`. La genera `setup.ps1`. |
| **OpenSSL** | Solo para generar la llave. Si no está en el `PATH` se usa el de Git for Windows (`C:\Program Files\Git\usr\bin\openssl.exe`). |

> **La llave de desarrollador nunca se versiona.** Vive fuera del repo y `.gitignore`
> bloquea `*.der`, `*.pem` y `developer_key*`. Haz una copia de seguridad: sin la misma
> llave no se pueden publicar actualizaciones en la Connect IQ Store.

## Scripts

Todos los scripts están en `scripts/` y se ejecutan desde la raíz del repo. Leen la ruta del
SDK desde `%APPDATA%\Garmin\ConnectIQ\current-sdk.cfg` (lo escribe el SDK Manager).

Si la política de ejecución de PowerShell los bloquea, ejecútalos así:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build.ps1
```

| Script | Qué hace | Salida |
|---|---|---|
| `setup.ps1` | Instala la extensión de VS Code y genera la llave si no existe (nunca la sobrescribe). Informa si faltan Java o el SDK. | Llave en `Downloads\FocusPulse-keys\` |
| `build.ps1` | Compila para `fr165` con verificación de tipos estricta (`-l 3`). `-Release` compila en modo release (sin el código `(:debug)`), como el paquete de la tienda. | `bin\FocusPulse.prg` (`-Release`: `bin\FocusPulse-release.prg`) |
| `run.ps1` | Compila, abre el simulador y ejecuta la app en `fr165`. `-NoBuild` omite la compilación; `-TargetDevice fr165m` usa el 165 Music; `-Release` ejecuta la compilación de release (la de la sustentación). Copia al simulador la definición de los ajustes para su editor. | — |
| `test.ps1` | Compila con pruebas (`-t`), las ejecuta en el simulador y termina con error si alguna falla. | `bin\FocusPulse-test.prg` |
| `export.ps1` | Genera el paquete firmado en modo release para la tienda (`fr165` y `fr165m`). | `bin\FocusPulse.iq` |
| `train.ps1` | Crea `ml\.venv` (Python 3.12), instala `ml\requirements.txt`, genera el dataset sintético, entrena, evalúa v1/v2, elige el umbral de la confirmación por IA y exporta los pesos. `-Seed N` cambia la semilla; `-NoExport` no toca `source\` ni `tests\`. No usa el SDK. Ver [ml/README.md](ml/README.md). | `source\core\ClassifierWeights.mc`, `ml\reports\` |
| `icon.ps1` | Genera el ícono del launcher con los colores de `Palette.mc`. `-Size` cambia el tamaño. No necesita el SDK. | `resources\drawables\launcher_icon.png` |

Primer uso:

```powershell
.\scripts\setup.ps1
.\scripts\run.ps1
```

## Modo demo

Para presentar la app en el simulador (o en el reloj sin dormirse), en cualquier
compilación:

1. `.\scripts\run.ps1 -Release` abre la compilación de release en el simulador del fr165.
2. **Mantén pulsado UP** en la esfera: menú principal → *Modo demo* (START). La esfera
   cambia la fecha por **"DEMO · Normal"**.
3. START inicia la guardia (5 s de calibración). **DOWN** recorre *Movimiento normal →
   Tecleo activo → Simular cabeceo → Inactividad prolongada → Mirar la hora* con un aviso
   de 1,5 s; el cabeceo abre la alerta a los ~8 s (6 s del detector + 2 s de la
   confirmación) y la inactividad a los ~10 s.
4. *Guion automático* recorre todo solo (normal 10 s → tecleo 10 s → cabeceo → normal 8 s →
   inactividad → inactividad sin respuesta) y espera a que se responda cada alerta salvo la
   última, que escala hasta el nivel 3; luego pausa la guardia y muestra su resumen. La
   esfera muestra "Guion 2/6 · Tecleo activo". *Probar alerta* abre los niveles 1, 2 y 3.
5. Sin respuesta, la alerta sube un nivel cada 6 s (10 s con el sensor real). Tras 3
   episodios en 5 min (30 min con el sensor real) la esfera avisa "Micro-sueños repetidos";
   tocar el aviso abre un descanso guiado de 30 s (15 min). *Historial* guarda las 10
   últimas guardias.

Paso a paso, qué decir y qué hacer si algo falla: [docs/GUIA_DEMO.md](docs/GUIA_DEMO.md).

## Ajustes

Se cambian en el reloj (**mantener UP → *Ajustes***; cada ítem muestra su valor) y desde la
app **Garmin Connect** (`resources/settings/`); se guardan en `Application.Properties` y se
aplican sin reiniciar la guardia (`onSettingsChanged`).

| Ajuste | Valores (por defecto en negrita) | Qué hace |
|---|---|---|
| Sensibilidad | Baja · **Media** · Alta | Umbrales del detector: sacudida 440 / 400 / 340 mg, inclinación 45 / 35 / 28°, inactividad 90 / 60 / 45 s (demo 12 / 8 / 6 s). |
| Vibración | Apagada · Suave · **Normal** · Fuerte | Número y duración de los pulsos (el FR165 no cambia la fuerza del motor), hasta 4 pulsos por ráfaga. |
| Sonido | **Activado** · Desactivado | Tonos de alerta. Solo aparece en el reloj si tiene `Attention.playTone`. |
| Animaciones reducidas | Activado · **Desactivado** | Orbe sin partículas; alerta sin sacudida y con el pulso el doble de lento (mismo color y textos). |
| Confirmación por IA | **Activado** · Desactivado | El modelo confirma cada cabeceo antes de la alerta ([docs/IA.md](docs/IA.md) §12). |
| Grabar actividad | **Activado** · Desactivado | Graba la guardia como actividad para que sensores y vibración sigan con la app en segundo plano. |

Si la vibración queda apagada y no hay sonido, la app avisa **"Alerta solo visual"** (en
Ajustes y al iniciar la guardia). En el simulador, *File > Edit Persistent Storage > Edit
Application.Properties data* hace de Garmin Connect cuando la app se cargó con `run.ps1`.

## Probar la telemetría en el simulador

Solo en compilaciones de depuración (`build.ps1` / `run.ps1` sin `-Release`; ni
`run.ps1 -Release` ni el `.iq` de `export.ps1` incluyen nada de esto).

1. `.\scripts\run.ps1` abre la app en el simulador del fr165.
2. **Mantén pulsado UP** en la esfera: menú principal → *Debug* / *Depuración* (último
   ítem, solo en depuración) abre el menú de depuración.
3. **Fuente de datos** → elige *Sensor real* o un escenario simulado: *Movimiento normal*,
   *Tecleo activo*, *Simular cabeceo*, *Inactividad prolongada* o *Manual (X/Y/Z fijos)*.
   Es el mismo ajuste que el *Modo demo* del menú principal (elegir un escenario lo
   enciende, *Sensor real* lo apaga) y se recuerda en el siguiente arranque. El escenario
   manual solo está aquí.
4. **Telemetría en vivo** → START (o un toque) inicia y pausa la guardia. Se ven las
   muestras recibidas, la fuente, X/Y/Z, la varianza, la sacudida (últimas 10 muestras y
   pico del lote), la quietud, los Hz efectivos frente a los pedidos y si está grabando.
   **UP/DOWN** cambian de fuente sin salir; volver a elegir *Simular cabeceo* repite el
   cabeceo desde el principio (3 s de movimiento, caída y quietud).
5. BACK vuelve al menú y a la pantalla principal; BACK con la guardia activa la detiene,
   guarda la actividad y sale.

**Datos del acelerómetro "real" en el simulador.** El simulador no entrega lotes del
acelerómetro por sí solo (la telemetría se queda en 0 muestras). Para inyectarlos:

- *Simulation > Activity Data*, *Data Source* = **Data Simulation** y pulsa ▶. Llegan lotes a
  25 Hz, pero son vectores de 1 g en direcciones al azar: sirven para comprobar que el
  sensor real funciona, no para probar la detección.
- *Data Source* = **FIT/GPX Playable File** y *Load File* reproduce un FIT. Según la doc del
  SDK, un FIT grabado en el reloj con `SensorLogging` reproduce el acelerómetro real
  (pendiente de probar, ver [docs/PENDIENTES.md](docs/PENDIENTES.md)).

Para la sustentación se usa el **modo demo**: es reproducible y cada escenario tiene su
firma (tabla en [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md)).

Las actividades grabadas en el simulador se guardan en
`%TEMP%\com.garmin.connectiq\GARMIN\Activities\`. El ajuste "Grabar actividad" se
cambia en *Ajustes* (ver arriba).

## Estructura

```
manifest.xml        Manifest de Connect IQ (watch-app, fr165/fr165m, permisos, idiomas)
monkey.jungle       Configuración de compilación
source/app/         Punto de entrada (FocusPulseApp)
source/views/       Vistas, menú principal y delegados de entrada (incluye el menú de depuración)
source/core/        Lógica pura (estado, telemetría, detector, modo demo) sin dependencias de UI
source/platform/    Adaptadores de hardware: acelerómetro real y simulado, grabación
source/util/        Sistema de diseño: paleta, tipografía, layout redondo, dibujo
resources/          Recursos por defecto (inglés): textos, ícono, layouts, ajustes
resources-spa/      Textos en español
tests/              Pruebas unitarias con Toybox.Test
scripts/            Scripts de PowerShell
docs/               Arquitectura y pendientes
ml/                 Entrenamiento del modelo de detección (no se empaqueta en el reloj)
```

## Documentación

- [docs/GUIA_DEMO.md](docs/GUIA_DEMO.md) — guía paso a paso de la demo para la sustentación.
- [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md) — módulos y plan por fases.
- [docs/DETECTOR.md](docs/DETECTOR.md) — algoritmo del detector, línea base, clasificador y
  matriz de confusión.
- [docs/DISENO.md](docs/DISENO.md) — sistema de diseño: paleta, tipografía, layout, accesibilidad.
- [docs/PENDIENTES.md](docs/PENDIENTES.md) — datos confirmados y lo que falta verificar
  (sobre todo en el reloj real).
- [docs/IA.md](docs/IA.md) — clasificador entrenado: pipeline, fuga de datos, métricas v1/v2
  y limitaciones (datos sintéticos).
- [ml/README.md](ml/README.md) — cómo entrenar con `scripts\train.ps1`.
