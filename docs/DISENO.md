# Sistema de diseño — FocusPulse AI

Documento vivo del sistema de diseño de la app para el **Forerunner 165** y **165 Music**
(AMOLED redonda de 390×390, 325 ppi, táctil). Medidas y capturas verificadas en el simulador
del SDK 9.3.0. Todo lo descrito aquí está implementado en `source/util/`
(`Palette`, `Typography`, `Layout`, `Rect`, `Draw`), en `source/core/AlertnessColors.mc` y
en las fuentes de `resources/fonts/`, y se puede revisar en el simulador con la **guía de
estilo** oculta (ver al final).

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
4. **Sin animaciones continuas innecesarias.** El orbe IA, el arco de escaneo y el ping
   solo se animan con la guardia activa y la vista en primer plano (el timer se detiene en
   `onHide`); en pausa el orbe queda quieto y tenue. Ver la sección 5.2.
5. **Nada fijo durante mucho tiempo en la misma posición y a brillo alto** (quemado):
   la hora y el anillo cambian, los elementos estáticos usan colores apagados y, desde la
   fase 12, **la esfera entera se desplaza cada minuto** a la siguiente de 9 posiciones
   alrededor del centro (±2 px por eje, saltos de 2 px como mucho, media cero; `PixelShift`
   y `RoundLayout.shiftTo`). Se mueve todo junto, así que el diseño redondo no cambia y el
   anillo queda dentro de la pantalla. Las áreas táctiles no se mueven (les sobran 12 px).
   No aplica a la alerta, que dura segundos.

## 2. Paleta

Constantes en `source/util/Palette.mc`. **Nunca** se escriben colores sueltos en el código.
Contraste calculado con la fórmula WCAG 2.x contra `BACKGROUND`.

| Token | Hex | Uso | Contraste sobre fondo |
|---|---|---|---|
| `BACKGROUND` | `0x07090C` | Fondo de todas las pantallas. | — |
| `SURFACE` | `0x11151B` | Relleno de los avisos de la esfera (fatiga, "Alerta solo visual"). | — |
| `PILL` | `0x1A1F27` | Fondo de la píldora de estado en pausa o con un aviso (diseño web, fase 14). | decorativo (`TEXT_SECONDARY` encima: 6,6:1) |
| `PILL_ACTIVE` | `0x0F2A36` | Fondo cian tenue de la píldora "Guardia activa" (diseño web, fase 14). | decorativo (`ACCENT_LIGHT` encima: 9,8:1) |
| `BORDER` | `0x1C222B` | Fondo del botón "Pausar guardia" (diseño web), pista del anillo de progreso (guía de estilo), separadores. | decorativo (`TEXT` encima: 14,9:1) |
| `RING_TRACK` | `0x1A1F27` | Pista del anillo de nivel de la esfera principal (parte sin avance). | decorativo |
| `BORDER_STRONG` | `0x2E3743` | Contorno de controles, puntos de página inactivos. | 1,7:1 (decorativo) |
| `TEXT` | `0xF5F7FA` | Texto principal, texto del botón "Pausar guardia". | 18,6:1 |
| `TEXT_SECONDARY` | `0x9AA4B2` | Estados, ayudas, etiquetas, fecha, "ALERTA". | 7,9:1 |
| `TEXT_SOFT` | `0xC9D1DB` | Porcentaje de la batería (diseño web, fase 14). | 12,9:1 |
| `WHITE` | `0xFFFFFF` | Texto de la alerta de nivel 3 y relleno del botón "Estoy despierto". | 19,9:1 |
| `BLACK` | `0x000000` | Texto de las alertas de nivel 1 y 2, borde y texto del botón "Estoy despierto"; color con el que se mezcla el pulso de los niveles 1 y 2 (diseño web). | — (sobre `ORANGE`: 8,9:1) |
| `ACCENT` | `0x4CC9F0` | Marca, guardia activa, alerta alta (≥ 60). | 10,4:1 |
| `ACCENT_LIGHT` | `0x8BDDF5` | Contorno B del orbe IA; punto, ping y texto de la píldora "Guardia activa". | 13,1:1 |
| `VIOLET` | `0xC3A6FF` | Contorno C del orbe IA (banda cian). | 9,7:1 |
| `AMBER` | `0xFFB020` | Alerta media (35–59). | 10,9:1 |
| `AMBER_LIGHT` | `0xFFD27A` | Contorno B del orbe IA en la banda ámbar (fase 13B). | 14,0:1 |
| `RED` | `0xFF5A5A` | Alerta baja (< 35) sobre fondo oscuro. | 6,5:1 |
| `RED_LIGHT` | `0xFF8A8A` | Contorno B del orbe IA en la banda roja (fase 13B). | 8,8:1 |
| `RED_INTENSE` | `0xE01E1E` | Fondo de la alerta de nivel 3 (alterna con `RED_DARK`). | 4,2:1 |
| `RED_DARK` | `0x6A0000` | Segundo color del parpadeo del nivel 3 (fase 13B). | decorativo |
| `ORANGE` | `0xFF8A1F` | Fondo de la alerta de nivel 1. | 8,5:1 |
| `ORANGE_DEEP` | `0xFF5A1F` | Fondo de la alerta de nivel 2 ("naranja intenso"; `0xF2620F` hasta la 1.0.0). | 6,4:1 |

Los colores atenuados del orbe, el arco y el ping no son tokens nuevos: se calculan con
`ColorMath.blend(token, BACKGROUND, opacidad)` a partir de los tokens de esta tabla.

`ORANGE_DEEP` no venía en la lista inicial de tokens: se agregó para el nivel 2 de alerta,
entre `ORANGE` y `RED_INTENSE`. `WHITE` se agregó para que el texto del nivel 3 pase 4,5:1.
En la fase 13B (versión 1.1.0) los colores de la alerta y del orbe se igualaron a los del
diseño web: `ORANGE_DEEP` cambió de valor y se agregaron `BLACK`, `RED_DARK`, `AMBER_LIGHT`
y `RED_LIGHT`.

### 2.1 Color según el nivel de alerta

Funciones puras en `source/core/AlertnessColors.mc` (probadas en
`tests/AlertnessColorsTest.mc`). El puntaje va de 0 (dormido) a 100 (despierto); fuera de
ese rango se recorta.

| Banda | Puntaje | `colorForAlertness` | `orbPalette` (contornos A, B, C; diseño web) |
|---|---|---|---|
| `BAND_HIGH` | ≥ 60 | `ACCENT` | `ACCENT` #4CC9F0, `ACCENT_LIGHT` #8BDDF5, `VIOLET` #C3A6FF |
| `BAND_MEDIUM` | 35–59 | `AMBER` | `AMBER` #FFB020, `AMBER_LIGHT` #FFD27A, `ORANGE` #FF8A1F |
| `BAND_LOW` | < 35 | `RED` | `RED` #FF5A5A, `RED_LIGHT` #FF8A8A, `AMBER` #FFB020 |

El contorno A del orbe siempre coincide con el color del anillo de nivel.

### 2.2 Alerta a pantalla completa

Valores del diseño web desde la fase 13B (versión 1.1.0):

| Nivel | Fondo (`alertBackgroundColor`) | Texto (`alertTextColor`) | Contraste |
|---|---|---|---|
| 1 | `ORANGE` #FF8A1F | `BLACK` | 8,9:1 |
| 2 | `ORANGE_DEEP` #FF5A1F | `BLACK` | 6,7:1 |
| 3 | `RED_INTENSE` #E01E1E ↔ `RED_DARK` #6A0000 | `WHITE` | 4,8:1 → 13,0:1 |

El texto claro sobre los naranjas no llega a 3:1, por eso los niveles 1 y 2 usan texto
negro. En el nivel 3, `TEXT` (`0xF5F7FA`) se quedaba en 4,47:1 sobre `RED_INTENSE`; con
blanco puro llega a 4,8:1. El botón "Estoy despierto" es `WHITE` con borde de 3 px y texto
`BLACK` (21:1) en los tres niveles, también en el 3, como en el diseño web.

El fondo además late (§5.3, `alertPulseColor`):

- **Niveles 1 y 2:** opacidad 1 → mínima → 1, simulada mezclando el color con negro. El
  diseño web pide 0,72 en ambos. En el nivel 1 el texto queda en **4,83:1** en el punto más
  oscuro. En el nivel 2, `ORANGE_DEEP` al 0,72 deja el texto en **3,81:1 (< 4,5:1)**, así
  que se conserva la profundidad que ya tenía la app: **0,88 (5,3:1)**. Lo documenta la
  prueba `alertPulseDimsTowardsBlack`.
- **Nivel 3:** pasa de `RED_INTENSE` a `RED_DARK` y vuelve; el texto blanco gana contraste
  al oscurecerse (13,0:1 en `RED_DARK`).

`alertPulseColorsKeepTextReadable` comprueba ≥ 4,5:1 en 11 puntos del pulso de cada nivel.

## 3. Tipografía

Desde la fase 14 (versión 1.2.0) los textos del diseño se dibujan con **fuentes propias en
mapa de bits** (BMFont con antialias), las mismas del diseño web. Roles en
`source/util/Typography.mc`; las vistas usan el rol, nunca la fuente directamente.
`Typography.load()` las carga **una sola vez** al arrancar (`FocusPulseApp.onStart`); antes
de cargarlas (por ejemplo, en las pruebas) cada rol apunta a la fuente del sistema más
parecida.

| Rol | Fuente | Tamaño | Glifos | Uso |
|---|---|---|---|---|
| `clock` | Space Grotesk Bold, espaciado −2 px | 76 px | dígitos y `:` | Hora de la esfera, cuenta atrás del descanso. |
| `alertTitle` | Space Grotesk Bold, −0,4 px | 42 px | letras de "¡DESPIERTA!" y "WAKE UP!" | Título de la alerta. |
| `title` | Space Grotesk Bold | 22 px | texto | Títulos: Modelo IA, Resumen, Descanso, Acerca de, aviso solo visual. |
| `body` | Inter Medium | 15 px | texto | Fecha, línea del modo demo, textos y etiquetas de filas. |
| `bodyStrong` | Inter SemiBold | 15 px | texto | Nivel de la alerta, valores con letras, aviso de fatiga. |
| `label` | Inter Medium | 13 px | texto | "ALERTA", motivo de la alerta, ayudas. |
| `labelStrong` | Inter SemiBold | 13 px | texto | Píldora de estado, "DEMO" del resumen. |
| `button` | Inter Bold | 18 px | texto | Botón grande de la esfera y del descanso. |
| `alertButton` | Inter ExtraBold | 22 px | texto | "Estoy despierto". |
| `number` | JetBrains Mono SemiBold | 22 px | dígitos, `%`, `,` y `.` | Porcentaje de alerta ("85%"). |
| `numberSmall` | JetBrains Mono SemiBold | 14 px | dígitos, `%`, `,` y `.` | Batería ("78%"), cifras de las filas ("3", "93,3%"). |

"Texto" son las letras de español e inglés con tildes, ü y ñ, los dígitos y los signos que
usan los textos de la app: `` !"%'()+,-./:;?¡¿·–—…‘’“” `` (101 glifos).

**Origen y licencias.** TTF variables oficiales de [google/fonts](https://github.com/google/fonts)
(`assets/fonts/`, sin modificar; origen y SHA-256 en `assets/fonts/README.md`), todas con la
**SIL Open Font License 1.1**: Space Grotesk (The Space Grotesk Project Authors, Florian
Karsten), Inter (The Inter Project Authors, Rasmus Andersson) y JetBrains Mono (The
JetBrains Mono Project Authors). Textos de las licencias en `resources/fonts/LICENSES/` y
créditos en el README.

**Generación** (`scripts\make_fonts.ps1` → `scripts/make_fonts.py`, Python de `ml\.venv`):

1. fontTools crea una instancia estática de cada peso (Inter, además, con el tamaño óptico
   igual al tamaño en px);
2. Pillow dibuja cada glifo con el antialias de FreeType y lo recorta a su tinta;
3. el avance de cada glifo es el **exacto** de la fuente (tabla `hmtx`) más el espaciado,
   redondeado al píxel. Los avances de Pillow vienen redondeados por el *hinting* ("r" de
   Inter Bold 18 avanzaba 8 px en vez de 7,2) y separaban letras ("guar dia");
4. escribe un `.fnt` de texto y un `.png` en escala de grises (glifo blanco sobre negro, el
   formato del ejemplo *Analog* del SDK) por fuente y `resources/fonts/fonts.xml` con
   `antialias="true"`.

Es reproducible (dos ejecuciones dan archivos idénticos) con las versiones de Pillow y
fontTools fijadas en `ml/requirements.txt`. `make_fonts.ps1 -Check` comprueba que todos los
caracteres de los dos `strings.xml` están en el juego de texto. 11 fuentes, ≈ 103 000 px de
glifos: el `.prg` de release pasa de 87 a 128,5 kB y la memoria pico del recorrido completo,
de 104,2 a **110,7 kB de 763,6 kB** (ver `PENDIENTES.md`).

**Pesos y espaciado medidos en las referencias** (`docs/img/referencia/`, llevadas a 390 px
con la escala del contenido, el botón de 220 px): con los avances exactos coinciden sin
espaciado "Iniciar guardia" (Bold 18: 122 px, referencia 123), "Nivel 1 de 3 · vibración
suave" (SemiBold 15: 207 / 208), "Monitoreo en pausa" (SemiBold 13: 123 / 123) y "Estoy
despierto" (ExtraBold 22: 166 / 168). La hora "10:50" mide 189 px con 56 px de alto: Space
Grotesk 76 sin espaciado mide 196 → −2 px por carácter (≈ −0,025 em); "¡DESPIERTA!", 231
frente a 235 → −0,4 px. La fecha y el motivo tienen el trazo de Inter **Medium**, más fino
que el SemiBold.

**Cifras.** `Typography.valueFont` elige JetBrains Mono para un valor que solo tiene dígitos,
`%`, `,` o `.` ("3", "93,3%") e Inter SemiBold si lleva letras ("1 min 11 s", "v2"). Por eso
los porcentajes que van en JetBrains Mono no llevan espacio en ningún idioma
(`PercentCompactFormat`, `ModelPercentFormat`).

**Textos que no caben.** `Draw.fittingFont` baja por la escala de `Typography.smaller`:
botón de la alerta → botón → cuerpo destacado → etiqueta destacada; cuerpo → etiqueta; título
→ cuerpo destacado. La hora, el título de la alerta y las cifras no bajan (ninguna otra fuente
tiene sus glifos). Una frase larga se parte con `Graphics.fitTextToArea`, que acepta las
fuentes propias; para obtener *n* líneas hay que pedir algo más de *n* alturas de fuente.

**Espaciado entre letras** fuera de la fuente: `Draw.trackedText` dibuja letra a letra
("ALERTA" con 1 px).

**Menús nativos.** Los `Menu2` (menú principal, Ajustes, Historial, escenarios, probar alerta)
no admiten fuentes propias: siguen con la fuente del sistema (Roboto en el simulador). Las
vistas de depuración (telemetría, detector en vivo) también usan las del sistema.

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
| Batería / título (`topY`) | 152 ‰ | 59 |
| Hora (`timeY`, centro de la caja de la fuente) | 296 ‰ | 115 (cifras de y 88 a 142) |
| Fecha (`dateY`) | 434 ‰ | 169 |
| "ALERTA" + porcentaje (`scoreY`, centro de las cifras) | 527 ‰ | 205 |
| Píldora de estado (`pillY`, alto `pillHeight`, margen `pillPadding`) | 617 ‰, 67 ‰, 31 ‰ | 240, 26 px, 12 px |
| Botón grande (`buttonRect`) | arriba 682 ‰, alto 154 ‰, ancho máx. 565 ‰ | x 85, y 265, 220×60 (diseño web) |
| Área táctil del botón (`buttonTouchRect`) | botón + 30 ‰ por lado | x 74, y 254, 242×82 |
| Botón de la alerta (`alertButtonRect`) | arriba 631 ‰, alto 180 ‰, ancho máx. 642 ‰ | x 70, y 246, 250×70 (diseño web) |
| Indicador de página (`footerY`) | 905 ‰ | 352 |

En la fase 4 la hora subió (de 420 ‰ a 335 ‰) para dejar sitio a la fecha, y el porcentaje
y la píldora se acercaron para que quede aire entre la píldora y el botón. En la fase 14 todas
las zonas se colocaron donde las pone el diseño web, medido en las referencias a 390 px: en
la captura del simulador cada banda queda a 1–2 px de la referencia (más el desplazamiento
anti quemado de ±2 px). La anatomía completa de la esfera está en la sección 5.1.

### Zonas seguras para texto

En una pantalla redonda el ancho disponible depende de la altura:

- `safeWidthAt(y)`: cuerda del círculo seguro (`contentRadius`) a la altura `y`.
- `safeWidthBetween(top, bottom)`: para una caja que ocupa de `top` a `bottom` manda el
  borde más alejado del centro.
- `stadiumWidth(midY, h)`: ancho máximo de un botón o píldora de extremos redondos cuyo
  contorno queda dentro del círculo seguro. El botón grande usa este cálculo, limitado a
  565 ‰ del lado (220 px en el fr165, como el diseño web).

Regla: ningún texto ni control cruza `contentRadius`; el anillo vive entre
`ringInnerRadius` y el borde.

## 5. Componentes

### 5.1 Anatomía de la esfera principal (fase 4; medidas del diseño web desde la fase 14)

`MainView` (`source/views/MainView.mc`), revisada en el simulador del fr165 y del fr165m
en español e inglés. Medidas reales en el fr165 (390×390). Comparación con el diseño web en
[img/comparacion-esfera.png](img/comparacion-esfera.png):

```
                 ╭────── anillo de alerta (r 183, 11 px) ──────╮
              ╭──┤          ▭ 78% •                y 59       ├──╮   batería (+ punto demo)
            ╱   │                                              │   ╲
           │    │          10:50                   y 88–142    │    │  hora (orbe IA detrás)
           │    │       Dom, 15 Nov                y 169       │    │  fecha (2 s: "DEMO · …")
           │    │     ALERTA 88%                   y 205       │    │  puntaje
           │    │  ( • Guardia activa )            y 228–253   │    │  píldora
            ╲   │  [  Pausar guardia  ]            y 265–325   │   ╱   botón
              ╰─┤                                              ├─╯
                 ╰──────────────────────────────────────────────╯
```

| Zona | Contenido | Fuente / tamaño | Color |
|---|---|---|---|
| Anillo | Pista completa + avance desde las 12 en sentido horario, `percent` = puntaje. Extremos redondos. | trazo de 11 px, r 183 | pista `RING_TRACK`; avance `colorForAlertness(puntaje)` |
| Batería (`topY` 59) | Ícono dibujado de 22×12 px (borne a la derecha, relleno proporcional) y, 8 px después, el porcentaje real de `System.getSystemStats().battery` sin espacio ("78%", `PercentCompactFormat`), centrados juntos. Con el modo demo, un **punto cian de 5 px** 6 px a la derecha del porcentaje (la batería sigue centrada). | `numberSmall` (JetBrains Mono SemiBold 14 px) | `TEXT_SOFT` #C9D1DB; `RED` con ≤ 15 %; punto `ACCENT` |
| Hora (`timeY` 115) | `HH:MM` en 24 h si el sistema la usa (`is24Hour`), si no `H:MM` en 12 h sin a. m./p. m. Los dos puntos se dibujan aparte y parpadean cada segundo del reloj entre opacidad 1 y 0,25 (fase 13B, `GuardVisuals.colonAlpha`), también en pausa. Cifras de 55 px de alto (y 88–142). | `clock` (Space Grotesk Bold 76 px, −2 px) | `TEXT`; dos puntos `TEXT` mezclado con el fondo |
| Fecha (`dateY` 169) | "Dom, 15 Nov" / "Sun, 15 Nov" (`DateFormat` "$1$, $2$ $3$"). Día de la semana y mes con abreviaturas **propias** (`DateWeekdays`, `DateMonths`), no las del sistema: así solo usa letras que tienen las fuentes, sea cual sea el idioma del reloj. **Siempre visible**, también en modo demo. | `body` (Inter Medium 15 px) | `TEXT_SECONDARY` |
| Puntaje (`scoreY` 205) | "ALERTA" en mayúsculas con 1 px entre letras (`Draw.trackedText`) y el porcentaje sin espacio ("85%"), 10 px después, centrados juntos y **alineados por la línea base**: las cifras van centradas en `scoreY` y la etiqueta apoya en su línea base (`Graphics.getFontAscent`). | `label` (Inter Medium 13 px) + `number` (JetBrains Mono SemiBold 22 px) | etiqueta `TEXT_SECONDARY`; número del color del anillo |
| Píldora (`pillY` 240) | "Monitoreo en pausa" / "Guardia activa" ("Calibrando…" mientras el detector aprende la línea base, 30 s o 5 s en demo) / "Sensor no disponible" / "Sin datos del sensor" (fase 12: más de 5 s sin lotes con la guardia activa; se quita sola y tiene prioridad sobre el aviso de fatiga). 26 px de alto, 12 px de margen a cada lado, sin borde; punto de 8 px a 8 px del texto. | `labelStrong` (Inter SemiBold 13 px) | pausa: fondo `PILL` #1A1F27, punto y texto `TEXT_SECONDARY`; activa: fondo cian tenue `PILL_ACTIVE` #0F2A36, punto (con ping) y texto `ACCENT_LIGHT`; avisos: fondo `PILL`, texto `AMBER`, sin punto |
| Botón (`buttonRect`, 220×60, radio 30, y 265) | "Iniciar guardia" o "Pausar guardia"; `fittingFont` bajaría la fuente si no cupiera (en el fr165 caben los dos idiomas). Con la guardia activa, borde `ACCENT` de 2 px por dentro mientras tiene el foco (`ButtonFocus`, 1,5 s tras START, un toque, UP o DOWN). | `button` (Inter Bold 18 px) | inicio: `ACCENT` con texto `BACKGROUND`; guardia activa: `BORDER` #1C222B con texto `TEXT` (diseño web) |
| Línea del modo demo (`dateY` 169, fase 8; transitoria desde la fase 14) | **2 s** en el sitio de la fecha cuando DOWN cambia de escenario o el guion cambia de paso (`Toast` de tipo escenario): "DEMO · Tecleo activo" o "Guion 2/6 · Tecleo activo". Fuera de esos 2 s se ve la fecha y el modo demo se reconoce por el punto cian junto a la batería. Nombres cortos (`DemoShort*`) para que quepa en los dos idiomas. | `body` | `ACCENT` |
| Aviso de seguridad (centro) | "Alerta solo visual / Sin vibración ni sonido", 3 s al iniciar la guardia sin vibración ni sonido. Caja de esquinas redondas centrada; el valor baja de `button` hasta que cabe. Tapa la fecha y el puntaje mientras dura. (Hasta la fase 13B el cambio de escenario también usaba esta caja.) | `label` + `button` → `bodyStrong` | relleno `SURFACE`, borde y título `AMBER`, valor `TEXT` |

**Orden de dibujo:** fondo → orbe IA y partículas → anillo de alerta y arco de escaneo →
contenido. Ver la sección 5.2.

**Refresco:** un `Timer` redibuja cada 1000 ms en pausa y cada 83 ms (≈ 12 cuadros/s) con
la guardia activa (`REFRESH_PAUSED_MS` / `REFRESH_ACTIVE_MS`); la alerta, a ≈ 15 cuadros/s.
Nada se anima por encima de 15 cuadros/s. Se detiene en `onHide` y se reanuda en `onShow`
(verificado en el simulador con *Settings > Force onHide / Force onShow*). El puntaje no
depende del timer: lo actualiza cada lote de telemetría.

**Entrada:** START (`onKey`, `KEY_ENTER`) y un toque dentro de `buttonTouchRect` inician o
pausan la guardia; un toque en cualquier otra parte no hace nada. UP y DOWN enfocan el
botón (borde cian 1,5 s); DOWN además cambia de escenario en el modo demo. Ver la sección 6.

**AMOLED:** el único relleno claro es el botón "Iniciar guardia" (220×60 px); con la guardia
activa el botón pasa a `BORDER` (#1C222B), así que durante la guardia no queda ningún relleno
claro.

### 5.2 Orbe IA (fase 5; diseño web desde la fase 13B)

El "orbe IA" detrás del contenido muestra de un vistazo cómo ve la app al usuario: su
**color** sigue el puntaje de alerta y su **velocidad** sigue lo que está haciendo. Desde la
fase 13B (versión 1.1.0) copia el orbe del diseño web: mismas curvas, mismos tiempos y
mismos colores. Comparación en [img/comparacion-guardia.png](img/comparacion-guardia.png).

**Forma.** 3 contornos orgánicos cerrados (no círculos), cada uno un trazado SVG de 4 curvas
de Bézier cúbicas en coordenadas locales (centro en 0,0; y hacia abajo; px de una pantalla
de 390):

| Contorno | Trazado | Trazo | Opacidad propia |
|---|---|---|---|
| A | `M 0,-150 C 80,-152 140,-90 145,-10 C 150,80 85,140 5,138 C -85,136 -150,75 -146,-5 C -142,-90 -80,-148 0,-150 Z` | 2,5 px | 0,6 |
| B | `M 10,-140 C 95,-135 155,-60 140,20 C 125,100 60,150 -20,145 C -100,140 -150,60 -140,-20 C -130,-100 -70,-145 10,-140 Z` | 2 px | 0,45 |
| C | `M -5,-155 C 70,-160 130,-110 150,-30 C 165,50 120,125 30,140 C -60,155 -135,100 -150,20 C -160,-60 -80,-150 -5,-155 Z` | 2 px | 0,35 |

`OrbModel` los muestrea **una sola vez** al crearse, 12 puntos por curva (`POINTS` = 48 por
contorno), y la vista los dibuja como polilínea cerrada centrada en la pantalla (195, 195,
con el desplazamiento anti quemado), escalada por lado / 390. Los puntos se pasan como
`Float` a `drawLine` (con suavizado se colocan con precisión de subpíxel), y el grosor 2,5
también se pasa tal cual a `setPenWidth`.

**Movimiento.** Cada contorno tiene su propia fase de ciclo (0–1) y sigue 3 fotogramas
clave con interpolación lineal, como la animación CSS:

| Contorno | 0 % | 50 % | 100 % |
|---|---|---|---|
| A | 0°, escala (1, 1) | 180°, (1,07, 0,93) | 360°, (1, 1) |
| B (gira al revés) | 0°, (0,95, 1,04) | −180°, (1,05, 0,95) | −360°, (0,95, 1,04) |
| C | 40°, (1, 1) | 220°, (0,92, 1,06) | 400°, (1, 1) |

Cada punto local p va a pantalla como centro + k · R(θ) · S · p (primero la escala y luego
la rotación, como `rotate(θ) scale(sx, sy)`; θ > 0 gira en sentido horario). Por cuadro son
3 `Math.sin`/`Math.cos` (uno por contorno) y 4 multiplicaciones por punto.

**Estados** (`OrbModel.stateFor`, por orden de prioridad; los decide la clase ganadora del
clasificador, [DETECTOR.md](DETECTOR.md) §5). Duración de un ciclo de A / B / C y opacidad
general del orbe:

| Estado | Cuándo | Ciclo A / B / C | Opacidad |
|---|---|---|---|
| Pausa | Guardia en pausa. | congelado | 0,3 |
| Activo ("guardia activa y despierto") | Clase Activo (tecleo, gestos). | 4,5 / 6 / 7,5 s | 1 |
| Somnoliento | Clase Cabeceo o Inerte, o puntaje < 60. | 22 / 28 / 34 s | 0,75 |
| Normal | El resto. | 9 / 12 / 15 s | 0,9 |

Cada contorno avanza su fase dt / duración, así que un cambio de estado cambia la velocidad
sin saltos. La actividad alta tiene prioridad sobre un puntaje bajo: si el usuario vuelve a
moverse, el orbe se acelera enseguida aunque el puntaje todavía esté subiendo.

**Color.** `AlertnessColors.orbPalette(puntaje)` (§2.1): A, B y C en cian / cian claro /
violeta (≥ 60), ámbar / ámbar claro / naranja (35–59) o rojo / rojo claro / ámbar (< 35).

**Transparencia.** El fr165 no tiene `Dc.setStroke` ni `Dc.setFill` en tiempo de ejecución
(el simulador da *Symbol Not Found* aunque `compiler.json` marque `alphaBlendingSupport`).
La opacidad de cada contorno (la suya × la del estado, `OrbModel.ringAlpha`) se precalcula
mezclando el color con el fondo (`ColorMath.blend`). Sobre `BACKGROUND` el resultado es
idéntico a un trazo con alfa. El orbe va de radio ≈ 137 a ≈ 165 px (con la escala máxima):
queda detrás de la hora, la fecha, el puntaje y el botón, y nunca toca el anillo de alerta
(empieza en 177 px; lo comprueba `orbStaysInsideTheAlertRing`).

**Partículas.** 16 puntos fijos sobre un anillo de radio 150 px (con un desplazamiento
radial de ±1,4 % para que no parezcan marcas de reloj), de radios alternos 2,2 y 1,6 px y
con los colores de la paleta en rotación (A, B, C, A…). Titilan de opacidad 0,1 a 1 y de
vuelta (onda triangular) en 2,4 s; 1,2 s en estado activo y 4,8 s somnoliento; en pausa
quedan congeladas. Cada una va 7/16 de ciclo por detrás de la anterior, así nunca titilan
dos vecinas a la vez. Su opacidad también se multiplica por la del estado.

**Arco de escaneo** (`GuardVisuals`). Con la guardia activa, un arco cian al 55 % de 46 px
de largo (16°) y 3 px de trazo gira en sentido horario sobre un círculo de radio 164 px, una
vuelta cada 2,8 s. Indica que la app está vigilando.

**Ping.** El punto de la píldora "Guardia activa" es `ACCENT_LIGHT`; detrás, un círculo del
mismo color crece de 1× a 2,6× su radio y se desvanece de 0,8 a 0 en 1,6 s.

**Animaciones reducidas** (ajuste): el orbe queda congelado (con el color y la opacidad de
su estado) y sin partículas. El arco de escaneo y el ping siguen.

**Refresco y rendimiento.** Con la guardia activa se redibuja cada 83 ms (≈ 12 cuadros/s);
en pausa, una vez por segundo con el orbe quieto. `MainView.ANIMATIONS_ENABLED = false`
apaga orbe, arco y ping. En depuración, `FrameStats` escribe en la consola cada 5 s los
cuadros por segundo reales, el tiempo de dibujo y el estado y la fase del orbe. Medido en
el simulador del fr165 con el orbe de Bézier (fase 13B): 12,2–13,4 cuadros/s y **3–7 ms de
dibujo medio** en todos los estados; ver `PENDIENTES.md`.

### 5.3 Alerta a pantalla completa (fase 7)

`AlertView` (`source/views/AlertView.mc`) se apila sobre la esfera con `pushView` cuando el
detector emite un cabeceo o una inactividad, y solo se cierra con "Estoy despierto". Si en
ese momento hay menús abiertos (Ajustes, Historial, Modelo IA, demo…), primero se cierran
(`ViewUnwinder`, fase 12): la alerta siempre queda sobre la esfera y al responder se vuelve
a ella, sin pantallas apiladas. La
lógica vive en `core` (`AlertController`, `VibePatterns`, `AlertVisuals`, `AlertLog`) y la
vibración en `source/platform/Haptics.mc`.

**Anatomía** (fr165, revisada en español e inglés en el simulador):

```
                       (|▯|)                      y 102    ícono de vibración (círculo r 30)
                   ¡DESPIERTA!                    base 172 Space Grotesk Bold 42 px
          Nivel 1 de 3 · vibración suave          y 196    Inter SemiBold 15 px
        Cabeceo / pérdida de tono muscular        y 221    Inter Medium 13 px, una línea
             [   Estoy despierto   ]              y 246–316 botón 250×70, Inter ExtraBold 22 px
```

Desde la fase 14 (fuentes propias) las posiciones son las del diseño web medidas en las
referencias a 390 px; en la captura del simulador cada línea queda a 1–2 px de la referencia.

Comparación con el diseño web en [img/comparacion-alertas.png](img/comparacion-alertas.png).

| Zona | Contenido | Notas |
|---|---|---|
| Fondo | `alertPulseColor(nivel, pulso)` | Naranja / naranja intenso que laten hacia negro, rojo intenso ↔ rojo oscuro (§2.2). La única pantalla con fondo claro: dura segundos. |
| Ícono | Círculo de 30 px de radio y 3 px de trazo con un teléfono (13×21 px) y una barra de vibración a cada lado. Dos ondas: anillos de 3 px que crecen de 1× a 1,25× el radio y se desvanecen hacia el fondo en 1,1 s; la segunda sale 0,55 s después (`AlertVisuals.ripple*`). Sin vibración no hay ondas. | Del color del texto. |
| Título | "¡DESPIERTA!" / "WAKE UP!" | `alertTitle`: Space Grotesk Bold 42 px con −0,4 px entre letras (231 px de ancho, como la web). Su fuente solo trae esas letras, así que no baja a otra. |
| Nivel | "Nivel N de 3 · vibración suave/media/máxima" (`AlertLevelLineFormat`). | `bodyStrong` (Inter SemiBold 15 px). La vibración va en minúsculas porque sigue al punto medio. "Nivel 3 de 3 · vibración máxima" mide ≈ 215 px (357 px con la fuente del sistema hasta la 1.1.0). En inglés es "max vibration" desde la fase 12. |
| Motivo | "Cabeceo / pérdida de tono muscular" o "Inactividad prolongada". | `label` (Inter Medium 13 px), centrado; en una línea si cabe en 260 px (en los dos idiomas caben: 225 px el más largo), si no en dos con `fitTextToArea`. |
| Botón | "Estoy despierto" / "I'm awake": `WHITE` con borde `BLACK` de 3 px y texto `BLACK` en los tres niveles (diseño web). | `alertButton` (Inter ExtraBold 22 px). `RoundLayout.alertButtonRect`, 250×70 px en y 246 (el de la esfera es 220×60). Área táctil 272×92 px (`alertButtonTouchRect`). |

**Niveles y vibración** (`VibePatterns`). Los Forerunner ignoran el `dutyCycle`: los
niveles se distinguen por pulsos, duración y repetición. Cada ráfaga es una sola llamada a
`Attention.vibrate` (≤ 8 `VibeProfile`) y se repite con un `Timer`.

| Nivel | Color | Patrón (ms, encendido/apagado) | Se repite cada | Motor encendido | Sacudida |
|---|---|---|---|---|---|
| 1 suave | `ORANGE` | 150 · 150 · 150 (2 pulsos) | 3 s | 10 % | 2 px |
| 2 media | `ORANGE_DEEP` | 300 · 200 · 300 · 200 · 300 (3 pulsos) | 2 s | 45 % | 4 px |
| 3 máxima | `RED_INTENSE` | 800 · 200 · 800 · 200 · 800 · 200 · 800 (4 tramos) | 4 s | 80 %, casi continuo | 6 px |

Un evento del detector siempre abre el **nivel 1**; "Probar alerta" (menú principal con el
modo demo, o depuración) abre cualquier nivel. Si nadie responde, la alerta **escala** sola
(fase 9, abajo).

#### Escalamiento automático (fase 9)

`AlertController.update` sube la alerta un nivel por cada intervalo sin respuesta en el
nivel actual:

| | Sensor real | Modo demo |
|---|---|---|
| 1 → 2 | a los 10 s | a los 6 s |
| 2 → 3 | 10 s después (20 s) | 6 s después (12 s) |
| Nivel 3 | se mantiene hasta la respuesta | igual |

- Lo avanzan los lotes del acelerómetro (`GuardController.onBatch`) y cada cuadro de la
  propia alerta (`AlertView` llama a `GuardController.onAlertTick`), así que también
  escalan las alertas de prueba con la guardia en pausa. Si una llamada llega tarde, sube
  todos los niveles pendientes de una vez.
- Al subir, **sin cerrar ni volver a abrir la vista**: `Haptics.start(nivel)` cambia al
  patrón del nivel nuevo; el color nuevo crece desde el centro sobre el anterior en 300 ms
  (los textos cambian de color a mitad de camino, para no perder contraste ni un cuadro);
  cambian la línea "Nivel N de 3 · vibración …", el ritmo del pulso y la amplitud de la
  sacudida. Pulso, sacudida y ondas cuentan desde el **inicio del nivel**, igual que el
  patrón de vibración, para que la sacudida siga a los pulsos del motor.
- El tiempo de respuesta se cuenta desde que se abrió la alerta (no desde el último
  nivel) y se guarda con el **nivel máximo alcanzado** (`AlertRecord.maxLevel`).
- Medido en el simulador (consola de depuración): "sube al nivel 2 a los 6031 ms" y "al
  nivel 3 a los 12109 ms" en modo demo; la diferencia con 6 000 / 12 000 es el periodo
  del redibujo (50 ms hasta la 1.0.0; 67 ms desde la 1.1.0).

**Animaciones** (`AlertVisuals`, redibujo cada 67 ms, ≈ 15 cuadros/s, mientras la alerta se
ve; 100 ms con animaciones reducidas):

- **Entrada, 300 ms:** el color de la alerta crece desde el centro como un disco y el botón
  entra con un rebote de escala (easeOutBack, pico ≈ 108 %); los textos aparecen a la
  mitad, cuando el disco ya los cubre.
- **Pulso** (diseño web), onda triangular sin saltos: nivel 1, opacidad 1 → 0,72 → 1 en
  1,4 s; nivel 2, lo mismo en 0,7 s (hasta 0,88 por contraste, §2.2); nivel 3, rojo intenso
  → rojo oscuro en 0,5 s y de vuelta en 0,5 s. Las referencias del diseño muestran rojos
  intermedios, así que el cambio del nivel 3 es gradual, no un corte.
- **Ondas del ícono:** ver la tabla de arriba.
- **Sacudida:** el contenido se desplaza ±2/4/6 px cada cuadro (67 ms) **solo mientras el motor está
  encendido** (`VibePatterns.isOnAt`), así se ve el ritmo de la vibración aunque el reloj la
  tenga apagada.

**Luz y tono** (`Haptics`): `Attention.backlight(true)` en cada ráfaga (la excepción por
protección contra quemado se atrapa); un tono de 2,5 kHz por pulso con `ToneProfile` si el
reloj tiene `playTone` y los tonos activados, `TONE_ALERT_HI` si no hay `ToneProfile`, y nada
si no hay tonos. Sin vibración en el reloj (`vibrateOn` falso o sin motor) la alerta es solo
visual, con la misma pantalla, luz y tono.

**Al descartar** (botón o START): para la vibración, `popView` a la vista anterior (la
esfera), el puntaje sube a un mínimo de 70 y, si la abrió el detector, se guarda como
episodio de la guardia con su tiempo de respuesta y su nivel máximo (`AlertLog`, en memoria,
32 como mucho; se vacía al iniciar otra guardia). El detector no se reinicia, así que respeta su
refractario: en el escenario de inactividad, tras descartar, la siguiente alerta llegó a
los 10–11 s del evento anterior. Mientras la alerta está abierta los eventos nuevos se
ignoran y la esfera no se redibuja (`MainView` para su timer en `onHide` y
`GuardController` no pide redibujos). Pausar la guardia o cerrar la app con la alerta
abierta la cierra sin guardar respuesta.

#### Accesibilidad de la alerta

- **No depende de la vista:** el usuario puede tener los ojos cerrados. La vibración es el
  canal principal; la pantalla, la luz y el tono son refuerzos. Sin vibración, queda la
  alerta visual.
- **Fotosensibilidad:** el pulso más rápido es el del nivel 2 (0,7 s, ≈ 1,4 ciclos por
  segundo); el parpadeo del nivel 3 hace 1 ciclo por segundo. Todos quedan por debajo del
  límite de 3 destellos por segundo (WCAG 2.3.1) y cambian de forma gradual, sin cortes
  bruscos. Lo comprueban `alertPulseIsSlowerThanThreeHertz` (periodo ≥ 334 ms y menos de 9
  picos en 3 s), `alertPulseIsSmoothTriangle` y `alertLevelThreeFlashesEveryHalfSecond`. La
  sacudida es un desplazamiento de pocos píxeles, no un cambio de brillo.
- **Contraste** ≥ 4,5:1 en todo el ciclo del pulso (§2.2). El nivel también va en texto
  ("Nivel 2 de 3"), no solo en el color.
- **Objetivo táctil grande:** botón de 258×64 px con área de 280×86 px (≈ 22×7 mm), y
  START hace lo mismo.
- **Por qué BACK no descarta.** Alguien que se está durmiendo puede rozar BACK con la
  manga o la otra mano, o deslizar la pantalla sin querer; si eso cerrara la alerta, el
  aviso que debía despertarlo se apagaría sin que se entere. Descartar exige un gesto
  deliberado (el botón grande o START). BACK, deslizar, mantener UP y las teclas de página
  se consumen sin hacer nada; en la esfera BACK sigue saliendo de la app como siempre.

### 5.4 Aviso de fatiga (fase 9)

Con la fatiga en **Alto** ([DETECTOR.md](DETECTOR.md) §8) y la guardia activa, la esfera
reemplaza el puntaje y la píldora de estado por un aviso ámbar:

```
             12:06               hora
        DEMO · Inactividad       fecha / línea demo
  ╭──────────────────────────╮
  │  Micro-sueños repetidos  │   y ≈ 221  Inter SemiBold 15 px, AMBER
  │     descansa 15 min      │   y ≈ 240  Inter Medium 15 px, TEXT
  ╰──────────────────────────╯   caja 314×57 px (RoundLayout.fatigueBannerRect)
      [  Pausar guardia  ]       botón
```

- Caja `SURFACE` con borde `AMBER` de 2 px y esquinas de un tercio del alto. Va de 520 ‰ a
  665 ‰ del lado (y 202–259 en el fr165; hasta la 1.1.0, 275: el botón subió a y 265 en la
  fase 14), tan ancha como permite el círculo seguro en su borde inferior.
- Texto en dos ids (`FatigueBannerTitle`, `FatigueBannerAction`). La frase completa
  "toma un descanso de 15 min" **no cabía**: en `FONT_XTINY` mide más que los ≈ 290 px útiles
  a esa altura y se cortaba contra el borde (captura en el simulador). Quedó "descansa
  15 min" en español; en inglés "take a 15 min break" sí cabe. El texto original sigue en
  `FatigueRepeatedMicrosleeps` (guía de estilo).
- El anillo sigue mostrando el nivel de alerta: el porcentaje desaparece mientras dura el
  aviso, pero no la información.
- **Tocar el aviso** (`RoundLayout.hitsFatigueBanner`) abre el descanso guiado. El área
  táctil del botón grande se solapa 6 px con el borde inferior de la caja y tiene
  prioridad. Sin pantalla táctil, el menú tiene "Tomar descanso".
- Estático, sin animación (AMOLED: solo se encienden el borde y el texto).

### 5.5 Descanso guiado (fase 9)

`BreakView` (`source/views/BreakView.mc`), con la cuenta en `core/BreakTimer`:

| | En marcha | Terminado |
|---|---|---|
| Anillo | `ACCENT` desde las 12 en sentido horario, tan largo como lo que queda; pista `RING_TRACK`. Mismas medidas que el de la esfera. | vacío (solo la pista) |
| Centro | "Descanso" (`title`, secundario) · "14:59" (`clock`, Space Grotesk 76 px) · "BACK · cancelar" (`label`) | "Descanso terminado" (`title`) |
| Botón | — | "Reanudar guardia" (`ACCENT`, como "Iniciar guardia") |

- Dura **15 min** (30 s en modo demo). El reloj redondea hacia arriba: marca 15:00 al
  empezar y 0:01 en el último segundo. Redibujo cada 1 s.
- Mientras dura, la guardia está **suspendida**: sin fuente, detector, alertas ni guion,
  pero sin terminar (la actividad se sigue grabando y los episodios se conservan).
- Al llegar a cero: una vibración suave (`Haptics.notify`, el patrón del nivel 1 una sola
  vez) y la luz. El predictor de fatiga empieza a contar desde ese instante.
- START o un toque en el botón reanudan la guardia (que vuelve a calibrar). **BACK**
  cancela en cualquier momento y también reanuda; si se cancela antes de tiempo, la fatiga
  no se reinicia.

### 5.6 Resumen de la guardia e historial (fase 9)

`SummaryView` se abre sobre la esfera al **pausar** una guardia que duró **1 min o más o
tuvo algún episodio** (`GuardSummary.shouldShow`; una guardia de segundos sin episodios es
casi siempre un toque de prueba). START o BACK vuelven a la esfera.

```
         Resumen de la guardia        y 99   title, ACCENT  (o la fecha, en el detalle)
                ───                   raya de acento
   Duración             1 min 11 s    y 148
   Episodios                     3    y 181
   Respuesta media           1,9 s    y 214
   Nivel máximo             3 de 3    y 248
   Fatiga                     Alto    y 281  valor en cian / ámbar / rojo
                DEMO                  y 318  solo si la guardia fue en modo demo
```

- Las cinco filas comparten el ancho seguro de la más estrecha (la de "Fatiga"), así las
  dos columnas quedan alineadas; etiqueta en `body` y `TEXT_SECONDARY`, valor en `TEXT` con
  `Typography.valueFont` (cifras solas en JetBrains Mono 14 px, el resto en Inter SemiBold
  15 px).
- Formatos (`SummaryText`): duración "45 s", "1 min 32 s" (< 10 min), "47 min",
  "2 h 05 min"; respuesta con una décima y el separador del idioma ("1,9 s" / "1.9 s");
  "—" sin dato (sin respuestas o sin episodios).
- Episodios = alertas del detector, también las que se cerraron sin respuesta al pausar.
  Las de "Probar alerta" no cuentan.
- El mismo resumen se guarda en el **historial** (`SessionHistory`, las 10 últimas
  guardias, en `Application.Storage` con `HistoryStore`) también al salir de la app con la
  guardia activa, aunque entonces no se muestre.

**Historial** (menú principal → "Historial", subtítulo "3 guardias"): lista `Menu2` de la
más reciente a la más antigua, "14 nov · 10:32" con "1 min 11 s · 3 episodios" debajo.
Elegir una abre su detalle: la misma vista con la fecha como título. Al final, "Borrar
historial" pide confirmación (`WatchUi.Confirmation`, "¿Borrar el historial?"); con
"Confirmar" la lista queda en "Aún no hay guardias" y el subtítulo del menú se actualiza.

### 5.7 Funciones de dibujo

Funciones en `source/util/Draw.mc`:

| Componente | Función | Notas |
|---|---|---|
| Texto centrado | `Draw.centeredText` | Centrado en ambos ejes. |
| Texto con espaciado | `Draw.trackedText`, `Draw.trackedWidth` | Letra a letra con *n* px entre letras ("ALERTA"). |
| Anillo de progreso | `Draw.progressRing` | Pista completa en `BORDER` + avance con `drawArc` desde las 12 en punto en sentido horario, extremos redondos. Color del avance: `colorForAlertness`. |
| Píldora de estado | `Draw.statusPill` | Diseño web (fase 14): fondo de color sin borde, extremos redondos, alto y margen de `RoundLayout` (26 y 12 px), punto opcional delante (`dotColor`, 8 px) y, con `ping` entre 0 y 1, el ping del diseño web (`GuardVisuals`) mezclado con el fondo de la píldora. Devuelve su `Rect`. |
| Batería | `Draw.battery` | Cuerpo redondeado + borne, relleno proporcional al porcentaje. |
| Botón grande | `Draw.largeButton` | `fillRoundedRectangle` con extremos redondos. Cian con texto oscuro en la pantalla principal; blanco con texto oscuro en la alerta. El botón de la alerta es más grande (`RoundLayout.alertButtonRect`). Si el texto no cabe, reduce la fuente con `Draw.fittingFont` (escala de `Typography.smaller`). |
| Indicador de página | `Draw.pageDots` | Punto actual en `ACCENT`, el resto en `BORDER_STRONG`. |

`Draw.enableAntiAlias(dc)` activa el suavizado cuando el dispositivo lo soporta.

## 6. Accesibilidad

### Contraste

- Texto normal: **≥ 4,5:1**. Texto grande (titulares, números grandes): **≥ 3:1**.
- Todos los colores de texto sobre `BACKGROUND` cumplen 4,5:1 (el menor es `RED`, 6,5:1),
  y todos los textos de la alerta a pantalla completa también (el menor es 4,8:1).
- `BORDER` y `BORDER_STRONG` son decorativos: nunca llevan información por sí solos.
- Lo comprueban las pruebas: `tests/ContrastTest.mc` (textos de la esfera, píldoras,
  avisos, botón y todas las bandas del puntaje; mínimo 6,51:1) y `AlertVisualsTest` (la
  alerta en todo el ciclo del pulso).
- Contraste de la alerta: tabla de la sección 2.2.

### Áreas táctiles

- Mínimo **44 px** de alto y de ancho para cualquier área táctil
  (`RoundLayout.MIN_TOUCH`, `Rect.withMinSize`).
- El fr165 tiene 325 ppi (≈12,8 px por milímetro, dato de `simulator.json`), así que 44 px son solo
  ≈3,4 mm: es un **mínimo absoluto**, no un objetivo. Los controles principales usan
  áreas mucho mayores: el área táctil del botón grande es de 242×82 px (≈19×6 mm).
- El área táctil (`buttonTouchRect`) es más grande que el botón dibujado (`buttonRect`)
  para perdonar toques imprecisos con la mano en movimiento.
- Toda acción táctil tiene equivalente con botones físicos (START/STOP, BACK, UP/DOWN).
- En el fr165, **START y cualquier toque disparan primero el comportamiento `onSelect`**
  de `BehaviorDelegate`; solo si devuelve `false` llegan los eventos crudos: `onKey`
  (`KEY_ENTER`) para START y `onTap` (con coordenadas) para el toque. Verificado en la
  fase 4 con mensajes en consola: con `onSelect` devolviendo `true`, `onTap` nunca se
  llamaba. Por eso:
  - la esfera principal devuelve `false` en `onSelect` y decide en `onKey`/`onTap`, y solo
    un toque dentro de `buttonTouchRect` actúa (`RoundLayout.hitsButton`);
  - las vistas donde cualquier toque vale (guía de estilo, telemetría de depuración) pueden
    seguir usando `onSelect`.
- Coordenadas medidas: un toque en el centro del botón llega como (196, 308); uno sobre la
  hora, como (196, 166).

### No depender solo del color

- El nivel de alerta se muestra también como **porcentaje** y la sesión como **texto** en
  la píldora de estado.
- La alerta a pantalla completa incluye el nivel en texto ("Nivel 2 de 3") y, sobre todo,
  **vibración**: el usuario puede tener los ojos cerrados. Detalle y decisiones de
  accesibilidad de la alerta (fotosensibilidad, BACK) en la sección 5.3.

## 7. Textos

- Todos los textos visibles viven en `resources/strings/strings.xml` (inglés, por defecto)
  y `resources-spa/strings/strings.xml` (español), con el mismo `id`.
- Ids en inglés, con prefijo por grupo: `Status*`, `Button*`, `Label*`, `Alert*`,
  `Fatigue*`, `Break*`, `Summary*`, `History*`, `Duration*`, `Demo*`, `Menu*`, `Setting*`,
  `AiClass*`, `StyleGuide*`, `TypeRole*`.
- Mayúsculas solo en "¡DESPIERTA!" / "WAKE UP!" y en las etiquetas cortas de la esfera
  ("ALERTA" / "ALERT" y "DEMO"), que son rótulos pequeños, no frases.
- Formatos con valores (`PercentFormat`, `DateFormat`) viven también en los recursos: el
  español separa el `%` con un espacio ("88 %") y el inglés no ("88%"). Desde la fase 14 los
  porcentajes que se dibujan en JetBrains Mono (batería, puntaje y Modelo IA) van **sin
  espacio en los dos idiomas** (`PercentCompactFormat`, `ModelPercentFormat`), como el diseño
  web; `PercentFormat` queda para la depuración.
- Revisión final (fase 12) de todas las pantallas a 390×390 en ambos idiomas: en inglés se
  acortaron "Glance at watch" y "Long inactivity" (nombres de escenario, que en el submenú
  rozaban el borde redondo) y "max vibration".
- Abreviaturas de días y meses propias (`DateWeekdays`, `DateMonths`, listas separadas por
  comas): la esfera dice "Dom, 15 Nov" / "Sun, 15 Nov" y el historial "15 nov · 10:32" /
  "Nov 15 · 10:32" con letras que siempre tienen las fuentes, sea cual sea el idioma del
  sistema. `DateCase` (no visible) solo pasa a minúsculas el mes del historial en español.

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
