# FocusPulse AI

Aplicación nativa de **Garmin Connect IQ** (Monkey C) para el **Forerunner 165** y **165 Music**
(pantalla redonda AMOLED de 390×390, táctil + botones).

FocusPulse AI detecta **micro-sueños y cabeceos** a partir del acelerómetro del reloj y
despierta al usuario con **vibraciones progresivas**. Incluye un **modo demo** interno para
simular eventos sin necesidad de dormirse frente al reloj.

> Estado: **Fase 5 — orbe IA animado**. La pantalla inicial es la esfera de guardia: anillo de
> nivel de alerta en el borde, batería, hora, fecha, porcentaje de alerta, píldora de estado
> y botón grande "Iniciar guardia" (START o un toque en el botón). Detrás de la hora, un orbe
> IA de 3 anillos orgánicos cambia de color con el puntaje y de velocidad con la actividad
> (quieto en pausa, el doble con tecleo, cámara lenta al quedarse quieto); con la guardia
> activa gira un arco de escaneo y el punto de estado late. Durante la guardia se lee el
> acelerómetro a 25 Hz (o una fuente simulada, marcada como "DEMO"). La detección de
> cabeceos y las alertas llegan en las fases siguientes. Ver
> [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md) y [docs/DISENO.md](docs/DISENO.md).

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
| `build.ps1` | Compila para `fr165` con verificación de tipos estricta (`-l 3`). | `bin\FocusPulse.prg` |
| `run.ps1` | Compila, abre el simulador y ejecuta la app en `fr165`. `-NoBuild` omite la compilación; `-TargetDevice fr165m` usa el 165 Music. | — |
| `test.ps1` | Compila con pruebas (`-t`), las ejecuta en el simulador y termina con error si alguna falla. | `bin\FocusPulse-test.prg` |
| `export.ps1` | Genera el paquete firmado en modo release para la tienda (`fr165` y `fr165m`). | `bin\FocusPulse.iq` |
| `icon.ps1` | Genera el ícono del launcher con los colores de `Palette.mc`. `-Size` cambia el tamaño. No necesita el SDK. | `resources\drawables\launcher_icon.png` |

Primer uso:

```powershell
.\scripts\setup.ps1
.\scripts\run.ps1
```

## Probar la telemetría en el simulador

Solo en compilaciones de depuración (`build.ps1` / `run.ps1`; el `.iq` de `export.ps1` no
incluye nada de esto).

1. `.\scripts\run.ps1` abre la app en el simulador del fr165.
2. **Mantén pulsado UP** (menú) en la pantalla principal: se abre el menú de depuración.
3. **Fuente de datos** → elige *Sensor real* o un escenario simulado: *Movimiento normal*,
   *Tecleo activo*, *Simular cabeceo*, *Inactividad prolongada* o *Manual (X/Y/Z fijos)*.
   La elección se guarda y se recupera en el siguiente arranque. Con una fuente simulada,
   la pantalla principal muestra "Modo demo".
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

Para la sustentación se recomienda la **fuente simulada**: es reproducible y cada escenario
tiene su firma (tabla en [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md)).

Las actividades grabadas en el simulador se guardan en
`%TEMP%\com.garmin.connectiq\GARMIN\Activities\`. El ajuste "Grabar guardia como
actividad" se cambia en el simulador con *File > Edit Persistent Storage > Edit
Application.Properties data* y en el reloj desde la app Garmin Connect.

## Estructura

```
manifest.xml        Manifest de Connect IQ (watch-app, fr165/fr165m, permisos, idiomas)
monkey.jungle       Configuración de compilación
source/app/         Punto de entrada (FocusPulseApp)
source/views/       Vistas y delegados de entrada (incluye el menú de depuración)
source/core/        Lógica pura (estado, telemetría, detector) sin dependencias de UI
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

- [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md) — módulos y plan por fases.
- [docs/DISENO.md](docs/DISENO.md) — sistema de diseño: paleta, tipografía, layout, accesibilidad.
- [docs/PENDIENTES.md](docs/PENDIENTES.md) — datos confirmados y lo que falta verificar
  (sobre todo en el reloj real).
- [ml/README.md](ml/README.md) — entrenamiento del modelo.
