# Guía de la demo — sustentación

Paso a paso para presentar FocusPulse AI en el simulador del **Forerunner 165** con la
**compilación de release** (la misma app que se publica, sin menú de depuración). Todo lo
que aparece aquí se probó en el simulador del SDK 9.3.0, en español y en inglés, el
2026-11-13 (fase 8) y el 2026-11-14 (fase 9: escalamiento, fatiga, descanso, resumen e
historial; fase 11: ajustes, confirmación por IA y transición entre escenarios) y el
2026-11-15 (fase 12, versión 1.0.0: aviso sin datos del sensor, alerta sobre menús y
desplazamiento anti quemado; fase 13B, versión 1.1.0: animaciones del diseño web; fase 14,
versión 1.2.0: fuentes propias, fecha siempre visible y etiqueta del escenario de 2 s; las
dos con el guion automático completo en release en los dos idiomas; fase 15, versión 1.2.1:
controles táctiles, arranque directo con `run.ps1 -DemoAuto` y recorrido completo **solo con
toques**, en los dos idiomas).

> **¿Los botones dibujados no responden?** Toda la demo se puede hacer solo con clics en la
> pantalla, o sin tocar nada con `run.ps1 -Release -DemoAuto`. Ver
> [Si los botones no responden](#si-los-botones-no-responden).

Duración recomendada: **10–12 minutos** (unos 6 de demo en vivo y el resto de explicación).

## 1. Antes de empezar

### Abrir el simulador

Desde la raíz del repo, en PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run.ps1 -Release
```

- Compila `bin\FocusPulse-release.prg` (modo release, `-r`), abre el simulador si no está
  abierto y carga la app en el `fr165`. Si el simulador ya está abierto, lo reutiliza.
- **Arranque directo en la demo** (versión 1.2.1):

  | Comando | Al abrir la app |
  |---|---|
  | `scripts\run.ps1 -Release` | Normal: guardia en pausa; el modo demo, como se dejó la última vez. |
  | `scripts\run.ps1 -Release -Demo` | **Modo demo ya activo** (punto cian junto a la batería), guardia en pausa. |
  | `scripts\run.ps1 -Release -DemoAuto` | Modo demo y, **a los 3 s, el guion automático solo** (paso 4). Al terminar se queda en el resumen; **un toque** vuelve a la esfera. |

  Funciona como si se cambiaran los ajustes desde Garmin Connect: antes de abrir la app,
  `run.ps1` escribe *Iniciar en modo demo* y *Guion automático al abrir* en el archivo de
  ajustes del simulador (`%TEMP%\com.garmin.connectiq\GARMIN\APPS\SETTINGS\*.SET`), sin
  tocar el resto de ajustes. Sin `-Demo` ni `-DemoAuto` los deja apagados, así que cada
  ejecución de `run.ps1` hace lo que dice su comando. Los dos ajustes también están en el
  reloj: *Ajustes > Abrir en demo* y *Guion al abrir* (se aplican la próxima vez que se
  abra la app).
- La consola queda ocupada mientras la app corre; es normal. En release la app no escribe
  nada en ella.
- Para volver a cargar la app sin recompilar: `scripts\run.ps1 -Release -NoBuild`.
- **No ejecutes `scripts\test.ps1` justo antes de presentar**: las pruebas reemplazan la
  app en el simulador y lo dejan sin reloj ("CIQ Simulator" sin dispositivo). Si pasa,
  vuelve a ejecutar `run.ps1 -Release`.

### Controles: botón, teclado o toque

Cada acción se puede hacer de tres maneras. En el simulador, **"toque" es un clic sobre la
pantalla redonda** y **"deslizar" es arrastrar con el botón del ratón pulsado** (rápido, unos
100 px o más). Los botones del reloj se pulsan en las **pestañas grises del borde de la
caja**, no en los rótulos impresos del bisel (ver
[Si los botones no responden](#si-los-botones-no-responden)).

| Acción | Botón del fr165 | Teclado del PC (simulador) | Toque |
|---|---|---|---|
| Iniciar o pausar la guardia | START | **5** del teclado numérico | Tocar el botón grande ("Iniciar guardia") |
| **Abrir el menú principal** | Mantener UP ~1,5 s | **M** | **Tocar la batería o la hora** (franja de arriba), o mantener pulsada la pantalla |
| Moverse por un menú | UP / DOWN | **8** / **2** numérico | Deslizar hacia arriba o hacia abajo |
| Elegir una opción del menú | START | **5** numérico | Tocar la opción (no hace falta enfocarla antes) |
| Volver (menús, submenús) | BACK | **Esc** | Deslizar a la derecha |
| Escenario **siguiente** (modo demo) | DOWN, con la guardia en marcha | **2** numérico (guardia en marcha) o **4** numérico | **Deslizar a la izquierda** (también en pausa) |
| Escenario **anterior** (modo demo) | — | **6** numérico | **Deslizar a la derecha** en la esfera |
| Responder la alerta ("Estoy despierto") | START | **5** numérico | Tocar "Estoy despierto" |
| Cerrar el resumen, Modelo IA o Acerca de | START o BACK | **5** numérico o **Esc** | Tocar en cualquier parte |
| Abrir el descanso (fatiga en Alto) | Menú → *Tomar descanso* | — | Tocar el aviso ámbar |
| Salir de la app | BACK | **Esc** | Deslizar a la derecha **sin** el modo demo |

- En la esfera, **tocar la hora nunca inicia la guardia**: solo el botón grande lo hace.
- Con el **modo demo**, deslizar a la derecha en la esfera cambia de escenario y **no sale
  de la app**; el botón BACK (o Esc) sí sale. Sin el modo demo, deslizar a la derecha sale,
  como en el reloj.
- La alerta **no se cierra** con BACK, Esc ni deslizando: solo con "Estoy despierto"
  (toque, START o 5 numérico).
- LIGHT no está definido en el fr165 del simulador: no hace nada.
- Teclado: el teclado numérico necesita **Bloq Num activado** (con Bloq Num apagado, el 8 y
  el 2 son flechas y no hacen nada). Haz clic una vez en la ventana del simulador para que
  reciba las teclas. Las flechas, Enter y Retroceso **no** hacen nada en el fr165. La barra
  espaciadora a veces genera un toque en el centro de la pantalla: no dependas de ella.

### Comprobaciones (2 minutos antes)

- [ ] Idioma del simulador: *Settings > Language > Spanish (spa)* (o *English (eng)* si se
      presenta en inglés). Solo aparece la lista completa con la app cargada.
- [ ] *Settings > Vibrate* marcado (si no, la alerta sigue, pero solo visual, con luz y tono).
- [ ] La esfera en pausa: "Monitoreo en pausa" y botón "Iniciar guardia".
- [ ] Ventana del simulador grande y visible para el público (arrástrala por la barra de
      título; el reloj escala con la ventana).
- [ ] El modo demo se recuerda entre arranques. Si en la esfera hay un **punto cian junto a
      la batería**, está activo; si no, está apagado. Para la demo
      conviene empezar **apagado** y encenderlo delante del profesor (paso 2).
- [ ] *Ajustes* (tocar la hora o mantener UP → *Ajustes*): **Sensibilidad Media, Vibración Normal,
      Confirmar IA activado**, Animaciones *Completas*. Son los valores con que se midió
      esta guía; con otra sensibilidad cambian los tiempos de la inactividad.
- [ ] *Historial* (tocar la hora o mantener UP): si tiene guardias de ensayos que no quieres enseñar,
      bórralo ahora (*Borrar historial* → *Confirmar*). Las guardias de la demo se irán
      guardando solas.

## 2. Orden recomendado

> En todos los pasos, cada botón tiene su equivalente táctil (tabla de §1): **mantener UP** =
> tocar la batería o la hora (o la tecla M); **START** = tocar el botón grande, la opción del
> menú o "Estoy despierto"; **BACK** = deslizar a la derecha en los menús; **DOWN** en la
> esfera = deslizar a la izquierda. El recorrido completo se probó así, solo con toques.

### Paso 1 — La esfera (30 s)

**Qué hacer:** nada; la app está en pausa.

**Qué decir:** "Esta es la esfera de guardia. El anillo del borde y el porcentaje son el
nivel de alerta, de 0 a 100. Detrás está el orbe IA, los tres contornos del diseño web: en
pausa queda quieto y al 30 %. Todo es casi negro porque la pantalla es AMOLED: cada píxel
negro está apagado."

### Paso 2 — Activar el modo demo (45 s)

**Qué hacer:** mantener **UP** → se abre el menú *FocusPulse AI*. Con el foco en *Modo
demo*, pulsar **START**: el interruptor pasa a verde, el subtítulo cambia de "Sensor real"
a "Datos simulados" y aparecen *Escenario*, *Guion automático* y *Probar alerta* (después
vienen *Historial*, *Modelo IA* y *Acerca de*; con la guardia activa, también *Tomar
descanso*). Pulsar
**BACK** para volver a la esfera: junto a la batería aparece un **punto cian** (modo demo);
la fecha sigue a la vista.

*Solo con toques:* **tocar la hora** abre el menú; **tocar *Modo demo*** cambia el
interruptor; **deslizar a la derecha** vuelve a la esfera.

**Qué decir:** "El simulador no tiene muñeca, así que el modo demo reemplaza el
acelerómetro por una fuente simulada con cinco escenarios. También acorta los tiempos:
la calibración pasa de 30 a 5 segundos y la inactividad prolongada de 60 a 8. El resto
del código, detector, clasificador y alertas, es exactamente el mismo que con el sensor
real. El modo queda guardado aunque cierre la app."

### Paso 3 — Guardia y escenarios a mano (2–3 min)

**Qué hacer:**

1. **START**: "Calibrando…" durante 5 s, luego "Guardia activa". El botón se enmarca en cian
   un momento, el orbe gira y se deforma, las partículas titilan, el arco de escaneo da
   vueltas, el punto de la píldora hace "ping" y los dos puntos de la hora parpadean.
2. **DOWN** → durante 2 s, en el sitio de la fecha, "DEMO · Tecleo activo". Esperar
   ~10 s: el puntaje sube y el orbe gira al doble (ciclos de 4,5 / 6 / 7,5 s).
3. **DOWN** → "Simular cabeceo". A los **~8 s** aparece la alerta naranja "¡DESPIERTA!
   Nivel 1 de 3 · vibración suave — Cabeceo / pérdida de tono muscular" (el detector ve la
   caída a los ~6 s y el modelo la confirma 2 s después). Responder con **START** ("Estoy
   despierto").
4. **DOWN** → "Inactividad prolongada". A los **~10 s** (1,5 s en que el brazo pasa de
   colgar a la postura inerte y 8 s de quietud), alerta "Inactividad prolongada".
   Responder con **START**. Desde la fase 11 ya **no** llega un cabeceo de más al cambiar:
   la fuente simulada desliza la postura en vez de saltar.
5. **DOWN** → "Mirar la hora". Cada 12 s la muñeca gira rápido y se queda 6 s leyendo con el
   brazo sostenido. Esperar un ciclo o dos: **no llega ninguna alerta** y la guardia sigue
   en "Guardia activa".
6. **DOWN** → vuelve a "Movimiento normal".

*Solo con toques:* tocar **Iniciar guardia**; **deslizar a la izquierda** en lugar de DOWN
(siguiente escenario; deslizar a la derecha vuelve al anterior); tocar **Estoy despierto**
para responder. A diferencia de DOWN, deslizar también cambia el escenario con la guardia en
pausa.

**Qué decir:**

- *Tecleo:* "Mucho movimiento, sacudidas fuertes, pero nunca seguidas de quietud: el
  detector no lo confunde con un cabeceo y el clasificador lo ve como Activo."
- *Cabeceo:* "El cabeceo necesita tres señales a la vez: una sacudida de más de 400 mg, la
  quietud antes de 5 segundos y que el brazo haya cambiado de postura más de 35 grados.
  Cada señal descarta un falso positivo distinto. Además, el modelo entrenado lo confirma:
  dos segundos después, si todavía ve movimiento normal, no despierta a nadie." (Detalle en
  [DETECTOR.md](DETECTOR.md) §3.7.)
- *Alerta:* "La alerta ocupa toda la pantalla, vibra por pulsos, enciende la luz y suena.
  Solo se cierra respondiendo: BACK no la cierra, para no apagarla dormido. El tiempo de
  respuesta queda registrado."
- *Inactividad:* "Si el brazo queda inmóvil el tiempo configurado, también alerta. En la
  vida real son 60 segundos."
- *Mirar la hora:* "Este es el caso difícil: un giro rápido y luego el brazo quieto con la
  muñeca inclinada se parece a un cabeceo. En los datos de prueba, justo después de
  teclear, las reglas solas lo tomaban por cabeceo 15 de 24 veces; con la confirmación del
  modelo, 3 de 24, sin perder ningún cabeceo real." (Ver [IA.md](IA.md) §12.)

Al terminar, **START** para pausar la guardia.

### Paso 4 — Guion automático (≈ 1 min 15 s, sin tocar casi nada)

**Qué hacer:** con la guardia en pausa, mantener **UP** (o tocar la hora) → **DOWN** dos
veces hasta *Guion automático* (subtítulo "Iniciar") → **START** (o tocar *Guion
automático*). El menú se cierra, la guardia arranca y la línea de la esfera muestra el paso.
**Sin tocar nada:** abrir la app con `scripts\run.ps1 -Release -DemoAuto` (§1): a los 3 s el
guion arranca solo.

| Paso | Línea de la esfera | Dura | Qué pasa |
|---|---|---|---|
| 1/6 | Guion 1/6 · Normal | 10 s | Calibra los primeros 5 s. |
| 2/6 | Guion 2/6 · Tecleo activo | 10 s | El puntaje sube. |
| 3/6 | Guion 3/6 · Cabeceo | hasta responder | Alerta de cabeceo a los ~8 s (6 s del detector + 2 s de la confirmación). **El guion espera**: responde con START cuando termines de explicar. |
| 4/6 | Guion 4/6 · Normal | 8 s | Empieza al responder. |
| 5/6 | Guion 5/6 · Inactividad | hasta responder | Alerta de inactividad a los ~10 s. Responde con START. |
| 6/6 | Guion 6/6 · Inactividad | ≈ 26 s | **No respondas.** Alerta a los ~10 s; sube al **nivel 2** a los 6 s (naranja intenso, "Nivel 2 de 3 · vibración media") y al **nivel 3** a los 12 s (rojo que parpadea con rojo oscuro cada 0,5 s, "vibración máxima"), sin cerrarse. 4 s después el guion termina. |
| fin | **Resumen de la guardia** | — | La guardia se pausa sola y se abre el resumen: ≈ 1 min 11 s, 3 episodios, respuesta media, nivel máximo **3 de 3**, fatiga **Alto**, DEMO. **Se queda ahí** hasta que START o **un toque en cualquier parte** vuelvan a la esfera. |

En total ≈ **75 s** más lo que tardes en responder las dos primeras alertas (medido en la
fase 11: 1 min 15 s en español y 1 min 14 s en inglés respondiendo cada una en ≈ 2,3 s;
alertas a los 28, 48 y 58 s). Si nadie responde en los pasos 3 y 5, el guion no avanza
solo.

**Qué decir:**

- *Pasos 1–5:* "Para que el recorrido sea reproducible hay un guion automático. Cada paso
  cambia el escenario simulado; los pasos de alerta esperan a que yo responda, igual que
  esperaría el reloj a que el usuario despierte."
- *Paso 6:* "Ahora no respondo, como si el usuario siguiera dormido. A los 6 segundos la
  alerta sube al nivel 2, cambia el patrón de vibración y el color, y a los 12 llega al 3,
  la vibración casi continua. En el reloj real son 10 y 20 segundos. El nivel 3 se queda
  hasta que alguien responda."
- *Resumen:* "Al terminar la guardia queda su resumen: cuánto duró, cuántos micro-sueños,
  cuánto tardé en responder, el nivel más alto al que llegó la alerta y la fatiga. Con tres
  episodios en cinco minutos y una alerta en nivel 3, la fatiga es Alta. Se guarda en el
  historial."

**Cancelar:** mantener UP (o tocar la hora) → *Guion automático* (subtítulo "Detener · paso
N/6") → START; o pausar la guardia con START o tocando el botón (se ve el resumen de lo que
haya hasta ahí); o DOWN / deslizar (pasa al control manual).

Medido en la fase 15 con `run.ps1 -Release -DemoAuto`, respondiendo con toques: resumen de
**1 min 14 s** en español y **1 min 16 s** en inglés (3 episodios, nivel máximo 3 de 3, fatiga
Alto / High).

### Paso 5 — Fatiga y descanso guiado (≈ 1 min 30 s)

**Qué hacer:**

1. **START** (iniciar guardia) y **DOWN** tres veces hasta "Inactividad prolongada".
2. Responde con **START** cada alerta (llegan cada ~10 s). Tras la **tercera**, en lugar del
   puntaje y la píldora aparece el aviso ámbar **"Micro-sueños repetidos / descansa
   15 min"**.
3. **DOWN** una vez (pasa a "Mirar la hora", que no da alertas) y,
   enseguida, **toca el aviso** (clic sobre él). Se abre el **descanso**: anillo cian que
   se vacía y cuenta regresiva de **0:30** (15:00 en el reloj real). Sin pantalla táctil:
   mantener UP → *Tomar descanso*.
4. Al llegar a cero: vibración suave, "Descanso terminado" y el botón **"Reanudar
   guardia"** → **START**. La guardia vuelve a calibrar y el aviso ya no está.
5. **START** para pausar: el resumen muestra los episodios y la fatiga **Bajo** (el descanso
   completo la reinició).

**Qué decir:** "La app no solo despierta: también lleva la cuenta. Un predictor por reglas
mira los episodios: uno o dos en la última media hora es fatiga moderada, tres o más es
alta. También sube si las respuestas son cada vez más lentas o si una alerta llegó al nivel
3. Con fatiga alta recomienda un descanso de 15 minutos; mientras dura, la guardia se
suspende, y al volver la cuenta empieza de cero. BACK cancela el descanso." (Reglas en
[DETECTOR.md](DETECTOR.md) §8.)

> Si se te adelanta otra alerta antes de tocar el aviso, respóndela primero: DOWN no hace
> nada con una alerta abierta.

### Paso 6 — Historial (45 s)

**Qué hacer:** mantener **UP** → **DOWN** hasta *Historial* (subtítulo "N guardias") →
**START**. La lista muestra las guardias de la más reciente a la más antigua ("14 nov ·
12:02" y "1 min 11 s · 3 episodios"). **START** sobre una abre su detalle (el mismo
resumen, con la fecha de título); **BACK** vuelve. Al final de la lista, *Borrar historial*
pide confirmación.

**Qué decir:** "Se guardan las últimas diez guardias en el almacenamiento del reloj, con
tamaño fijo para no gastar memoria. Si los datos guardados estuvieran dañados o fueran de
otra versión de la app, se descartan sin romper nada."

> Para la sustentación conviene **no** borrar el historial delante del público: deja las
> guardias de los pasos anteriores a la vista. Si hace falta limpiarlo antes de empezar,
> hazlo en las comprobaciones previas.

### Paso 7 — Los tres niveles de alerta (1 min, opcional)

**Qué hacer:** mantener **UP** → *Probar alerta* (tercer ítem bajo el interruptor) →
**START** → elegir *Nivel 1 de 3*, *Nivel 2 de 3* o *Nivel 3 de 3* con DOWN y **START**.
La alerta se abre sobre la esfera; **START** la cierra y vuelve a la esfera. Repetir con
los otros niveles.

**Qué decir:** "Los Forerunner no pueden variar la fuerza del motor, así que los niveles
se distinguen por el patrón: el 1 son dos pulsos cortos cada 3 segundos, el 2 tres pulsos
más largos cada 2 y el 3 es casi continuo. El color también sube: naranja, naranja intenso
y rojo." (Ver [DISENO.md](DISENO.md) §5.3.) Una alerta de prueba de nivel 1 o 2 también
escala si no se responde, aunque la guardia esté en pausa.

> La vibración **no se ve en el simulador** (ni la ventana ni el reloj se mueven). Lo que sí
> se ve: la sacudida de la propia alerta, que sigue el mismo patrón que el motor, y el
> indicador de luz de la barra de estado, que pasa de "☀ Off" a "☀ Default".

### Paso 7 bis — Ajustes (1 min, opcional)

**Qué hacer:** mantener **UP** → *Ajustes* (subtítulo "Sensibilidad: Media"). Cada ítem
muestra su valor: *Sensibilidad* y *Vibración* abren una lista con el valor actual
marcado; *Sonido*, *Animaciones*, *Confirmar IA* y *Grabar actividad* son interruptores.
Para enseñar el aviso de seguridad: *Vibración* → *Apagada* y apagar *Sonido*: se abre
**"Alerta solo visual"** y el subtítulo pasa a "Apagada · solo visual". **Después vuelve a
dejar Vibración Normal y Sonido activado.**

**Qué decir:** "Los mismos ajustes se cambian desde la app Garmin Connect del teléfono y se
aplican sin reiniciar la guardia. La sensibilidad cambia los umbrales del detector; la
vibración, el número y la duración de los pulsos, porque el motor del Forerunner no cambia
de fuerza. Si la alerta quedara sin vibración ni sonido, la app lo avisa: dormido nadie
mira la pantalla."

> En el simulador, *File > Edit Persistent Storage > Edit Application.Properties data* abre
> el editor de ajustes (el equivalente a Garmin Connect) si la app se cargó con `run.ps1`.

### Paso 8 — Modelo IA y Acerca de (45 s)

**Qué hacer:** mantener **UP** → **DOWN** hasta *Modelo IA* (subtítulo "v2", el penúltimo) →
**START**. Se ve el tipo de modelo, la versión, la exactitud, los falsos cabeceos y "Entrenado
con datos sintéticos". **BACK** vuelve al menú; **DOWN** → *Acerca de* → **START**; **BACK**
dos veces para volver a la esfera.

**Qué decir (Modelo IA):** "El clasificador es una regresión logística de cuatro clases
entrenada en Python y exportada a Monkey C: 24 números, sin librerías en el reloj. Lo
entrenamos con datos sintéticos generados a partir de los mismos patrones del simulador,
con 48 usuarios distintos y casos difíciles como mirar la hora. Separamos los usuarios de
prueba para no hacer trampa. Estos porcentajes comparan versiones con datos simulados: no
son la precisión en una muñeca real, que se medirá con datos del reloj." (Detalle en
[IA.md](IA.md).)

**Qué decir (Acerca de):** nombre, versión 1.2.1 y la frase de la app.

*Solo con toques:* tocar una opción del menú la abre directamente; *Modelo IA*, *Acerca de*
y el detalle de una guardia del historial se cierran con **un toque en cualquier parte**;
los menús, deslizando a la derecha.

### Paso 9 — Volver al sensor real (30 s)

**Qué hacer:** mantener **UP** → **START** sobre *Modo demo* (subtítulo "Sensor real"). Los
ítems de la demo desaparecen. **BACK**: desaparece el punto cian. Si la guardia estaba activa, se
reinicia sola con el acelerómetro real (puntaje a 88 y "Calibrando…"); a los 5 s sin lotes
la píldora pasa a **"Sin datos del sensor"** (ámbar).

**Qué decir:** "Fuera del modo demo la app lee el acelerómetro real a 25 Hz, calibra 30
segundos y la inactividad salta a los 60. En el simulador no hay muñeca: el acelerómetro
del simulador no entrega datos por sí solo, y la app lo avisa: «Sin datos del sensor». Un
corte así nunca cuenta como inactividad. En el reloj esto es lo que corre."

Para terminar, **START** (pausar) y **BACK** (salir).

## 3. Si algo falla

| Síntoma | Qué hacer |
|---|---|
| Mantener UP no abre el menú | **Toca la batería o la hora**, o pulsa **M** en el teclado. Si quieres usar el botón: mantén el clic ~1,5 s **sobre la pestaña del borde izquierdo** (no sobre el rótulo "UP") sin mover el ratón. Ver [Si los botones no responden](#si-los-botones-no-responden). |
| Ningún botón dibujado responde | Haz clic en las **pestañas grises del borde de la caja**, no en los rótulos impresos. O usa toques y deslizamientos (§1, tabla de controles) o el teclado. |
| DOWN no cambia de escenario | Solo funciona con el **modo demo activo y la guardia en marcha**. En pausa no hace nada (a propósito). Deslizar a la izquierda o a la derecha funciona también en pausa. |
| Deslizar a la derecha cerró la app | Pasa **sin el modo demo** (es el gesto de volver, como en el reloj). Con el modo demo activo cambia de escenario. Vuelve a abrir con `run.ps1 -Release -NoBuild`. |
| El cabeceo no dispara la alerta | Espera ~8 s desde que se eligió (la confirmación del modelo añade 2 s). Si había otra alerta hace menos de 10 s, el refractario la bloquea: espera o vuelve a elegir *Escenario > Simular cabeceo* (repite el cabeceo desde el principio). Si *Confirmar IA* está activado y la sensibilidad es Alta, revisa que no sea *Mirar la hora*: ahí el modelo descarta el cabeceo a propósito. |
| La alerta no vibra ni suena, o dice "sin vibración" | *Ajustes*: *Vibración* en *Apagada* o *Sonido* apagado (y "Alerta solo visual" al iniciar la guardia). Vuelve a Normal / activado. |
| El editor de ajustes del simulador dice "No settings file found" | Carga la app con `scripts\run.ps1` (copia la definición de los ajustes al simulador) y vuelve a abrir el editor. |
| El guion "se queda" en el paso 3 o 5 | Está esperando a que respondas la alerta: pulsa START. Si no hay alerta en pantalla, espera ~10 s (refractario) o cancélalo desde el menú y vuelve a iniciarlo. |
| En el paso 6 respondí la alerta sin querer | No pasa nada: el guion termina igual y muestra el resumen, pero sin el nivel 3. Repite el guion para enseñar el escalamiento. |
| No aparece el resumen al pausar | La guardia duró menos de 1 min y no tuvo episodios: a propósito no se muestra ni se guarda. |
| El aviso de fatiga no aparece | Hacen falta 3 episodios en 5 min (modo demo) con la guardia activa. Las alertas de *Probar alerta* no cuentan. Tras un descanso completo la cuenta vuelve a empezar. |
| Tocar el aviso no abre el descanso | Toca el centro de la caja ámbar, no el botón de abajo. O usa mantener UP → *Tomar descanso*. |
| "Calibrando…" no termina o sale "Sin datos del sensor" | Estás con el **sensor real** (sin "DEMO" en la esfera): el simulador no entrega datos. Activa el modo demo. |
| Llegó una alerta con un menú abierto | Es normal: la alerta cierra los menús y se abre sobre la esfera; al responder vuelves a la esfera. |
| La app aparece en inglés (o en español) | *Settings > Language* con la app cargada, y luego `run.ps1 -Release -NoBuild`: los textos se cargan al abrir la app y no cambian hasta volver a abrirla. Si el clic en el idioma no se aplica (el punto sigue en el anterior), repítelo. |
| El simulador muestra "CIQ Simulator" sin reloj | Se ejecutaron las pruebas o se cerró la app: `scripts\run.ps1 -Release -NoBuild`. El modo demo sigue como estaba. |
| El simulador se cerró con un error | Ocurre si la app termina con una guardia **grabando** y no se pausó antes. Vuelve a abrirlo con `run.ps1 -Release -NoBuild`. Para salir, pausa primero (START) y luego BACK. |
| Aparece el menú *Debug* o la guía de estilo | Se cargó la compilación de depuración. Vuelve a `run.ps1 -Release`. |
| No se nota la vibración | Es normal en el simulador (ver el paso 5). La consola de la compilación de depuración escribe cada ráfaga. |

## 4. Si los botones no responden

**Qué pasaba** (diagnóstico de la fase 15, con la traza de entrada de la compilación de
depuración, `InputTrace`, que escribe en la consola cada evento que llega a la app):

- **La app no pierde los botones.** La esfera es la vista inicial con su delegado
  (`MainDelegate`) y nunca se sustituye; cada pantalla que se abre encima trae el suyo. Con
  la traza, cada pulsación de las pestañas del borde llega a la app: UP → `previousPage`,
  DOWN → `nextPage`, START → `onSelect` + `onKey ENTER`, BACK → `onBack` + `onKey ESC`.
- **Las zonas activas del simulador son solo las pestañas grises del borde de la caja**
  (definidas en el `simulator.json` del fr165: UP ocupa 40 × 79 px en el borde izquierdo).
  Un clic en los **rótulos impresos del bisel** no pulsa nada: sobre "UP" no hace nada, y
  sobre "DOWN", "START", "BACK" o "LIGHT" el simulador lo convierte en un **toque en la
  pantalla** (fuera del círculo). Era la causa más probable de que "no respondieran".
- **Mantener UP** depende de que el simulador vea el botón del ratón **pulsado de verdad**
  ~1,5 s sobre la pestaña: si el clic cae en el rótulo o el ratón se mueve, solo llega un UP
  corto (o nada). La tecla **M** abre el menú sin mantener nada.
- **LIGHT** no está definido en el fr165 del simulador.
- Las **flechas, Enter y Retroceso** del teclado no hacen nada en el fr165: el simulador usa
  el teclado numérico.

**Qué hacer**, de más a menos sencillo:

1. **Sin tocar nada:** `scripts\run.ps1 -Release -DemoAuto` (guion automático a los 3 s; al
   final, un toque vuelve a la esfera).
2. **Solo toques** (tabla de §1): tocar la hora → menú; tocar opciones; deslizar a la
   izquierda o derecha → escenario; tocar "Estoy despierto"; deslizar a la derecha → volver.
3. **Teclado:** M (menú), Esc (BACK), y con Bloq Num: 5 (START), 8 (UP), 2 (DOWN), 4 y 6
   (deslizar a la izquierda y a la derecha).
4. **Botones dibujados:** clic en las pestañas grises del borde de la caja, no en los
   rótulos.

Para ver qué recibe la app: `scripts\run.ps1` (sin `-Release`) y mirar la consola; cada
evento sale como `ENTRADA esfera: toque (195, 115) a los … ms`. Si un clic no deja ninguna
línea `ENTRADA`, el simulador no lo entregó a la app.

## 5. Referencias

- Algoritmo del detector y matriz de confusión: [DETECTOR.md](DETECTOR.md).
- Entrenamiento del clasificador, métricas v1/v2 y limitaciones: [IA.md](IA.md).
- Diseño de la esfera, la alerta y el aviso: [DISENO.md](DISENO.md).
- Lo que está confirmado y lo que falta probar en el reloj real: [PENDIENTES.md](PENDIENTES.md).
