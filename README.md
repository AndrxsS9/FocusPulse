# FocusPulse AI

Aplicación nativa de **Garmin Connect IQ** (Monkey C) para el **Forerunner 165**
(pantalla redonda AMOLED de 390×390, táctil + botones).

FocusPulse AI detecta **micro-sueños y cabeceos** a partir del acelerómetro del reloj y
despierta al usuario con **vibraciones progresivas**. Incluye un **modo demo** interno para
simular eventos sin necesidad de dormirse frente al reloj.

> Estado: **Fase 1 — scaffolding**. La app muestra la pantalla inicial y alterna entre
> "Monitoreo en pausa" y "Monitoreo activo" con START/STOP o un toque. La detección todavía
> no está implementada. Ver [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md).

## Requisitos

| Herramienta | Detalle |
|---|---|
| **JDK** | Java 17 o superior en el `PATH` (`java -version`). |
| **Connect IQ SDK Manager** | Descárgalo desde developer.garmin.com/connect-iq/sdk. Con él instala **un SDK** (márcalo como actual) y el dispositivo **Forerunner 165 (`fr165`)**. |
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
| `build.ps1` | Compila para `fr165`. | `bin\FocusPulse.prg` |
| `run.ps1` | Compila, abre el simulador y ejecuta la app en `fr165`. `-NoBuild` omite la compilación. | — |
| `test.ps1` | Compila con pruebas (`-t`) y las ejecuta en el simulador. | `bin\FocusPulse-test.prg` |
| `export.ps1` | Genera el paquete firmado en modo release para la tienda. | `bin\FocusPulse.iq` |

Primer uso:

```powershell
.\scripts\setup.ps1
.\scripts\run.ps1
```

## Estructura

```
manifest.xml        Manifest de Connect IQ (watch-app, fr165, permisos, idiomas)
monkey.jungle       Configuración de compilación
source/app/         Punto de entrada (FocusPulseApp)
source/views/       Vistas y delegados de entrada
source/core/        Lógica pura (estado, telemetría, detector) sin dependencias de UI
source/util/        Utilidades compartidas (paleta de colores…)
resources/          Recursos por defecto (inglés): textos, ícono, layouts, settings
resources-spa/      Textos en español
tests/              Pruebas unitarias con Toybox.Test
scripts/            Scripts de PowerShell
docs/               Arquitectura y pendientes
ml/                 Entrenamiento del modelo de detección (no se empaqueta en el reloj)
```

## Documentación

- [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md) — módulos y plan por fases.
- [docs/PENDIENTES.md](docs/PENDIENTES.md) — lo que hay que verificar al instalar el SDK.
- [ml/README.md](ml/README.md) — entrenamiento del modelo.
