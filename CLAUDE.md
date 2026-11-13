# CLAUDE.md — FocusPulse AI

## Contexto

- App **nativa de Garmin Connect IQ** escrita en **Monkey C**, tipo `watch-app`
  (no watchface ni data field), para el **Forerunner 165** (`fr165`, AMOLED redonda 390×390,
  táctil + botones). Se publicará en la **Connect IQ Store**.
- Detecta micro-sueños/cabeceos con el acelerómetro y despierta al usuario con
  vibraciones progresivas. Tendrá un **modo demo** interno que simula eventos.
- No hay versión web.
- Meta del repo: más de 100 commits reales repartidos en ~12 fases
  (plan en `docs/ARQUITECTURA.md`).

## Estado del entorno

- El **Connect IQ SDK aún puede no estar instalado**. Si `%APPDATA%\Garmin\ConnectIQ\current-sdk.cfg`
  no existe, no intentes compilar ni abrir el simulador: escribe el código para que compile
  cuando el SDK esté listo y anota lo que falte verificar en `docs/PENDIENTES.md`.
- Con el SDK instalado, usa siempre los scripts: `scripts\build.ps1`, `run.ps1`, `test.ps1`,
  `export.ps1`. No inventes otras invocaciones de `monkeyc`.

## Paleta de colores

| Uso | Color | Constante |
|---|---|---|
| Fondo | `0x07090C` | `Palette.BACKGROUND` |
| Texto principal | `0xF5F7FA` | `Palette.TEXT` |
| Texto secundario | `0x9AA4B2` | `Palette.TEXT_SECONDARY` |
| Acento cian | `0x4CC9F0` | `Palette.ACCENT` |

Usa siempre las constantes de `source/util/Palette.mc`, nunca valores sueltos.
Pantalla AMOLED: fondos casi negros y poca superficie encendida.

## Reglas de trabajo

1. **Commits atómicos** con *conventional commits* (`feat(core): …`, `fix(views): …`,
   `test(core): …`, `docs: …`, `build(scripts): …`). Un commit por cambio lógico real;
   nada de commits de relleno. Mensajes de commit en inglés.
2. **Nunca hacer `git push`.** El push lo hace el dueño del repo manualmente.
3. **`source/core` está separado de la UI**: ahí no se importa `Toybox.WatchUi` ni
   `Toybox.Graphics`. Es lógica pura y testeable con `Toybox.Test`. El acceso a hardware
   (sensores, vibración) y la UI quedan fuera de `core`.
4. **Textos en español**: interfaz, comentarios y documentación. Cada texto visible va en
   `resources/strings/strings.xml` (inglés, por defecto) **y** en
   `resources-spa/strings/strings.xml` (español) con el mismo `id`. Nada de textos
   escritos directamente en el código.
5. **La llave de desarrollador nunca se versiona** ni se copia dentro del repo. Vive en
   `%USERPROFILE%\Downloads\FocusPulse-keys\`.
6. Toda lógica nueva en `core` va acompañada de pruebas en `tests/` (funciones `(:test)`).
7. Código Monkey C con tipos explícitos (`as Type`) en firmas y miembros.
