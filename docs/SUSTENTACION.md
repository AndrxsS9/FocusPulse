# Guía de sustentación — FocusPulse AI 1.0.0

Guion de **13 minutos** (con 2 de margen hasta los 15), checklist previa, preguntas
probables del jurado y las cifras que conviene tener a mano. La demo en vivo sigue
[GUIA_DEMO.md](GUIA_DEMO.md); aquí solo se dice cuándo y qué contar.

## 1. Guion con tiempos

| # | Parte | Minutos | Acumulado |
|---|---|---|---|
| 1 | Problema | 1:00 | 0:00 – 1:00 |
| 2 | Por qué un reloj (FR165) | 1:00 | 1:00 – 2:00 |
| 3 | Diseño de interfaz | 2:00 | 2:00 – 4:00 |
| 4 | Arquitectura | 1:30 | 4:00 – 5:30 |
| 5 | Detector e IA | 2:00 | 5:30 – 7:30 |
| 6 | Demo en vivo (guion automático) | 3:00 | 7:30 – 10:30 |
| 7 | Pruebas y métricas | 1:00 | 10:30 – 11:30 |
| 8 | Limitaciones honestas | 1:00 | 11:30 – 12:30 |
| 9 | Trabajo futuro | 0:30 | 12:30 – 13:00 |

### 1. Problema (1:00)

- Estudiando o trabajando de noche aparecen los **micro-sueños**: segundos de sueño de los
  que uno no se da cuenta. El primer signo visible es el **cabeceo** y, con el brazo apoyado,
  la **inactividad** total.
- Las alarmas de siempre son por hora, no por estado. Queríamos algo que reaccione cuando
  te estás durmiendo, no a una hora fija.
- Decirlo claro desde el inicio: **no es un dispositivo médico** ni sustituye el descanso.

### 2. Por qué un reloj — Forerunner 165 (1:00)

- Ya está en la muñeca: no hay que mirar ni sostener nada, y la muñeca **se mueve con la
  cabeza** cuando el brazo cae al cabecear.
- Tiene **acelerómetro hasta 100 Hz** (usamos 25 Hz para ahorrar batería), **motor de
  vibración** y pantalla **AMOLED** de 390×390 redonda.
- Limitaciones que condicionaron el diseño: **no tiene giroscopio**, el motor **no cambia de
  fuerza** (ignora el `dutyCycle`) y una app en segundo plano pierde sensor y vibración si no
  graba una actividad.
- App nativa en **Monkey C** (Connect IQ), para fr165 y fr165m, publicable en la tienda.

### 3. Diseño de interfaz (2:00) — mostrar `docs/img/`

- **Tokens de diseño**: 4 colores base (fondo `0x07090C`, texto `0xF5F7FA`, secundario
  `0x9AA4B2`, cian `0x4CC9F0`) más estados (ámbar, rojo, naranjas de la alerta), todos en
  `Palette`, nunca valores sueltos.
- **Círculo**: nada de píxeles fijos; `RoundLayout` calcula todo en milésimas del lado y un
  **círculo seguro** dentro del anillo. Los textos se miden contra la cuerda del círculo a
  esa altura; si no caben, baja la fuente.
- **Legibilidad**: contraste **≥ 4,5:1** en todos los textos importantes (el peor, rojo sobre
  fondo, 6,5:1), comprobado por pruebas, también en todo el ciclo de pulso de la alerta.
- **Fotosensibilidad**: el pulso de la alerta va a **menos de 1 ciclo por segundo**, muy por
  debajo del umbral de 3 destellos por segundo.
- **Accesibilidad**: los niveles de alerta se distinguen por **número y duración de pulsos**
  (no por fuerza ni solo por color); "Animaciones reducidas"; aviso si la alerta quedaría
  **solo visual**; áreas táctiles grandes (248×76 px la del botón, 44 px como mínimo); BACK no cierra la alerta para
  no apagarla dormido; textos en español e inglés.
- **AMOLED**: fondo casi negro, poca superficie encendida y, desde la 1.0, la esfera se
  **desplaza ±2 px cada minuto** contra el quemado.

### 4. Arquitectura (1:30)

```
 platform (sensor, vibración, grabación)  →  core (lógica pura, probada)  →  views (UI delgada)
        RealAccelSource / SimulatedAccelSource
                    │ lotes de 25 muestras (mili-g)
                    ▼
 TelemetryEngine → SlidingWindow (2 s) → DrowsinessDetector → StateClassifier → NodConfirmation
                    → AlertController → AlertView + Haptics → AlertLog → FatiguePredictor
```

- `source/core` no importa `WatchUi` ni `Graphics`: recibe números y el tiempo como
  parámetro, así que se prueba con `Toybox.Test` y **el modo demo usa exactamente el mismo
  código** que el sensor real (solo cambia la fuente).
- `GuardController` (app) coordina; las vistas solo leen estado.
- Detalle: [ARQUITECTURA.md](ARQUITECTURA.md).

### 5. Detector e IA: v1, v2 y confirmación (2:00)

- **Reglas explicables** detectan el evento: cabeceo = sacudida > 400 mg + quietud antes de
  5 s + cambio de inclinación > 35°; inactividad = quietud 60 s. Cada señal descarta un falso
  positivo distinto (tecleo, golpe en la mesa, apoyar el brazo).
- **Clasificador** de 4 clases (Activo, Normal, Cabeceo, Inerte), regresión logística con 5
  características: **v1** ajustado a mano; **v2** entrenado en Python con 48 usuarios
  sintéticos y exportado a Monkey C (24 números, sin librerías en el reloj).
- **v1 → v2** (12 usuarios no vistos): exactitud 89,7 % → **93,3 %**; falsos cabeceos en
  episodios difíciles 16 → **12 de 48**. A cambio, el recall de Cabeceo baja (0,58 → 0,48).
- **Confirmación** (fase 11): el detector propone el cabeceo y el modelo lo confirma 2 s
  después solo si ya no ve movimiento Normal. Mirar la hora tras teclear: falsos **15 → 3 de
  24**, sin perder ningún cabeceo real (22 de 36 en ambos casos).

### 6. Demo en vivo (3:00)

Seguir [GUIA_DEMO.md](GUIA_DEMO.md) §2, **paso 4 (guion automático)**:

1. Esfera en pausa (10 s): anillo, puntaje, orbe tenue.
2. Mantener UP → *Guion automático* → START. Narrar los pasos 1–2 (normal, tecleo).
3. Paso 3: alerta de cabeceo a los ~8 s; explicar las tres señales y la confirmación;
   responder con START.
4. Paso 5: inactividad; responder.
5. Paso 6: **no responder**: nivel 2 a los 6 s, nivel 3 a los 12 s.
6. Resumen automático: 3 episodios, nivel máximo 3, fatiga Alta. START.
7. Si sobra tiempo: mantener UP → *Modelo IA* (exactitud y "Entrenado con datos
   sintéticos").

Plan B si el simulador falla: abrir las capturas de `docs/img/` (y el video, si se grabó) y
contar lo mismo sobre ellas.

### 7. Pruebas y métricas (1:00)

- **205 pruebas** unitarias con `Toybox.Test` (`scripts\test.ps1`), todas en verde, en el
  simulador del SDK 9.3.0 con verificación de tipos estricta (`-l 3`) y sin advertencias.
- Python y el reloj calculan **las mismas características y probabilidades** (diferencias <
  10⁻⁶) con vectores generados en `ml/`.
- Matriz de confusión de los escenarios en el reloj: 93,1 % (v1) → **98,3 %** (v2).
- Memoria pico en el simulador: **98,8 kB de 763,6 kB** (13 %) en fr165 y fr165m.

### 8. Limitaciones honestas (1:00)

- **Todo el entrenamiento y la validación son con datos sintéticos.** Las cifras comparan
  versiones; no son precisión en una muñeca real.
- **No se probó en un reloj real**: ni la vibración, ni la orientación real de los ejes, ni
  la pantalla apagada, ni la batería.
- El detector solo ve el **61 % de los cabeceos sintéticos** (los más lentos no superan 400
  mg) y v2 ve menos cabeceos que v1.
- Mirar la hora con el brazo casi inmóvil todavía engaña algunas veces (3 de 24).
- Solo acelerómetro: sin giroscopio, sin ritmo cardiaco.

### 9. Trabajo futuro (0:30)

Grabar datos reales con `SensorLogging` y etiquetas, reentrenar (`ml/import_real.py`),
medir batería y vibración en el FR165, y publicar en la Connect IQ Store.

## 2. Checklist antes de presentar

- [ ] **Borrar el historial de prueba**: mantener UP → *Historial* → *Borrar historial* →
      confirmar ("Aún no hay guardias").
- [ ] **Idioma** del simulador: *Settings > Language* y volver a cargar la app
      (`scripts\run.ps1 -Release -NoBuild`): los textos se cargan al abrir la app.
- [ ] **Ajustes por defecto**: Sensibilidad Media, Vibración Normal, Sonido activado,
      Animaciones Completas, Confirmar IA activado, Grabar actividad activado.
- [ ] **Modo demo**: empezar apagado (se ve la fecha) y encenderlo delante del jurado, o
      dejarlo encendido si se va directo al guion.
- [ ] **Simulador abierto** con la compilación de release: `scripts\run.ps1 -Release`. No
      ejecutar `scripts\test.ps1` después (deja el simulador sin reloj).
- [ ] *Settings > Vibrate* marcado en el simulador.
- [ ] Ventana del simulador grande y visible; cerrar el visor de memoria y otras ventanas.
- [ ] **Plan B**: `docs/img/` abierto en otra pestaña con las capturas en orden (esfera,
      orbe, alertas 1–3, ajustes, modelo IA, resumen, historial).
- [ ] **Video**: si se puede, grabar el guion automático completo (≈ 1 min 15 s) con la
      grabadora de pantalla de Windows (Win + Alt + R) el día anterior y tenerlo local.
- [ ] Batería del portátil cargada y notificaciones silenciadas.

## 3. Preguntas probables del jurado

1. **¿Por qué datos sintéticos?** — No teníamos un reloj ni un estudio con personas
   durmiéndose (que además exige consentimiento y cuidado). Los datos sintéticos permiten
   construir y validar todo el pipeline; el modelo está listo para reentrenarse con datos
   reales en cuanto se graben. Lo decimos en la propia app.
2. **¿Por qué regresión logística y no una red?** — Cabe en el reloj (24 números, sin
   librerías), es rápida, da probabilidades calibradas que usa el puntaje y es explicable.
   Con 5 características y datos sintéticos, un modelo más grande solo memorizaría.
3. **¿Qué pasa sin giroscopio?** — La inclinación sale de la **gravedad media** de la ventana
   del acelerómetro: el ángulo entre la postura de antes y la de después de la caída. Los
   giros puros sin aceleración no se ven, pero un cabeceo cambia la postura del brazo.
4. **¿Por qué baja el recall de Cabeceo en v2?** — Elegimos priorizar la **precisión**: un
   falso cabeceo baja el puntaje justo cuando el usuario mira el reloj. Y un cabeceo que el
   clasificador no marca igual dispara la alerta del detector por reglas; la confirmación
   no perdió ninguno de los 22 que la regla ve.
5. **¿Cómo evitaron la fuga de datos?** — División **por usuario**: 12 de los 48 usuarios
   solo en la prueba, con todas sus secuencias; validación cruzada agrupada por usuario
   para elegir hiperparámetros; la prueba se usa una sola vez. El script comprueba que
   ningún usuario esté en los dos lados.
6. **¿Y la batería?** — **No la medimos**: requiere el reloj. Decisiones para cuidarla: 25 Hz
   en vez de 100, lotes de 1 s, redibujo a 1 cuadro/s en pausa, timers parados cuando la
   vista no se ve. Está en pendientes medirla con el orbe animado y sin él.
7. **¿Y si el usuario solo mira la hora?** — Es el caso difícil: giro rápido y brazo quieto.
   La confirmación del modelo espera 2 s y descarta el cabeceo si ve movimiento Normal: los
   falsos bajan de 15 a 3 de 24. Hay un escenario "Mirar la hora" en la demo que no alerta.
8. **¿Cuánto tarda en avisar?** — Cabeceo: unos 5 s desde la caída en el escenario
   simulado (≈ 3 s hasta ver la quietud y la postura nueva + 2 s de confirmación). Inactividad: 60 s (8 s en demo). Sin respuesta, la alerta sube de nivel
   cada 10 s.
9. **¿Qué pasa si el sensor deja de enviar datos?** — Tras 5 s sin lotes la esfera muestra
   "Sin datos del sensor" en ámbar; al volver los datos la quietud empieza de cero, así que
   un corte nunca dispara una inactividad falsa (hay pruebas de eso).
10. **¿Cómo se prueba algo que depende del tiempo y del sensor?** — El núcleo recibe el
    tiempo como parámetro y las muestras como números; las pruebas pasan secuencias
    completas de la fuente simulada con un reloj controlado (`DetectorRig`).
11. **¿Por qué la alerta no se cierra con BACK?** — Para no apagarla dormido con un gesto
    reflejo. Solo "Estoy despierto" o START, y se mide el tiempo de respuesta.
12. **¿Es accesible para quien no ve bien los colores?** — Los niveles no dependen solo del
    color: cambian el texto ("Nivel 2 de 3"), el patrón de vibración y el ritmo del pulso.
    Todo texto importante tiene contraste ≥ 4,5:1.
13. **¿Qué datos guarda y a dónde van?** — Solo en el reloj: las 10 últimas guardias en
    `Application.Storage` y, si se activa, la actividad genérica de Garmin. Permisos: solo
    `Sensor` y `Fit`. No usa red ni teléfono.
14. **¿Funcionaría en otros relojes?** — El diseño está en proporciones, no en píxeles, así
    que escalaría a otras pantallas redondas; hoy el manifest solo declara fr165 y fr165m
    porque son los únicos probados.
15. **¿Qué tan seguro es usarlo para no dormirse al volante?** — **No debe usarse para
    eso.** No es un dispositivo médico ni de seguridad; si hay sueño, hay que parar y
    descansar. Lo dice la ficha de la tienda.

## 4. Cifras clave

| Cifra | Valor |
|---|---|
| Versión | **1.0.0** (tag local `v1.0.0`) |
| Commits | **199** hasta el tag `v1.0.0`, en 12 fases (`git rev-list --count v1.0.0`) |
| Pruebas unitarias | **205**, todas en verde |
| Exactitud del clasificador (Python, 12 usuarios no vistos) | v1 **89,7 %** → v2 **93,3 %** |
| Falsos cabeceos del modelo, episodios difíciles | v1 **16 de 48** → v2 **12 de 48** |
| Falsos cabeceos al mirar la hora tras teclear | sin confirmación **15 de 24** → con confirmación **3 de 24** |
| Cabeceos reales con alerta | **22 de 36**, con y sin confirmación |
| Matriz de los escenarios en el reloj | 93,1 % (v1) → **98,3 %** (v2) |
| Memoria pico (simulador, release, recorrido completo) | **98,8 kB de 763,6 kB** (13 %) en fr165 y fr165m |
| Paquete de la tienda | `bin\FocusPulse.iq` (fr165 y fr165m) |
| Batería | **no medida** (requiere reloj real) |
