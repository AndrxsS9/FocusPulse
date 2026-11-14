# Guía de la demo — sustentación

Paso a paso para presentar FocusPulse AI en el simulador del **Forerunner 165** con la
**compilación de release** (la misma app que se publica, sin menú de depuración). Todo lo
que aparece aquí se probó en el simulador del SDK 9.3.0, en español y en inglés, el
2026-11-13.

Duración recomendada: **8–10 minutos** (unos 5 de demo en vivo y el resto de explicación).

## 1. Antes de empezar

### Abrir el simulador

Desde la raíz del repo, en PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run.ps1 -Release
```

- Compila `bin\FocusPulse-release.prg` (modo release, `-r`), abre el simulador si no está
  abierto y carga la app en el `fr165`. Si el simulador ya está abierto, lo reutiliza.
- La consola queda ocupada mientras la app corre; es normal. En release la app no escribe
  nada en ella.
- Para volver a cargar la app sin recompilar: `scripts\run.ps1 -Release -NoBuild`.
- **No ejecutes `scripts\test.ps1` justo antes de presentar**: las pruebas reemplazan la
  app en el simulador y lo dejan sin reloj ("CIQ Simulator" sin dispositivo). Si pasa,
  vuelve a ejecutar `run.ps1 -Release`.

### Botones del reloj en el simulador

Los botones se pulsan **con el ratón sobre el dibujo del reloj**, en el borde de la caja.
No se verificó ningún atajo de teclado: no dependas de ellos.

| Botón del fr165 | Dónde está en el simulador | Qué hace en FocusPulse |
|---|---|---|
| **START/STOP** | Arriba a la derecha (rótulo "START / STOP") | Inicia o pausa la guardia. En la alerta, "Estoy despierto". En los menús, elegir. |
| **BACK** | Abajo a la derecha (rótulo "BACK") | Volver en los menús. En la esfera, salir de la app (si la guardia está activa, antes la guarda). **No cierra la alerta.** |
| **UP** | En el centro del lado izquierdo (rótulo "UP") | Subir en los menús. **Mantenerlo pulsado ~1,5 s** (clic sostenido) abre el **menú principal**. |
| **DOWN** | Abajo a la izquierda (rótulo "DOWN") | Bajar en los menús. Con el modo demo y la guardia activa, **siguiente escenario** (aviso de 1,5 s). |
| LIGHT | Arriba a la izquierda | No se usa. |
| Toque | Clic sobre la pantalla | Un toque en el botón grande hace lo mismo que START; en la alerta, un toque en "Estoy despierto" la cierra. |

### Comprobaciones (2 minutos antes)

- [ ] Idioma del simulador: *Settings > Language > Spanish (spa)* (o *English (eng)* si se
      presenta en inglés). Solo aparece la lista completa con la app cargada.
- [ ] *Settings > Vibrate* marcado (si no, la alerta sigue, pero solo visual, con luz y tono).
- [ ] La esfera en pausa: "Monitoreo en pausa" y botón "Iniciar guardia".
- [ ] Ventana del simulador grande y visible para el público (arrástrala por la barra de
      título; el reloj escala con la ventana).
- [ ] El modo demo se recuerda entre arranques. Si en la esfera ya se ve "DEMO · …" en el
      sitio de la fecha, está activo; si se ve la fecha, está apagado. Para la demo
      conviene empezar **apagado** y encenderlo delante del profesor (paso 2).

## 2. Orden recomendado

### Paso 1 — La esfera (30 s)

**Qué hacer:** nada; la app está en pausa.

**Qué decir:** "Esta es la esfera de guardia. El anillo del borde y el porcentaje son el
nivel de alerta, de 0 a 100. Detrás de la hora está el orbe IA: en pausa queda quieto y
tenue. Todo es casi negro porque la pantalla es AMOLED: cada píxel negro está apagado."

### Paso 2 — Activar el modo demo (45 s)

**Qué hacer:** mantener **UP** → se abre el menú *FocusPulse AI*. Con el foco en *Modo
demo*, pulsar **START**: el interruptor pasa a verde, el subtítulo cambia de "Sensor real"
a "Datos simulados" y aparecen *Escenario*, *Guion automático* y *Probar alerta*. Pulsar
**BACK** para volver a la esfera: donde estaba la fecha ahora se lee **"DEMO · Normal"**.

**Qué decir:** "El simulador no tiene muñeca, así que el modo demo reemplaza el
acelerómetro por una fuente simulada con cuatro escenarios. También acorta los tiempos:
la calibración pasa de 30 a 5 segundos y la inactividad prolongada de 60 a 8. El resto
del código, detector, clasificador y alertas, es exactamente el mismo que con el sensor
real. El modo queda guardado aunque cierre la app."

### Paso 3 — Guardia y escenarios a mano (2–3 min)

**Qué hacer:**

1. **START**: "Calibrando…" durante 5 s, luego "Guardia activa". El orbe gira y el arco de
   escaneo da vueltas por dentro del anillo.
2. **DOWN** → aviso "Escenario / Tecleo activo" y la línea "DEMO · Tecleo activo". Esperar
   ~10 s: el puntaje sube y el orbe gira al doble.
3. **DOWN** → "Simular cabeceo". A los **~6 s** aparece la alerta naranja "¡DESPIERTA!
   Nivel 1 de 3 · vibración suave — Cabeceo / pérdida de tono muscular". Responder con
   **START** ("Estoy despierto").
4. **DOWN** → "Inactividad prolongada". A los **~8 s** de quietud, alerta "Inactividad
   prolongada". Responder con **START**.
5. **DOWN** → vuelve a "Movimiento normal".

**Qué decir:**

- *Tecleo:* "Mucho movimiento, sacudidas fuertes, pero nunca seguidas de quietud: el
  detector no lo confunde con un cabeceo y el clasificador lo ve como Activo."
- *Cabeceo:* "El cabeceo necesita tres señales a la vez: una sacudida de más de 400 mg, la
  quietud antes de 5 segundos y que el brazo haya cambiado de postura más de 35 grados.
  Cada señal descarta un falso positivo distinto." (Detalle en [DETECTOR.md](DETECTOR.md).)
- *Alerta:* "La alerta ocupa toda la pantalla, vibra por pulsos, enciende la luz y suena.
  Solo se cierra respondiendo: BACK no la cierra, para no apagarla dormido. El tiempo de
  respuesta queda registrado."
- *Inactividad:* "Si el brazo queda inmóvil el tiempo configurado, también alerta. En la
  vida real son 60 segundos."

Al terminar, **START** para pausar la guardia.

### Paso 4 — Guion automático (≈ 1 min, sin tocar casi nada)

**Qué hacer:** mantener **UP** → **DOWN** dos veces hasta *Guion automático* (subtítulo
"Iniciar") → **START**. El menú se cierra, la guardia arranca y la línea de la esfera
muestra el paso:

| Paso | Línea de la esfera | Dura | Qué pasa |
|---|---|---|---|
| 1/5 | Guion 1/5 · Normal | 10 s | Calibra los primeros 5 s. |
| 2/5 | Guion 2/5 · Tecleo activo | 10 s | El puntaje sube. |
| 3/5 | Guion 3/5 · Cabeceo | hasta responder | Alerta de cabeceo a los ~6 s. **El guion espera**: responde con START cuando termines de explicar. |
| 4/5 | Guion 4/5 · Normal | 8 s | Empieza al responder. |
| 5/5 | Guion 5/5 · Inactividad | hasta responder | Alerta de inactividad a los ~8 s. Responde con START. |
| fin | Aviso "Guion automático / Completado" y luego "DEMO · Normal" | — | La guardia sigue activa en movimiento normal. |

En total son unos **50 s** más lo que tardes en responder las dos alertas. Si nadie
responde, el guion no avanza solo (se probó con 15 s sin respuesta).

**Qué decir:** "Para que el recorrido sea reproducible hay un guion automático. Cada paso
cambia el escenario simulado; los pasos de alerta esperan a que yo responda, igual que
esperaría el reloj a que el usuario despierte."

**Cancelar:** mantener UP → *Guion automático* (subtítulo "Detener · paso N/5") → START; o
pausar la guardia con START; o DOWN (pasa al control manual). Al terminar, **START** para
pausar.

### Paso 5 — Los tres niveles de alerta (1 min)

**Qué hacer:** mantener **UP** → *Probar alerta* (tercer ítem bajo el interruptor) →
**START** → elegir *Nivel 1 de 3*, *Nivel 2 de 3* o *Nivel 3 de 3* con DOWN y **START**.
La alerta se abre sobre la esfera; **START** la cierra y vuelve a la esfera. Repetir con
los otros niveles.

**Qué decir:** "Los Forerunner no pueden variar la fuerza del motor, así que los niveles
se distinguen por el patrón: el 1 son dos pulsos cortos cada 3 segundos, el 2 tres pulsos
más largos cada 2 y el 3 es casi continuo. El color también sube: naranja, naranja intenso
y rojo." (Ver [DISENO.md](DISENO.md) §5.3.)

> La vibración **no se ve en el simulador** (ni la ventana ni el reloj se mueven). Lo que sí
> se ve: la sacudida de la propia alerta, que sigue el mismo patrón que el motor, y el
> indicador de luz de la barra de estado, que pasa de "☀ Off" a "☀ Default".

### Paso 6 — Acerca de (15 s)

**Qué hacer:** mantener **UP** → **DOWN** hasta *Acerca de* → **START**. **BACK** dos veces
para volver.

**Qué decir:** nombre, versión 0.8.0 y la frase de la app.

### Paso 7 — Volver al sensor real (30 s)

**Qué hacer:** mantener **UP** → **START** sobre *Modo demo* (subtítulo "Sensor real"). Los
ítems de la demo desaparecen. **BACK**: vuelve la fecha. Si la guardia estaba activa, se
reinicia sola con el acelerómetro real (puntaje a 88 y "Calibrando…").

**Qué decir:** "Fuera del modo demo la app lee el acelerómetro real a 25 Hz, calibra 30
segundos y la inactividad salta a los 60. En el simulador no hay muñeca: el acelerómetro
del simulador no entrega datos por sí solo, por eso se queda en Calibrando. En el reloj
esto es lo que corre."

Para terminar, **START** (pausar) y **BACK** (salir).

## 3. Si algo falla

| Síntoma | Qué hacer |
|---|---|
| Mantener UP no abre el menú | Mantén el clic más tiempo (~1,5 s) **sobre el botón UP**, no sobre el rótulo. Asegúrate de estar en la esfera (no en una alerta). Si la ventana no tenía el foco, el primer clic solo la activa: repite. |
| DOWN no cambia de escenario | Solo funciona con el **modo demo activo y la guardia en marcha**. En pausa no hace nada (a propósito). |
| El cabeceo no dispara la alerta | Espera ~6 s desde que se eligió. Si había otra alerta hace menos de 10 s, el refractario la bloquea: espera o vuelve a elegir *Escenario > Simular cabeceo* (repite el cabeceo desde el principio). |
| El guion "se queda" en el paso 3 o 5 | Está esperando a que respondas la alerta: pulsa START. Si no hay alerta en pantalla, espera ~10 s (refractario) o cancélalo desde el menú y vuelve a iniciarlo. |
| "Calibrando…" no termina | Estás con el **sensor real** (sin "DEMO" en la esfera): el simulador no entrega datos. Activa el modo demo. |
| La app aparece en inglés (o en español) | *Settings > Language* con la app cargada. |
| El simulador muestra "CIQ Simulator" sin reloj | Se ejecutaron las pruebas o se cerró la app: `scripts\run.ps1 -Release -NoBuild`. El modo demo sigue como estaba. |
| El simulador se cerró con un error | Ocurre si la app termina con una guardia **grabando** y no se pausó antes. Vuelve a abrirlo con `run.ps1 -Release -NoBuild`. Para salir, pausa primero (START) y luego BACK. |
| Aparece el menú *Debug* o la guía de estilo | Se cargó la compilación de depuración. Vuelve a `run.ps1 -Release`. |
| No se nota la vibración | Es normal en el simulador (ver el paso 5). La consola de la compilación de depuración escribe cada ráfaga. |

## 4. Referencias

- Algoritmo del detector y matriz de confusión: [DETECTOR.md](DETECTOR.md).
- Diseño de la esfera, la alerta y el aviso: [DISENO.md](DISENO.md).
- Lo que está confirmado y lo que falta probar en el reloj real: [PENDIENTES.md](PENDIENTES.md).
