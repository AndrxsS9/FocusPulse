# Sistema de diseño — FocusPulse AI

Documento vivo del sistema de diseño de la app para el **Forerunner 165** y **165 Music**
(AMOLED redonda de 390×390, 325 ppi, táctil). Medidas y capturas verificadas en el simulador
del SDK 9.3.0. Todo lo descrito aquí está implementado en `source/util/`
(`Palette`, `Typography`, `Layout`, `Rect`, `Draw`) y en `source/core/AlertnessColors.mc`,
y se puede revisar en el simulador con la **guía de estilo** oculta (ver al final).

Referencia visual aprobada (demo web): reloj negro con un anillo de nivel de alerta en el
borde, hora grande al centro, batería arriba, porcentaje de alerta, píldora de estado y
botón grande "Iniciar guardia"; alerta a pantalla completa "¡DESPIERTA!" en naranja/rojo
con botón blanco "Estoy despierto"; y un "orbe IA" de 3 anillos orgánicos que giran detrás
de la hora.

## 1. Reglas AMOLED

En AMOLED cada píxel negro está apagado: no consume batería ni se desgasta.

1. **Fondo casi negro** (`BACKGROUND`, `0x07090C`) en todas las pantallas.
2. **Poca superficie encendida.** Los rellenos claros solo se usan en controles pequeños
   (botón, píldora). La única excepción es la **alerta a pantalla completa**, que debe
   ser imposible de ignorar y dura pocos segundos.
3. **Color en trazos, no en áreas**: el anillo, los bordes y el texto llevan el color; los
   rellenos de píldoras usan `SURFACE`, que es casi negro.
4. **Sin animaciones continuas innecesarias.** El orbe IA solo gira mientras la guardia está
   activa y la pantalla encendida (fases siguientes); nada se anima en pausa.
5. **Nada fijo durante mucho tiempo en la misma posición y a brillo alto** (quemado):
   la hora y el anillo cambian, y los elementos estáticos usan colores apagados.

## 2. Paleta

Constantes en `source/util/Palette.mc`. **Nunca** se escriben colores sueltos en el código.
Contraste calculado con la fórmula WCAG 2.x contra `BACKGROUND`.

| Token | Hex | Uso | Contraste sobre fondo |
|---|---|---|---|
| `BACKGROUND` | `0x07090C` | Fondo de todas las pantallas. | — |
| `SURFACE` | `0x11151B` | Relleno de píldoras y tarjetas pequeñas. | — |
| `BORDER` | `0x1C222B` | Pista del anillo de progreso, separadores. | decorativo |
| `BORDER_STRONG` | `0x2E3743` | Contorno de controles, puntos de página inactivos. | 1,7:1 (decorativo) |
| `TEXT` | `0xF5F7FA` | Texto principal, botón de la alerta. | 18,6:1 |
| `TEXT_SECONDARY` | `0x9AA4B2` | Estados, ayudas, etiquetas. | 7,9:1 |
| `WHITE` | `0xFFFFFF` | Solo texto sobre `RED_INTENSE` (alerta de nivel 3). | 19,9:1 |
| `ACCENT` | `0x4CC9F0` | Marca, guardia activa, alerta alta (≥ 60). | 10,4:1 |
| `ACCENT_LIGHT` | `0x8BDDF5` | Brillo del orbe IA, pulso del ícono. | 13,1:1 |
| `VIOLET` | `0xC3A6FF` | Tercer anillo del orbe IA. | 9,7:1 |
| `AMBER` | `0xFFB020` | Alerta media (35–59). | 10,9:1 |
| `RED` | `0xFF5A5A` | Alerta baja (< 35) sobre fondo oscuro. | 6,5:1 |
| `RED_INTENSE` | `0xE01E1E` | Fondo de la alerta de nivel 3. | 4,2:1 |
| `ORANGE` | `0xFF8A1F` | Fondo de la alerta de nivel 1. | 8,5:1 |
| `ORANGE_DEEP` | `0xF2620F` | Fondo de la alerta de nivel 2 ("naranja intenso"). | 6,2:1 |

`ORANGE_DEEP` no venía en la lista inicial de tokens: se agregó para el nivel 2 de alerta,
entre `ORANGE` y `RED_INTENSE`. `WHITE` se agregó para que el texto del nivel 3 pase 4,5:1.

### 2.1 Color según el nivel de alerta

Funciones puras en `source/core/AlertnessColors.mc` (probadas en
`tests/AlertnessColorsTest.mc`). El puntaje va de 0 (dormido) a 100 (despierto); fuera de
ese rango se recorta.

| Banda | Puntaje | `colorForAlertness` | `orbPalette` (exterior → interior) |
|---|---|---|---|
| `BAND_HIGH` | ≥ 60 | `ACCENT` | `ACCENT`, `ACCENT_LIGHT`, `VIOLET` |
| `BAND_MEDIUM` | 35–59 | `AMBER` | `AMBER`, `ORANGE`, `VIOLET` |
| `BAND_LOW` | < 35 | `RED` | `RED`, `RED_INTENSE`, `ORANGE` |

El anillo exterior del orbe siempre coincide con el color del anillo de nivel.

### 2.2 Alerta a pantalla completa

| Nivel | Fondo (`alertBackgroundColor`) | Texto (`alertTextColor`) | Contraste |
|---|---|---|---|
| 1 | `ORANGE` | `BACKGROUND` | 8,5:1 |
| 2 | `ORANGE_DEEP` | `BACKGROUND` | 6,2:1 |
| 3 | `RED_INTENSE` | `WHITE` | 4,8:1 |

El texto claro sobre los naranjas no llega a 3:1 (2,2:1 y 3,0:1), por eso los niveles 1 y
2 usan texto oscuro. En el nivel 3, `TEXT` (`0xF5F7FA`) se quedaba en 4,47:1; con blanco
puro llega a 4,8:1 y cumple 4,5:1 también para texto pequeño. El botón "Estoy despierto" es
`TEXT` con texto `BACKGROUND` (18,6:1) en los tres niveles.

## 3. Tipografía

Roles en `source/util/Typography.mc`, mapeados a fuentes del sistema. Las vistas usan el
rol, nunca la fuente directamente.

| Rol | Constante | Fuente del sistema | Alto en fr165 | Uso |
|---|---|---|---|---|
| Hora | `TIME` | `FONT_NUMBER_MEDIUM` | 109 px | Hora grande al centro. |
| Número | `NUMBER` | `FONT_NUMBER_MILD` | 88 px | Porcentaje de alerta, contadores. |
| Alerta | `ALERT` | `FONT_LARGE` | 61 px | "¡DESPIERTA!". |
| Título | `TITLE` | `FONT_MEDIUM` | 53 px | Títulos de pantalla y sección. |
| Cuerpo | `BODY` | `FONT_SMALL` | 45 px | Texto corrido, botones, píldoras. |
| Etiqueta | `LABEL` | `FONT_XTINY` | 30 px | Batería, unidades, ayudas. |

`FONT_TINY` (35 px) no tiene rol propio, pero `Draw.fittingFont` la usa como paso intermedio.

- Alturas medidas con `dc.getFontHeight()` en el simulador del fr165, que usa **Roboto
  TTF** para todas las fuentes, también las `FONT_NUMBER_*`. Por eso en el simulador estas
  dibujan letras y `%`. En el reloj real pueden traer solo dígitos y `:`, así que no se usan
  para letras y el `%` se sigue dibujando aparte (pendiente de confirmar en el dispositivo).
- Los layouts usan siempre `dc.getFontHeight()` y `dc.getTextWidthInPixels()`, nunca
  alturas supuestas.
- **Textos que no caben** (verificado con los textos en español):
  - Una sola palabra o un rótulo de una línea (títulos, botones, "¡DESPIERTA!") **no se
    parte**: `Draw.fittingFont` baja de la fuente preferida a la siguiente más pequeña
    hasta que cabe. Ejemplo: "Iniciar guardia" mide 239 px en `FONT_SMALL` y el botón 226 px,
    así que se dibuja en `FONT_TINY` (188 px).
  - Una frase larga se parte con `Graphics.fitTextToArea`. Ojo: para obtener *n* líneas
    hay que pedir algo más de *n* alturas de fuente (interlineado); con *n* exactas
    devuelve *n − 1* líneas y "…".
- Pendiente: decidir si la hora necesita una fuente personalizada (ver `PENDIENTES.md`).

## 4. Layout redondo

`RoundLayout` (`source/util/Layout.mc`) calcula todas las medidas a partir del lado menor de
la pantalla (`size`), en **milésimas**, a partir de `dc.getWidth()` y `dc.getHeight()`. No
hay números fijos de 390. Valores resultantes en el fr165:

| Medida | Proporción | fr165 (px) |
|---|---|---|
| Centro | `width/2`, `height/2` | (195, 195) |
| Grosor del anillo | 30 ‰ (mín. 4 px) | 11 |
| Margen pantalla → anillo | 18 ‰ | 7 |
| Radio del anillo (línea central, para `drawArc`) | — | 183 |
| Radio interior del anillo | — | 177 |
| Radio seguro para contenido | interior − 20 ‰ | 170 |
| Radio del orbe IA | 250 ‰ | 97 |
| Batería / título (`topY`) | 130 ‰ | 50 |
| Hora (`timeY`) | 420 ‰ | 163 |
| Porcentaje (`scoreY`) | 575 ‰ | 224 |
| Píldora de estado (`pillY`) | 660 ‰ | 257 |
| Botón grande (`buttonRect`) | arriba 720 ‰, alto 140 ‰ | x 82, y 280, 226×54 |
| Área táctil del botón (`buttonTouchRect`) | botón + 30 ‰ por lado | x 71, y 269, 248×76 |
| Indicador de página (`footerY`) | 905 ‰ | 352 |

```
            ╭──────────────╮
         ╭──┤   🔋 85 %     ├──╮      topY       batería
       ╱    │              │    ╲
      │     │    07:42     │     │    timeY      hora (orbe IA detrás)
      │     │     72 %     │     │    scoreY     porcentaje de alerta
      │     │ (Guardia act)│     │    pillY      píldora de estado
       ╲    │[Iniciar guar]│    ╱     buttonRect botón grande
         ╰──┤      • •     ├──╯       footerY    indicador de página
            ╰──────────────╯
        anillo de nivel de alerta en el borde
```

### Zonas seguras para texto

En una pantalla redonda el ancho disponible depende de la altura:

- `safeWidthAt(y)`: cuerda del círculo seguro (`contentRadius`) a la altura `y`.
- `safeWidthBetween(top, bottom)`: para una caja que ocupa de `top` a `bottom` manda el
  borde más alejado del centro.
- `stadiumWidth(midY, h)`: ancho máximo de un botón o píldora de extremos redondos cuyo
  contorno queda dentro del círculo seguro. El botón grande usa este cálculo, limitado a
  580 ‰ del lado.

Regla: ningún texto ni control cruza `contentRadius`; el anillo vive entre
`ringInnerRadius` y el borde.

## 5. Componentes

Funciones en `source/util/Draw.mc`:

| Componente | Función | Notas |
|---|---|---|
| Texto centrado | `Draw.centeredText` | Centrado en ambos ejes. |
| Anillo de progreso | `Draw.progressRing` | Pista completa en `BORDER` + avance con `drawArc` desde las 12 en punto en sentido horario, extremos redondos. Color del avance: `colorForAlertness`. |
| Píldora de estado | `Draw.pill` | Relleno `SURFACE`, borde `BORDER_STRONG`, texto de color. Devuelve su `Rect`; `Draw.pillHeight` da su alto antes de dibujarla, para colocar el resto alrededor. |
| Botón grande | `Draw.largeButton` | `fillRoundedRectangle` con extremos redondos. Cian con texto oscuro en la pantalla principal; blanco con texto oscuro en la alerta. Si el texto no cabe, reduce la fuente con `Draw.fittingFont`. |
| Indicador de página | `Draw.pageDots` | Punto actual en `ACCENT`, el resto en `BORDER_STRONG`. |

`Draw.enableAntiAlias(dc)` activa el suavizado cuando el dispositivo lo soporta.

## 6. Accesibilidad

### Contraste

- Texto normal: **≥ 4,5:1**. Texto grande (titulares, números grandes): **≥ 3:1**.
- Todos los colores de texto sobre `BACKGROUND` cumplen 4,5:1 (el menor es `RED`, 6,5:1),
  y todos los textos de la alerta a pantalla completa también (el menor es 4,8:1).
- `BORDER` y `BORDER_STRONG` son decorativos: nunca llevan información por sí solos.
- Contraste de la alerta: tabla de la sección 2.2.

### Áreas táctiles

- Mínimo **44 px** de alto y de ancho para cualquier área táctil
  (`RoundLayout.MIN_TOUCH`, `Rect.withMinSize`).
- El fr165 tiene 325 ppi (≈12,8 px por milímetro, dato de `simulator.json`), así que 44 px son solo
  ≈3,4 mm: es un **mínimo absoluto**, no un objetivo. Los controles principales usan
  áreas mucho mayores: el área táctil del botón grande es de 248×76 px (≈19×6 mm).
- El área táctil (`buttonTouchRect`) es más grande que el botón dibujado (`buttonRect`)
  para perdonar toques imprecisos con la mano en movimiento.
- Toda acción táctil tiene equivalente con botones físicos (START/STOP, BACK, UP/DOWN).
- En el fr165 el sistema traduce el **toque a `onSelect`** (igual que START). Los delegados
  que implementan `onTap` deben devolver `true` para que el toque no se procese dos veces
  (verificado: un toque alterna el estado una sola vez).

### No depender solo del color

- El nivel de alerta se muestra también como **porcentaje** y la sesión como **texto** en
  la píldora de estado.
- La alerta a pantalla completa incluye el nivel en texto ("Nivel 2 de 3") y, sobre todo,
  **vibración**: el usuario puede tener los ojos cerrados.

## 7. Textos

- Todos los textos visibles viven en `resources/strings/strings.xml` (inglés, por defecto)
  y `resources-spa/strings/strings.xml` (español), con el mismo `id`.
- Ids en inglés, con prefijo por grupo: `Status*`, `Button*`, `Label*`, `Alert*`,
  `Fatigue*`, `Demo*`, `Setting*`, `AiClass*`, `StyleGuide*`, `TypeRole*`.
- Mayúsculas solo en "¡DESPIERTA!" / "WAKE UP!".

## 8. Ícono del launcher

`resources/drawables/launcher_icon.png`: disco casi negro, pista tenue, anillo cian de 300°
desde las 12 en punto y un pulso tipo ECG en cian claro. Mide **54×54**, el tamaño
`launcherIcon` del fr165 y del fr165m en `compiler.json`. Se genera con
`scripts\icon.ps1` (colores leídos de `Palette.mc`):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\icon.ps1            # 54×54
powershell -ExecutionPolicy Bypass -File scripts\icon.ps1 -Size 60   # otro tamaño
```

## 9. Guía de estilo en el simulador

Pantalla oculta `StyleGuideView`, solo en compilaciones de depuración (anotación
`(:debug)`; `scripts\export.ps1` compila en release y la excluye).

- **Abrir**: en la pantalla principal, mantener pulsado UP (menú). En el simulador,
  mantener pulsado con el ratón el botón UP del dibujo del reloj (en `simulator.json`
  la tecla `menu` es UP con `isHold`).
- **Navegar**: DOWN/UP o deslizar; START/STOP o toque pasa a la siguiente. BACK vuelve a
  la pantalla principal.
- **Páginas** (7):
  1. Paleta base: superficies y textos.
  2. Paleta de acentos: cian/violeta, ámbar/naranjas y rojos.
  3. Tipografía numérica: hora y número.
  4. Tipografía de texto: alerta, título, cuerpo y etiqueta.
  5. Textos reales largos: "¡DESPIERTA!", la causa de cabeceo y el aviso de micro-sueños.
     Sirve para comprobar tildes, ñ, ¡ y · y el ajuste de línea.
  6. Componentes: anillo en 3 estados (82 %, 47 %, 21 %) con los colores de su orbe,
     píldora y botón.
  7. Alertas: colores por nivel y botón "Estoy despierto".

Todas las páginas se revisaron en inglés y en español en el simulador del fr165, sin
solapamientos.
