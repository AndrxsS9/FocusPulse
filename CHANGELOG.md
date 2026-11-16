# Changelog

Cambios de FocusPulse AI por fase. La versión sigue el esquema *mayor.fase.parche*
(`AppInfo.VERSION`): la fase N es la 0.N.0, la fase 12 cierra la 1.0.0, la fase 13B
(animaciones del diseño web) es la 1.1.0, la fase 14 (fuentes propias) es la 1.2.0 y la
fase 15 (demo solo con toques) es la 1.2.1.
`AppInfo` existe
desde la fase 8; las versiones anteriores son la numeración retroactiva de cada fase.
Detalle de cada módulo en `docs/ARQUITECTURA.md` (local) y de lo verificado
en `docs/PENDIENTES.md` (local).

## 1.2.1 — Fase 15: demo controlable sin botones físicos (2026-11-15)

- **Diagnóstico** de "los botones dibujados no responden": la app no pierde el delegado (la
  esfera es la vista inicial y nunca se sustituye) y recibe cada botón que el simulador
  entrega. Las zonas activas del simulador son solo las pestañas del borde de la caja; un
  clic en los rótulos impresos del bisel no pulsa nada o llega como un toque en la
  pantalla, y *mantener UP* necesita el botón del ratón pulsado de verdad ~1,5 s sobre la
  pestaña. Mapa de teclado del simulador medido: M (menú), Esc (BACK), y con Bloq Num 5
  (START), 8 (UP), 2 (DOWN), 4 y 6 (deslizar); las flechas y Enter no hacen nada.
- **Traza de entrada** solo en depuración (`InputTrace`): cada tecla pulsada o soltada,
  comportamiento, toque, pulsación larga y deslizamiento de la esfera, la alerta, el resumen
  y el descanso sale en la consola (`ENTRADA esfera: …`). En release no hace nada.
- **Controles táctiles** en la esfera, además de los botones: **tocar la batería o la hora**
  abre el menú (`RoundLayout.menuZoneRect`, 390×156 px dentro del círculo; nunca inicia la
  guardia), **mantener pulsada la pantalla** también, y **deslizar a la izquierda o a la
  derecha** pasa al escenario siguiente o al anterior con el modo demo (también en pausa).
  Deslizar a la derecha llega como `onBack`, igual que el botón BACK; `BackSource` (core) los
  distingue por el evento de tecla, así que con el modo demo el gesto cambia de escenario y
  el botón sigue saliendo de la app.
- **Cerrar con un toque** el resumen de la guardia, Modelo IA y Acerca de (`InfoDelegate`).
  Los menús ya se elegían con toque (Menu2): verificado en todos.
- **Arranque directo en la demo**: ajustes nuevos *Iniciar en modo demo* y *Guion automático
  al abrir* (apagados por defecto; en el reloj, *Abrir en demo* y *Guion al abrir*).
  `DemoLaunch` (core) decide: el primero abre con el modo demo activo; el segundo, además,
  arranca el guion automático a los 3 s si nadie tomó el control antes. Al terminar el guion
  se queda en el resumen; un toque vuelve a la esfera.
- **`scripts\run.ps1 -Demo` y `-DemoAuto`**: escriben esos dos ajustes en el archivo de
  ajustes del simulador (`GARMIN\APPS\SETTINGS\*.SET`, formato medido y documentado en
  `_common.ps1`) antes de instalar la app, conservando el resto; sin ellos los dejan
  apagados.
- 14 pruebas nuevas (245): escenario anterior y regla de deslizar, zona del menú (también
  frente a los rótulos del bisel), `BackSource`, `DemoLaunch` y los ajustes guardados.

## 1.2.0 — Fase 14: fuentes propias y detalles de la esfera (2026-11-15)

- **Fuentes propias en mapa de bits** (BMFont con antialias, `resources/fonts/`), las del
  diseño web, con licencia SIL OFL 1.1 (textos en `resources/fonts/LICENSES/`, créditos en
  el README): Space Grotesk Bold para la hora (76 px, dígitos y ":"), "¡DESPIERTA!" (42 px,
  solo sus letras y las de "WAKE UP!") y los títulos (22 px); Inter Medium y SemiBold 13 y
  15 px, Bold 18 px y ExtraBold 22 px para textos y botones; JetBrains Mono SemiBold 14 y
  22 px para las cifras. 11 fuentes con solo los glifos necesarios.
- **`scripts\make_fonts.ps1`** (+ `make_fonts.py`, Python de `ml\.venv`): instancia cada peso
  de las TTF variables oficiales de google/fonts (`assets/fonts/`) con fontTools, dibuja los
  glifos con Pillow, usa los avances exactos de la fuente más el espaciado medido en las
  referencias (hora −2 px, título de la alerta −0,4 px) y escribe `.fnt`, `.png` y
  `fonts.xml`. Reproducible; `-Check` comprueba los caracteres de `strings.xml`.
- **`Typography`** carga las fuentes una vez al arrancar y define los roles `clock`,
  `alertTitle`, `title`, `body`, `bodyStrong`, `label`, `labelStrong`, `button`,
  `alertButton`, `number` y `numberSmall`; `Draw.fittingFont` baja por su escala
  (`Typography.smaller`) y `Typography.valueFont` pone las cifras solas en JetBrains Mono.
- **Esfera** con las medidas del diseño web (a 1–2 px de la referencia): batería con ícono
  de 22×12 y "78%" en JetBrains Mono 14 px #C9D1DB (`TEXT_SOFT`); hora en Space Grotesk 76;
  fecha "Dom, 15 Nov" / "Sun, 15 Nov" en Inter Medium 15 px con abreviaturas propias
  (`DateWeekdays`, `DateMonths`) y **siempre visible**; "ALERTA" con espaciado y "85%" en
  JetBrains Mono 22 px alineados por la línea base; píldora de 26 px sin borde, fondo
  `PILL` #1A1F27 en pausa y `PILL_ACTIVE` #0F2A36 (cian tenue) con la guardia activa, punto
  gris o cian claro con su ping y texto Inter SemiBold 13 px; botón en Inter Bold 18 px en
  y 265.
- **Modo demo**: el nombre del escenario ("DEMO · Tecleo activo" o el paso del guion) sale
  2 s en el sitio de la fecha al pulsar DOWN o al cambiar de paso el guion (antes, una caja
  de 1,5 s y la línea fija en lugar de la fecha); el modo se marca con un punto cian de 5 px
  junto a la batería.
- **Alerta**: "¡DESPIERTA!" en Space Grotesk 42, nivel en Inter SemiBold 15, motivo en una
  línea en Inter Medium 13, botón de 250×70 en Inter ExtraBold 22; ícono, título, nivel,
  motivo y botón en las posiciones de la web. Colores, pulsos, ondas y contraste sin cambios
  (el nivel 2 sigue en 0,88).
- **Pantallas propias** (Modelo IA, Resumen, Descanso, Acerca de, aviso solo visual, aviso
  de fatiga): títulos en Space Grotesk, textos en Inter y cifras en JetBrains Mono. Los
  `Menu2` nativos siguen con la fuente del sistema.
- Porcentajes sin espacio en los dos idiomas donde van en JetBrains Mono
  (`PercentCompactFormat`, `ModelPercentFormat` en español).
- Memoria pico del recorrido completo en el simulador: 104,2 → **110,7 kB** de 763,6 kB.
  `FocusPulse-release.prg` 128,5 kB; `FocusPulse.iq` 257,7 kB.
- Comparaciones nuevas en `docs/img/comparacion-esfera.png`, `comparacion-guardia.png` y
  `comparacion-alertas.png`, y las 20 capturas de la tienda rehechas. Guion automático
  completo en release en español e inglés. 231 pruebas.

## 1.1.0 — Fase 13B: estados animados iguales al diseño web (2026-11-15)

- **Orbe IA del diseño web**: 3 contornos de Bézier (A, B, C) muestreados una vez en 48
  puntos y centrados en la pantalla, con rotación y escala no uniforme por fotogramas clave
  (A 0→360°, B al revés, C 40→400°). Ciclo por estado: activo 4,5 / 6 / 7,5 s, normal
  9 / 12 / 15 s, somnoliento 22 / 28 / 34 s y congelado en pausa; opacidad general 1 / 0,9 /
  0,75 / 0,3. Paletas de la web por puntaje (tokens nuevos `AMBER_LIGHT` y `RED_LIGHT`).
- **Partículas**: 16 en un anillo de radio 150, radios de 2,2 y 1,6 px, colores de la
  paleta en rotación; titilan de 0,1 a 1 en 2,4 s (1,2 s activo, 4,8 s somnoliento).
- **Arco de escaneo** (cian al 55 %, radio 164, 16°, 2,8 s por vuelta), **ping** del punto
  de "Guardia activa" (1× → 2,6×, 0,8 → 0 en 1,6 s) y **dos puntos de la hora** que
  parpadean cada segundo entre 1 y 0,25 (`GuardVisuals`).
- **Botón de 220×60** (radio 30): "Pausar guardia" sobre #1C222B y borde cian de 2 px
  mientras tiene el foco: 1,5 s tras START, un toque, UP o DOWN (`ButtonFocus`).
- **Alertas como la web**: nivel 1 #FF8A1F y nivel 2 #FF5A1F con texto negro, pulso hacia
  negro en 1,4 s y 0,7 s; nivel 3 #E01E1E ↔ #6A0000 cada 0,5 s con texto blanco; ícono
  circular con dos ondas de 3 px (1× → 1,25× en 1,1 s); botón blanco con borde y texto
  negros en los tres niveles; título en `FONT_MEDIUM` y bloque más centrado. El pulso del
  nivel 2 se queda en 0,88 (no 0,72) porque al 0,72 el texto bajaría a 3,81:1.
- **Rendimiento**: la alerta pasa de 20 a ≈ 15 cuadros/s; la esfera, 12 con la guardia
  activa y 1 en pausa. Dibujo medio medido en el simulador: 3–7 ms (esfera) y 1–2 ms
  (alerta). Con *Animaciones reducidas* el orbe queda congelado y sin partículas.
- Comparaciones con el diseño web en `docs/img/comparacion-guardia.png` y
  `docs/img/comparacion-alertas.png`; referencias en `docs/img/referencia/`. Guion
  automático completo en release, en español e inglés. 226 pruebas.

## 1.0.0 — Fase 12: pulido final (2026-11-15)

- **Sin datos del sensor**: tras más de 5 s sin lotes del acelerómetro con la guardia
  activa, la píldora pasa a "Sin datos del sensor" (ámbar) y se quita sola al volver los
  datos; la quietud vuelve a contar desde cero, así que un corte no dispara inactividad
  (`SensorWatchdog`, `DrowsinessDetector.onDataGap`).
- **Alerta sobre menús**: una alerta que llega con un menú o submenú abierto los cierra
  (`ViewUnwinder`, una vista cada 50 ms) y se abre sobre la esfera; al responder se vuelve a
  ella. La vibración arranca en el primer cuadro de la alerta para no pasar de 3 timers.
- **Anti quemado AMOLED**: la esfera se desplaza cada minuto por un ciclo de 9 posiciones
  (±2 px, media cero) con `PixelShift` y `RoundLayout.shiftTo`.
- Revisión de textos en 390×390 (es/en): "Glance at watch", "Long inactivity" y "max
  vibration" acortados en inglés. Pruebas de contraste ≥ 4,5:1 (mínimo 6,51:1).
- Sin código muerto; trazas solo en depuración; auxiliares de pruebas y pesos v1 fuera de
  release (`.prg` de release 88,6 → 86,9 kB).
- Material de tienda (`docs/STORE.md`, 20 capturas), guía de sustentación, README final y
  este changelog. Memoria pico 98,8 de 763,6 kB (fr165 y fr165m). 205 pruebas.

## 0.11.0 — Fase 11: ajustes y confirmación por IA (2026-11-14)

- Ajustes en el reloj y en Garmin Connect: sensibilidad (Baja/Media/Alta), vibración por
  pulsos (Apagada/Suave/Normal/Fuerte), sonido, animaciones reducidas, confirmación por IA y
  grabar actividad, aplicados sin reiniciar la guardia (`onSettingsChanged`).
- Aviso "Alerta solo visual" si no habría vibración ni sonido.
- **Confirmación del cabeceo por el modelo**: espera 2 lotes y exige p(Normal) < 0,35;
  falsos al mirar la hora 15 → 3 de 24 sin perder cabeceos (`ml/confirmation.py`).
- Transición suave entre escenarios de la demo. 194 pruebas.

## 0.10.0 — Fase 10: IA entrenada (2026-11-14)

- Pipeline en Python (`ml/`, `scripts\train.ps1`): dataset sintético de 48 usuarios con
  negativos difíciles, características idénticas al reloj, división por usuario y
  validación cruzada agrupada, regresión logística, informe v1/v2 y exportación a Monkey C.
- Pesos v2: exactitud 89,7 % → 93,3 %, falsos cabeceos 16 → 12 de 48.
- Pantalla *Modelo IA* y escenario *Mirar la hora*. 172 pruebas.

## 0.9.0 — Fase 9: escalamiento, fatiga e historial (2026-11-14)

- La alerta sin respuesta sube del nivel 1 al 3 (cada 10 s; 6 s en demo).
- Predictor de fatiga por reglas, aviso "Micro-sueños repetidos" y descanso guiado.
- Resumen de la guardia al pausar e historial de las 10 últimas en Storage, con borrado
  confirmado. Guion automático con escalamiento. 167 pruebas.

## 0.8.0 — Fase 8: modo demo (2026-11-13)

- Menú principal (mantener UP, también en release): modo demo, escenario, guion
  automático, probar alerta y acerca de. DOWN cambia de escenario con un aviso breve.
- Configuración de la demo persistente y `AppInfo.VERSION`. 142 pruebas.

## 0.7.0 — Fase 7: alerta háptica (2026-11-13)

- Alerta a pantalla completa "¡DESPIERTA!" con vibración por pulsos (el FR165 no cambia la
  fuerza), luz y tono; entrada, pulso < 1 Hz y sacudida sincronizada con el motor.
- "Estoy despierto" mide el tiempo de respuesta; BACK no la cierra. 124 pruebas.

## 0.6.0 — Fase 6: detector y clasificador v1 (2026-11-13)

- Inclinación por gravedad, detector de cabeceos (sacudida + quietud + inclinación) e
  inactividad, línea base adaptativa, refractario de 10 s.
- Clasificador softmax de 4 clases con pesos a mano (v1). 100 pruebas.

## 0.5.0 — Fase 5: orbe IA (2026-11-13)

- Orbe animado de 3 anillos y 16 partículas detrás de la hora, arco de escaneo y latido a
  ≈ 12 cuadros/s. 74 pruebas.

## 0.4.0 — Fase 4: esfera principal (2026-11-13)

- Anillo de nivel de alerta, batería, hora, fecha, porcentaje, píldora de estado y botón
  de guardia con hit-testing. 57 pruebas.

## 0.3.0 — Fase 3: telemetría (2026-11-13)

- Acelerómetro real a 25 Hz y fuente simulada con escenarios, búfer circular, ventana
  deslizante (varianza, sacudida, quietud), motor de telemetría y grabación de la guardia
  como actividad. 42 pruebas.

## 0.2.0 — Fase 2: sistema de diseño (2026-11-12)

- Paleta de tokens, tipografía, layout redondo en proporciones, utilidades de dibujo,
  textos es/en, ícono y guía de estilo oculta. 20 pruebas.

## 0.1.0 — Fase 1: base del proyecto (2026-11-12)

- Manifest (`watch-app`, fr165/fr165m), jungle, estructura, vista inicial, delegado,
  scripts de setup, build, run, test y export, y documentación inicial.
