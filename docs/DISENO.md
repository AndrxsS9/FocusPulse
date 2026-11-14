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
4. **Sin animaciones continuas innecesarias.** El orbe IA, el arco de escaneo y el latido
   solo se animan con la guardia activa y la vista en primer plano (el timer se detiene en
   `onHide`); en pausa el orbe queda quieto y tenue. Ver la sección 5.2.
5. **Nada fijo durante mucho tiempo en la misma posición y a brillo alto** (quemado):
   la hora y el anillo cambian, y los elementos estáticos usan colores apagados.

## 2. Paleta

Constantes en `source/util/Palette.mc`. **Nunca** se escriben colores sueltos en el código.
Contraste calculado con la fórmula WCAG 2.x contra `BACKGROUND`.

| Token | Hex | Uso | Contraste sobre fondo |
|---|---|---|---|
| `BACKGROUND` | `0x07090C` | Fondo de todas las pantallas. | — |
| `SURFACE` | `0x11151B` | Relleno de píldoras y tarjetas pequeñas. | — |
| `BORDER` | `0x1C222B` | Pista del anillo de progreso (guía de estilo), separadores. | decorativo |
| `RING_TRACK` | `0x1A1F27` | Pista del anillo de nivel de la esfera principal (parte sin avance). | decorativo |

Los colores atenuados del orbe, el arco y el halo no son tokens nuevos: se calculan con
`ColorMath.blend(token, BACKGROUND, opacidad)` a partir de los tokens de esta tabla.
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

El fondo además late (pulso de brillo, §5.3): `alertPulseColor` oscurece los niveles 1 y 2
como mucho un 12 % y lleva el nivel 3 hasta un rojo oscuro (`RED_INTENSE` al 60 % sobre
`BACKGROUND`, calculado con `ColorMath.blend`, sin token nuevo). El contraste del texto en el
punto más oscuro sigue por encima de 4,5:1: 6,69:1 (nivel 1), 4,96:1 (nivel 2) y 9,59:1
(nivel 3, que gana contraste al oscurecerse). Lo comprueba
`alertPulseColorsKeepTextReadable` en 11 puntos del pulso.

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
| Hora (`timeY`) | 335 ‰ | 130 |
| Fecha (`dateY`) | 470 ‰ | 183 |
| "ALERTA" + porcentaje (`scoreY`) | 558 ‰ | 217 |
| Píldora de estado (`pillY`) | 648 ‰ | 252 |
| Botón grande (`buttonRect`) | arriba 720 ‰, alto 140 ‰ | x 82, y 280, 226×54 |
| Área táctil del botón (`buttonTouchRect`) | botón + 30 ‰ por lado | x 71, y 269, 248×76 |
| Indicador de página (`footerY`) | 905 ‰ | 352 |

En la fase 4 la hora subió (de 420 ‰ a 335 ‰) para dejar sitio a la fecha, y el porcentaje
y la píldora se acercaron para que quede aire entre la píldora y el botón. La anatomía
completa de la esfera está en la sección 5.1.

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

### 5.1 Anatomía de la esfera principal (fase 4)

`MainView` (`source/views/MainView.mc`), revisada en el simulador del fr165 y del fr165m
en español e inglés. Medidas reales en el fr165 (390×390):

```
                 ╭────── anillo de alerta (r 183, 11 px) ──────╮
              ╭──┤          ▭ 50 %                 y 50       ├──╮   batería
            ╱   │                                              │   ╲
           │    │          11:06                   y 130       │    │  hora (orbe IA detrás)
           │    │       vie 13 nov                 y 183       │    │  fecha / "DEMO · Normal"
           │    │     ALERTA 88 %                  y 217       │    │  puntaje
           │    │  ( • Guardia activa )            y 232–272   │    │  píldora
            ╲   │  [  Pausar guardia  ]            y 280–334   │   ╱   botón
              ╰─┤                                              ├─╯
                 ╰──────────────────────────────────────────────╯
```

| Zona | Contenido | Fuente / tamaño | Color |
|---|---|---|---|
| Anillo | Pista completa + avance desde las 12 en sentido horario, `percent` = puntaje. Extremos redondos. | trazo de 11 px, r 183 | pista `RING_TRACK`; avance `colorForAlertness(puntaje)` |
| Batería (`topY` 50) | Ícono dibujado (27×14 px, borne a la derecha, relleno proporcional) + porcentaje real de `System.getSystemStats().battery`. | `LABEL` (30 px) | `TEXT_SECONDARY`; `RED` con ≤ 15 % |
| Hora (`timeY` 130) | `HH:MM` en 24 h si el sistema la usa (`is24Hour`), si no `H:MM` en 12 h sin a. m./p. m. | `TIME` (109 px de caja) | `TEXT` |
| Fecha (`dateY` 183) | Día de la semana, día y mes abreviados por el sistema: "vie 13 nov" (español, en minúsculas) / "Fri Nov 13" (inglés). | `LABEL` | `TEXT_SECONDARY` |
| Puntaje (`scoreY` 217) | "ALERTA" + porcentaje, centrados juntos con 7 px de separación. | `LABEL` + `FONT_SMALL` (45 px) | etiqueta `TEXT_SECONDARY`; número del color del anillo |
| Píldora (`pillY` 252) | "Monitoreo en pausa" / "Guardia activa" (con punto delante; "Calibrando…" mientras el detector aprende la línea base, 30 s o 5 s en demo) / "Sensor no disponible". 40 px de alto. | `LABEL` | `TEXT_SECONDARY` / `ACCENT` / `AMBER`; relleno `SURFACE`, borde `BORDER_STRONG` |
| Botón (`buttonRect`) | "Iniciar guardia" o "Pausar guardia"; `fittingFont` baja de `BODY` si no cabe ("Iniciar guardia" va en `FONT_TINY`). | `BODY` → `TINY` | inicio: `ACCENT` con texto `BACKGROUND`; pausa: `SURFACE` + borde `BORDER_STRONG`, texto `TEXT` |
| Línea del modo demo (`dateY` 183, fase 8) | Con el modo demo activo reemplaza a la fecha: "DEMO · Tecleo activo" o, con el guion, "Guion 2/5 · Tecleo activo". Nombres cortos (`DemoShort*`) para que quepa en los ≈ 335 px de esa altura en ambos idiomas; en `footerY` solo había ≈ 130 px. | `LABEL` | `ACCENT` |
| Aviso breve (centro, fase 8) | 1,5 s al cambiar de escenario con DOWN ("Escenario / Tecleo activo"). (Hasta la fase 8 también salía "Guion automático / Completado" al terminar el guion; desde la fase 9 el guion termina en el resumen de la guardia.) Caja de esquinas redondas centrada en la pantalla; el valor baja de `BODY` hasta que cabe ("Inactividad prolongada"). Tapa la fecha y el puntaje mientras dura. | `LABEL` + `BODY` → `XTINY` | relleno `SURFACE`, borde `ACCENT`, título `TEXT_SECONDARY`, valor `TEXT` |

**Orden de dibujo:** fondo → orbe IA y partículas → anillo de alerta y arco de escaneo →
contenido. Ver la sección 5.2.

**Refresco:** un `Timer` redibuja cada 1000 ms en pausa y cada 83 ms con la guardia activa
(`REFRESH_PAUSED_MS` / `REFRESH_ACTIVE_MS`); se detiene en `onHide` y se reanuda en `onShow`
(verificado en el simulador con *Settings > Force onHide / Force onShow*). El puntaje no
depende del timer: lo actualiza cada lote de telemetría.

**Entrada:** START (`onKey`, `KEY_ENTER`) y un toque dentro de `buttonTouchRect` inician o
pausan la guardia; un toque en cualquier otra parte no hace nada. Ver la sección 6.

**AMOLED:** el único relleno claro es el botón "Iniciar guardia" (226×54 px); con la guardia
activa el botón pasa a `SURFACE`, así que durante la guardia no queda ningún relleno claro.

### 5.2 Orbe IA (fase 5)

El "orbe IA" detrás de la hora muestra de un vistazo cómo ve la app al usuario: su
**color** sigue el puntaje de alerta y su **velocidad** sigue lo que está haciendo.

**Forma.** 3 anillos delgados (2 px) de forma orgánica, no círculos: cada uno es la curva
polar `r(θ) = R · (1 + a1·sin(2θ + φ1) + a2·sin(3θ + φ2))` muestreada en 36 puntos
(`OrbModel.POINTS`). Los anillos giran a velocidades distintas (24, −36 y 16 °/s; el del
medio al revés) y sus fases φ avanzan, así que la forma "respira". Alrededor, 16 partículas
titilan con una onda de brillo desfasada entre ellas (ángulo áureo). El cálculo vive en
`source/core/OrbModel.mc` y usa `TrigTable` (senos precalculados): ni un `Math.sin` por cuadro.

**Estados** (`OrbModel.stateFor`, por orden de prioridad). Desde la fase 6 los decide la
clase ganadora del clasificador de estado ([DETECTOR.md](DETECTOR.md) §5), no reglas
sobre la varianza:

| Estado | Cuándo | Velocidad | Qué representa |
|---|---|---|---|
| Pausa | Guardia en pausa. | 0 (quieto) | Nadie vigila: orbe tenue (opacidad × 0,45), partículas fijas al 30 %. |
| Activo | Clase Activo (tecleo, gestos). | 2× | Mucha actividad: gira el doble y las partículas titilan más rápido. |
| Somnoliento | Clase Cabeceo o Inerte. | 0,35× (cámara lenta) | "Se está durmiendo": cayó el brazo o la muñeca dejó de moverse. |
| Somnoliento | Puntaje < 60. | 0,35× | El puntaje ya entró en la banda ámbar o roja. |
| Normal | El resto. | 1× | Movimiento tranquilo. |

La actividad alta tiene prioridad sobre un puntaje bajo: si el usuario vuelve a moverse,
el orbe se acelera enseguida aunque el puntaje todavía esté subiendo.

**Color.** `AlertnessColors.orbPalette(puntaje)`, exterior → interior: cian / cian claro /
violeta (≥ 60), ámbar / naranja / violeta (35–59), rojo / rojo intenso / naranja (< 35).
El anillo exterior siempre coincide con el anillo de alerta. Las partículas usan el
segundo color.

**Transparencia.** El fr165 no tiene `Dc.setStroke` ni `Dc.setFill` en tiempo de ejecución
(el simulador da *Symbol Not Found* aunque `compiler.json` marque `alphaBlendingSupport`).
Por eso la opacidad (60 %, 45 % y 35 % por anillo; hasta 70 % en las partículas) se
precalcula mezclando el color con el fondo (`ColorMath.blend`). Sobre `BACKGROUND` el
resultado es idéntico a un trazo con alfa.

**Posición.** Centro 9 px por debajo de la hora y radio de 85 px (88 % de `orbRadius`), así
que el orbe va de y ≈ 55 a y ≈ 225: no toca la batería y queda detrás de la hora, la fecha
y el puntaje. Con esas opacidades la hora (`TEXT`, 18,6:1) sigue leyéndose sin esfuerzo.
Las partículas van en el hueco entre el círculo seguro del contenido y el anillo de alerta
(radio ≈ 173 px), lejos de cualquier texto.

**Arco de escaneo.** Con la guardia activa, un arco de 15° cian (3 tramos: la cabeza al 55 %
de opacidad y la cola desvaneciéndose) gira en sentido horario por dentro del anillo de
alerta, una vuelta cada 3 s. Indica que la app está vigilando.

**Latido.** El punto de la píldora "Guardia activa" emite un halo que crece de 1 a 2,5 veces
su radio y se desvanece, cada 1,6 s.

**Refresco y rendimiento.** Con la guardia activa se redibuja cada 83 ms (≈12 cuadros/s);
en pausa, una vez por segundo con el orbe quieto. `MainView.ANIMATIONS_ENABLED = false`
apaga orbe, arco y latido (para el futuro ajuste "Animaciones reducidas"). En depuración,
`FrameStats` escribe en la consola cada 5 s los cuadros por segundo reales, el tiempo de
dibujo y el estado del orbe. Medido en el simulador (fr165 y fr165m): 12,2–13,4 cuadros/s
con la guardia activa y 7–12 ms de dibujo medio; ver `PENDIENTES.md`.

### 5.3 Alerta a pantalla completa (fase 7)

`AlertView` (`source/views/AlertView.mc`) se apila sobre la esfera con `pushView` cuando el
detector emite un cabeceo o una inactividad, y solo se cierra con "Estoy despierto". La
lógica vive en `core` (`AlertController`, `VibePatterns`, `AlertVisuals`, `AlertLog`) y la
vibración en `source/platform/Haptics.mc`.

**Anatomía** (fr165, revisada en español e inglés en el simulador):

```
                       ((▯))                      y ≈ 70   ícono de vibración
                   ¡DESPIERTA!                    y 125    ALERT (FONT_LARGE, fittingFont)
          Nivel 1 de 3 · vibración suave          y ≈ 170  LABEL
         Cabeceo / pérdida de tono                         LABEL, partido en dos líneas
                    muscular                               si no cabe
             [   Estoy despierto   ]              y 261–325 botón 258×64 px
```

| Zona | Contenido | Notas |
|---|---|---|
| Fondo | `alertPulseColor(nivel, pulso)` | Naranja / naranja intenso / rojo intenso que late (§2.2). La única pantalla con fondo claro: dura segundos. |
| Ícono | Contorno de un reloj y dos ondas (arcos de ±35°) a cada lado que crecen de 21 a 38 px de radio y se desvanecen hacia el fondo, desfasadas medio periodo (1,2 s). | Del color del texto. |
| Título | "¡DESPIERTA!" / "WAKE UP!" | `FONT_LARGE` cabe en ambos idiomas; `Draw.fittingFont` lo bajaría si no. |
| Nivel | "Nivel N de 3 · vibración suave/media/máxima" (`AlertLevelLineFormat`). | La vibración va en minúsculas porque sigue al punto medio. "Nivel 3 de 3 · vibración máxima" mide ≈ 357 px y "Level 3 of 3 · maximum vibration" ≈ 373 px: más que la cuerda segura (340 px) pero dentro de la pantalla, que aquí no tiene anillo. |
| Motivo | "Cabeceo / pérdida de tono muscular" o "Inactividad prolongada". | `fitTextToArea` en dos líneas cuando no cabe en una. |
| Botón | "Estoy despierto" / "I'm awake": `TEXT` con texto `BACKGROUND`. | `RoundLayout.alertButtonRect`, 258×64 px (el de la esfera es 226×54); el texto cabe en `BODY`. Área táctil 280×86 px (`alertButtonTouchRect`). |

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
  nivel 3 a los 12109 ms" en modo demo; la diferencia con 6 000 / 12 000 es el periodo de
  50 ms del redibujo.

**Animaciones** (`AlertVisuals`, redibujo cada 50 ms mientras la alerta se ve):

- **Entrada, 300 ms:** el color de la alerta crece desde el centro como un disco y el botón
  entra con un rebote de escala (easeOutBack, pico ≈ 108 %); los textos aparecen a la
  mitad, cuando el disco ya los cubre.
- **Pulso de brillo:** onda triangular sin saltos, de 2,4 / 1,8 / 1,2 s según el nivel.
- **Sacudida:** el contenido se desplaza ±2/4/6 px cada 50 ms **solo mientras el motor está
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
- **Fotosensibilidad:** el pulso de brillo va a menos de **1 ciclo por segundo** (el más
  rápido, 1,2 s en el nivel 3), lejos del límite de 3 destellos por segundo (WCAG 2.3.1),
  y cambia de forma gradual, sin destellos bruscos; el rojo saturado, que es el caso más
  delicado, es justo el más lento de los dos extremos que alterna. Lo comprueban
  `alertPulseIsSlowerThanThreeHertz` (periodo ≥ 334 ms y menos de 9 picos en 3 s) y
  `alertPulseIsSmoothTriangle`. La sacudida es un desplazamiento de pocos píxeles, no un
  cambio de brillo.
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
  │  Micro-sueños repetidos  │   y ≈ 220  LABEL, AMBER
  │     descansa 15 min      │   y ≈ 250  LABEL, TEXT
  ╰──────────────────────────╯   caja 300×72 px (RoundLayout.fatigueBannerRect)
      [  Pausar guardia  ]       botón
```

- Caja `SURFACE` con borde `AMBER` de 2 px y esquinas de un tercio del alto. Va de 520 ‰ a
  705 ‰ del lado (y 203–275 en el fr165), tan ancha como permite el círculo seguro en su
  borde inferior.
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
| Centro | "Descanso" (`LABEL`, secundario) · "14:59" (`NUMBER`, 88 px) · "BACK · cancelar" | "Descanso terminado" (`BODY`) |
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
         Resumen de la guardia        y 99   LABEL, ACCENT  (o la fecha, en el detalle)
                ───                   raya de acento
   Duración             1 min 11 s    y 148
   Episodios                     3    y 181
   Respuesta media           1,9 s    y 214
   Nivel máximo             3 de 3    y 248
   Fatiga                     Alto    y 281  valor en cian / ámbar / rojo
                DEMO                  y 318  solo si la guardia fue en modo demo
```

- Las cinco filas comparten el ancho seguro de la más estrecha (la de "Fatiga"), así las
  dos columnas quedan alineadas; etiqueta en `TEXT_SECONDARY`, valor en `TEXT`.
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
| Anillo de progreso | `Draw.progressRing` | Pista completa en `BORDER` + avance con `drawArc` desde las 12 en punto en sentido horario, extremos redondos. Color del avance: `colorForAlertness`. |
| Píldora de estado | `Draw.pill` | Relleno `SURFACE`, borde `BORDER_STRONG`, texto de color. Devuelve su `Rect`; `Draw.pillHeight` da su alto antes de dibujarla, para colocar el resto alrededor. |
| Píldora con punto | `Draw.statusPill` | Igual que `pill`, con un punto del color del texto delante (guardia activa) y, con `pulse` entre 0 y 1, el halo del latido. |
| Batería | `Draw.battery` | Cuerpo redondeado + borne, relleno proporcional al porcentaje. |
| Botón grande | `Draw.largeButton` | `fillRoundedRectangle` con extremos redondos. Cian con texto oscuro en la pantalla principal; blanco con texto oscuro en la alerta. El botón de la alerta es más grande (`RoundLayout.alertButtonRect`). Si el texto no cabe, reduce la fuente con `Draw.fittingFont`. |
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
  español separa el `%` con un espacio ("88 %") y el inglés no ("88%").
- `DateCase` no es un texto visible: `lower` (español) pasa a minúsculas el día y el mes que
  da el sistema ("Vie", "Nov" → "vie", "nov"); `keep` (inglés) los deja igual.

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
