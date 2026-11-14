# Detector de somnolencia — FocusPulse AI

Cómo decide la app que el usuario cabeceó o lleva demasiado tiempo inmóvil (fase 6). Todo
vive en `source/core` (lógica pura, sin `WatchUi`, `Graphics` ni `Sensor`): el tiempo entra
como parámetro y las pruebas recorren secuencias completas de la fuente simulada con el
reloj controlado. El detector emite eventos (se ven en la depuración, *Detector en vivo*) y,
desde la fase 7, cada uno abre la alerta a pantalla completa con vibración
([DISENO.md](DISENO.md) §5.3). Desde la fase 9, los episodios alimentan el predictor de
fatiga (§8). Desde la fase 10, el clasificador usa pesos **v2 entrenados** en Python con
datos sintéticos ([IA.md](IA.md)). Desde la fase 11, la **sensibilidad** es un ajuste
(§3.6) y el modelo **confirma los cabeceos** antes de abrir la alerta (§3.7).

## 1. Flujo por lote

El acelerómetro entrega un lote por segundo (25 muestras a 25 Hz). Con cada lote,
`GuardController.onBatch` hace, en este orden:

```
 lote (x, y, z en mg, t en ms)
        │
        ▼
 TelemetryEngine ─► SlidingWindow (2 s = 50 muestras)
        │              varianza de la magnitud, sacudida, gravedad media (x̄, ȳ, z̄)
        ▼
 TelemetrySnapshot
        │
        ▼
 DrowsinessDetector ◄──────── Baseline (calibración 30 s / 5 s demo, EMA)
        │   evento: NONE · CABECEO · INACTIVIDAD        │
        │   estado: calibrando · vigilando ·            └─► umbral de quietud
        │           caída detectada · evento
        ▼
 StateClassifier (softmax, ClassifierWeights v2)
        │   p(Activo), p(Normal), p(Cabeceo), p(Inerte), suavizadas
        ▼
 NodConfirmation (fase 11) ─► evento que abre la alerta
        │   CABECEO: espera 2 lotes y exige p(Normal) < 0,35 · INACTIVIDAD: directa
        ▼
 AlertnessScore ─► anillo y porcentaje          OrbModel.stateFor ─► orbe
```

`tests/DetectorRig.mc` repite exactamente esa cadena para las pruebas.

## 2. Señales de cada ventana

| Señal | Definición | Normal | Tecleo | Inerte | Cabeceo |
|---|---|---|---|---|---|
| Varianza | De la magnitud √(x²+y²+z²) en la ventana de 2 s (mg²). | 450–1 200 | 10 000–21 000 | 4–9 | alta en la caída, ≈ 6 después |
| Sacudida del lote | Mayor \|Δ\| vectorial entre muestras seguidas del lote (mg). | 87–177 | 406–717 | 8–13 | ≈ 460 en la caída |
| Sacudida final | Lo mismo en las 10 últimas muestras (0,4 s). | ≈ 70 | ≈ 450 | ≈ 10 | ≈ 10 tras la caída |
| Gravedad | Media de cada eje en la ventana: en 2 s el movimiento se promedia y queda la gravedad. | — | — | — | — |
| Inclinación | Ángulo entre dos gravedades (`Tilt.angleDegrees`). | < 1° entre lotes | < 4° entre lotes | ≈ 0° | **76°** antes/después |

Valores medidos con la fuente simulada (5 semillas). El fr165 no tiene giroscopio: la
postura sale solo de la dirección de la gravedad, y el ángulo no depende de cómo estén
orientados los ejes (sirve en las dos muñecas).

## 3. Detector (`DrowsinessDetector`)

### 3.1 Cabeceo: tres señales a la vez

1. **Sacudida** — el pico del lote supera **400 mg**. Abre una *caída candidata* y guarda
   la gravedad de la ventana anterior (la postura de antes).
2. **Quietud** — antes de **5 s** la ventana queda quieta (varianza < umbral, §4). Si no,
   la candidata caduca.
3. **Inclinación** — el ángulo entre la gravedad de antes y la de la ventana quieta supera
   **35°**: el brazo cayó de verdad. Si llega la quietud sin ese giro, la candidata se
   descarta.

Se combinan con un **Y**: hacen falta las tres. Cada una descarta un falso positivo
distinto:

| Si faltara… | …dispararía con |
|---|---|
| la sacudida | apoyar el brazo despacio en la mesa y quedarse quieto |
| la quietud | el tecleo (sacudidas de más de 400 mg en el 100 % de los lotes) |
| la inclinación | dejar de teclear, o un golpe en la mesa seguido de quietud |

Además, el detector solo muestra **caída detectada** (y el clasificador recibe "caída
pendiente") si la sacudida de las últimas 0,4 s del lote baja de **50 mg**: el movimiento
casi se detuvo. Un brazo que cuelga da ≈ 10 mg; el movimiento normal, ≈ 70; el tecleo, más
de 400. Este límite empezó en 150 mg y la matriz de confusión con secuencias mixtas
destapó el fallo: al pasar de teclear a moverse con normalidad quedaban 5 s de "caída
detectada" (commit `fix(core): require near stillness…`).

En el escenario simulado la caída empieza a los 3,04 s y el evento llega a los **6,0 s**
(2,96 s después; ≈ 2 s son los que tarda la ventana en quedar llena de muestras quietas).

### 3.2 Por qué el tecleo no dispara

- Tiene sacudidas fuertes (120 de 120 lotes en 2 minutos, pico de 717 mg), pero **nunca
  quietud**: su varianza es ≈ 18 000 mg², más de 100 veces el umbral.
- Su sacudida final nunca baja de 50 mg, así que tampoco se ve "caída detectada".
- Cuando el usuario deja de teclear sí llega la quietud, pero la gravedad casi no cambia
  (≈ 2°, muy lejos de 35°): la candidata se descarta y no hay cabeceo. Si la quietud sigue,
  lo que llega es la **inactividad**, que es lo correcto.

### 3.3 Inactividad prolongada

Quietud continua durante **T = 60 s** (**8 s en modo demo**, para la sustentación). La
quietud empieza a contar desde que la ventana está quieta *menos los 2 s de la ventana*:
si toda la ventana está quieta, el brazo lleva al menos 2 s sin moverse. Por eso, en el
escenario de inactividad, el evento llega exactamente a los 8,0 s (demo) o 60,0 s de
iniciar la guardia, y nunca antes.

### 3.4 Refractario y pausa

- Tras cada evento, **10 s** sin emitir otro, y la cuenta de quietud vuelve a cero. Si el
  usuario sigue inmóvil, en demo llega otra inactividad a los 10 s (8, 18, 28 s…).
  Mientras la alerta está abierta el detector sigue corriendo y sus eventos se ignoran (la
  alerta ya escala sola por tiempo, [DISENO.md](DISENO.md) §5.3); al descartarla, el
  siguiente llega cuando termina el refractario.
- Una caída candidata que se confirma durante el refractario espera a que termine (si no
  caducó): dos cabeceos seguidos dan eventos a los 6 y 16 s.
- Al **pausar** la guardia se borra todo (estado, candidata, quietud, línea base); al
  reanudar vuelve a calibrar.

### 3.5 Estados

| Estado | Cuándo | Color en la depuración |
|---|---|---|
| En pausa (`IDLE`) | Guardia en pausa. | gris |
| Calibrando | Primeros 30 s (5 s en demo). Ya detecta eventos. | gris |
| Vigilando | Sin caída pendiente ni evento reciente. | cian |
| Caída detectada | Sacudida hace menos de 5 s y el movimiento casi se detuvo: se espera la quietud. | ámbar |
| Evento | Los 10 s del refractario tras un cabeceo o una inactividad. | rojo |

Prioridad: evento > caída detectada > calibrando > vigilando.

### 3.6 Umbrales y sensibilidad (fase 11)

El ajuste **Sensibilidad** (Baja / Media / Alta, en el reloj y en Garmin Connect) cambia
tres umbrales; **Media son los valores de siempre** (fases 6–10). Los aplica
`DetectorThresholds` en el detector en el lote siguiente, sin reiniciar la guardia.

| Umbral | Baja | **Media** | Alta | Dónde |
|---|---|---|---|---|
| Sacudida que abre la caída | 440 mg | **400 mg** | 340 mg | `DetectorThresholds.NOD_JERK_MIN` |
| Inclinación de la caída | 45° | **35°** | 28° | `NOD_TILT_MIN` |
| Inactividad prolongada | 90 s | **60 s** | 45 s | `INACTIVITY_MS` |
| Inactividad en modo demo | 12 s | **8 s** | 6 s | `INACTIVITY_DEMO_MS` |

- La inactividad escala ×1,5 en Baja y ×0,75 en Alta, también en demo.
- Baja queda por debajo del pico del cabeceo simulado (≈ 460 mg): la demo da su cabeceo con
  cualquier sensibilidad (`sensitivityKeepsSimulatedNodAtEveryLevel`).
- Alta baja de los 366 mg del giro de *mirar la hora* del simulador: con esa sensibilidad
  la regla sí ve un cabeceo al mirar la hora y lo filtra la confirmación (§3.7; visto en el
  simulador).
- No cambian con la sensibilidad (son de medición, no de criterio):

| Constante | Valor | Dónde |
|---|---|---|
| Sacudida "calmada" | 50 mg | `DrowsinessDetector.NOD_CALM_JERK` |
| Quietud tras la caída | antes de 5 s | `NOD_STILL_WITHIN_MS` |
| Refractario | 10 s | `REFRACTORY_MS` |
| Umbral de quietud | 25–100 mg² (§4) | `Baseline.stillThreshold()` |

Efecto en el dataset sintético (prueba, `ml/reports/confirmation.md`; con confirmación):

| Sensibilidad | Cabeceos reales con alerta | Falsos cabeceos al mirar la hora | Otros falsos |
|---|---|---|---|
| Baja | 17 de 36 | 2 de 24 (13 sin confirmación) | 0 |
| Media | 22 de 36 | 3 de 24 (15 sin confirmación) | 0 |
| Alta | 30 de 36 | 4 de 24 (17 sin confirmación) | 0 |

### 3.7 Confirmación del cabeceo por el modelo (fase 11)

Con el ajuste **Confirmación por IA** (activado por defecto), un evento CABECEO del
detector no abre la alerta en el acto. `NodConfirmation` lo retiene **2 lotes (2 s)** y
lo confirma solo si entonces la probabilidad **suavizada de Normal** del clasificador es
**menor que 0,35**; si no, lo descarta (en depuración la consola escribe "CABECEO
confirmado/descartado por el modelo … p(Normal)"). La **inactividad no pasa por el
modelo**. Con el ajuste desactivado se vuelve al comportamiento de las fases 6–10.

Por qué funciona: en el instante del evento, una mirada a la hora tras teclear y un
cabeceo tienen casi la misma p(Cabeceo) (0,4–0,7 los dos); dos segundos después, el brazo
dormido ya es Inerte (p(Normal) ≤ 0,26 en todos los cabeceos de prueba) y el que lee la
hora vuelve a Normal (mediana 0,67). Retardo y umbral los eligió `ml/confirmation.py` con
los usuarios de entrenamiento: retardo ≤ 2 s y el menor umbral que no pierde ningún
cabeceo de entrenamiento. Detalle en [IA.md](IA.md) §12.

| Conjunto de prueba sintético (12 usuarios no vistos) | Regla sola (fases 6–10) | Regla + confirmación (fase 11) |
|---|---|---|
| Falsos cabeceos en *mirar la hora* (secuencias con alerta de cabeceo) | **15 de 24** (62,5 %) | **3 de 24** (12,5 %) |
| Recall de cabeceos reales (secuencias de cabeceo con alerta) | **22 de 36** (61,1 %) | **22 de 36** (61,1 %) |
| Falsos cabeceos en el resto (apoyar el brazo, mixtas, tecleo → normal, inactividad) | 0 | 0 |
| Retraso de la alerta de cabeceo | — | + 2 s |

El recall de cabeceos no baja: la confirmación no pierde ninguno de los que ve la regla. El
compromiso es el **retraso de 2 s** de la alerta de cabeceo (en el simulador: evento a los
6 s → alerta a los 8 s del escenario). La regla sigue sin ver las caídas lentas (61 %).

Qué no cambia: el detector (sus eventos, su estado y su refractario; un cabeceo descartado
también abre el refractario de 10 s) y, por tanto, las características del clasificador.

## 4. Línea base adaptativa (`Baseline`)

Aprende cuánto se mueve **este** usuario, en escala logarítmica: x = ln(varianza + 1). El
logaritmo pone en la misma escala a quien apenas se mueve (200 mg², x ≈ 5,3) y a quien
teclea (18 000 mg², x ≈ 9,8); el + 1 evita ln(0).

1. **Calibración**: los primeros **30 s** de la guardia (**5 s** en demo) acumula la media
   y la desviación de x. Mientras tanto la píldora de la esfera dice **"Calibrando…"**.
2. **Adaptación**: después, cada ventana mueve la media y la varianza con una EMA de peso
   **α = 0,01** (constante de tiempo ≈ 100 s con un lote por segundo).
3. **Solo ventanas ordinarias**, tanto al calibrar como al adaptar: ni quietas, ni con una
   caída pendiente, ni de un evento o su refractario. Un cabeceo o un rato inmóvil no
   arrastran la línea base hacia abajo. Si el usuario no se mueve nada durante la
   calibración, quedan los valores por defecto (los del movimiento normal: 6,55 ± 0,5).
4. **Umbral de quietud** = mín(100 mg², 0,25 × varianza típica), sin bajar de 25 mg²,
   donde varianza típica = e^media − 1. Con el movimiento normal (≈ 725 mg²) queda en 100;
   a quien se mueve poco (200 mg²) le basta bajar de 50 mg² para contar como quieto. El
   ruido de un brazo inerte (≈ 6 mg²) queda por debajo de cualquier umbral posible.

Los eventos **no esperan a la calibración**: con el umbral por defecto (100 mg²) ya
funcionan, y perder un cabeceo en los primeros 30 s sería peor que usar un umbral sin
adaptar.

## 5. Clasificador (`StateClassifier`)

Regresión logística multiclase con cuatro clases: **Activo, Normal, Cabeceo, Inerte**. Desde
la fase 10 usa los pesos **v2**, entrenados en Python ([IA.md](IA.md)); los v1, ajustados a
mano en la fase 6, quedan en `ClassifierWeightsV1.mc` como referencia.

| # | Característica (por lote) | Unidad |
|---|---|---|
| 0 | ln(varianza + 1) | ln(mg²) |
| 1 | Sacudida del lote | mg |
| 2 | Segundos de quietud (tope 30) | s |
| 3 | Cambio de inclinación en grados (tope 90): desde antes de la caída si hay una pendiente, si no respecto al lote anterior | grados |
| 4 | Caída pendiente | 0/1 |

```
z_k = INTERCEPT_k + Σ_j COEF_kj · x_j      (x sin normalizar: la estandarización va plegada)
p_k = e^z_k / Σ e^z                         (se resta el máximo de z para no desbordar)
p̂_k ← 0,6 · p_k + 0,4 · p̂_k                 (EMA; al empezar, Normal = 1)
```

`ml/features.py` calcula las mismas características en Python (la prueba
`featuresMatchPythonVectors` lo comprueba) y `ml/export_weights.py` genera
`ClassifierWeights.mc`: no se edita a mano.

**v2 (entrenado).** Regresión logística multinomial sobre 17 376 ventanas sintéticas de 48
usuarios, con negativos difíciles (mirar la hora, apoyar el brazo); peso ×2 para Cabeceo y
C = 1, elegidos con validación cruzada agrupada por usuario. En la prueba (12 usuarios no
vistos): exactitud 93,3 % frente a 89,7 % de v1 y falsos cabeceos en 12 de 48 episodios
difíciles frente a 16. Pesos, elección y limitaciones en [IA.md](IA.md).

**v1 (referencia, fase 6).** Formato sin plegar: x' = (x − media) / escala, con media 0 y
escala (3, 400, 10, 30, 1).

| Clase | Intercepto | ln var | sacudida | quietud | inclinación | caída pend. |
|---|---|---|---|---|---|---|
| Activo | −14 | 4 | 2,5 | −2 | −2 | −2 |
| Normal | 0 | 0 | 0 | 0 | 0 | 0 |
| Cabeceo | −5 | 0 | 0 | −1 | 1,5 | 6 |
| Inerte | 11,5 | −7,5 | 0 | 1,5 | 0 | 0 |

Activo ganaba con varianza y sacudida altas (frontera ≈ 5 600 mg² con una sacudida de
400 mg); Inerte, por debajo de ≈ 100 mg²; Cabeceo, sobre todo con la caída pendiente. Su
punto débil, medido en la fase 10: leer la hora con el brazo sostenido (≈ 40 mg²) caía en
Inerte, y un giro rápido seguido de quietud, en Cabeceo.

**Puntaje y orbe.** `AlertnessScore` se acerca a Σ p̂_k × nivel_k (Activo 100, Normal 85,
Cabeceo 0, Inerte 10) a +3 / −2 puntos por segundo como mucho: de 88 a ≈ 84 con
movimiento normal, de 88 a 50 en 20 s de inactividad, de 84 a 60 en 12 s tras un
cabeceo. El orbe va a cámara lenta con Cabeceo o Inerte, al doble con Activo y normal en
el resto (y lento si el puntaje baja de 60).

## 6. Resultados

### 6.1 Matriz de confusión

`classifierConfusionMatrixOnSimulatedScenarios` (en `tests/StateClassifierTest.mc`) la escribe
en el registro de pruebas, con v1 y con v2 sobre los mismos lotes. Con 5 semillas se recorre
cada escenario (tecleo 40 s, normal 40 s, cabeceo 15 s, inactividad 40 s y, desde la fase 10,
mirar la hora 36 s) más una guardia mixta (normal → tecleo → normal → inactividad, 10 s cada
uno y 15 la inactividad), y se cuenta cada lote de 1 s desde que la ventana está llena.

Clase real: la del escenario en curso (mirar la hora es Normal). En el cabeceo, Normal antes
de la caída, Cabeceo desde la caída hasta 2 s después de terminar (mientras la ventana la
contiene) e Inerte después (el usuario quedó dormido).

**v2:**

| Real \ Predicha | Activo | Normal | Cabeceo | Inerte | Acierto |
|---|---|---|---|---|---|
| **Activo** | **243** | 2 | 0 | 0 | 99,2 % |
| **Normal** | 3 | **472** | 0 | 0 | 99,4 % |
| **Cabeceo** | 0 | 0 | **10** | 0 | 100 % |
| **Inerte** | 0 | 8 | 5 | **307** | 95,9 % |

**Exactitud global: 1 032 de 1 050 lotes = 98,3 %** (v1: 978 de 1 050 = 93,1 %). Desde la
fase 11 la fuente simulada cambia de postura en 1,5 s (§7): en la guardia mixta, el paso a
inactividad tarda algo más en ser Inerte (8 lotes Normal en lugar de 5) y el de tecleo a
normal algo menos (antes 1 033 de 1 050).

La diferencia con v1 está en *mirar la hora*: v1 toma 59 lotes de lectura por Inerte; v2,
ninguno. Ninguno de los dos da Cabeceo al mirar la hora ni al dejar de teclear. Los errores de
v2 son retrasos en los cambios de escenario de la guardia mixta (la ventana de 2 s y la EMA
tardan uno o dos lotes) y 5 lotes Inerte tomados por Cabeceo justo después de la caída, con
la candidata todavía pendiente. Nunca se confunden los extremos (Activo con Inerte).

Ojo: son datos **simulados** y muy separables; la matriz demuestra que el algoritmo hace lo
que se diseñó, no su exactitud en muñecas reales. Las métricas del modelo sobre usuarios
sintéticos variados están en [IA.md](IA.md) §8.

### 6.2 Pruebas del detector

| Prueba | Resultado |
|---|---|
| Tecleo 2 min (modo demo) | 0 eventos; 120 de 120 lotes con sacudida ≥ 400 mg |
| Normal 2 min (modo demo) | 0 eventos |
| Tecleo con sacudidas > 400 mg, y luego reposo | 0 cabeceos; 0 lotes en "caída detectada"; 1 inactividad tras el reposo |
| Tecleo → movimiento normal | nunca "caída detectada" |
| Cabeceo | exactamente 1 CABECEO, 2,96 s después de la caída |
| Inactividad | a los 8,0 s en demo y a los 60,0 s en normal, ni un lote antes |
| Refractario | inactividad continua: 8, 18 y 28 s; dos cabeceos: 6 y 16 s |
| Calibración | termina a los 5 s (demo) y 30 s; aprende 6,59 ± 0,13 (≈ 725 mg²) con movimiento normal; umbral 50 mg² para 200 mg² |
| Clasificador | gana la clase del escenario (> 90 %); Cabeceo durante la caída pendiente |
| Mirar la hora 2 min (modo demo, fase 10) | 0 eventos; el giro llega a 366 mg (no abre caída candidata); leyendo: varianza 43 mg², inclinación 80° |
| Python ↔ reloj (fase 10) | los 64 eventos y las características de 62 ventanas coinciden (máx. 8 × 10⁻⁶ grados) |
| Sensibilidad (fase 11) | Media = umbrales de siempre; inactividad demo a los 12 / 8 / 6 s; el cabeceo simulado sale con las tres; una caída de 420 mg y 40° es cabeceo en Media y Alta, no en Baja |
| Confirmación (fase 11) | cabeceo simulado: evento a los 6 s y alerta a los 8 s (5 semillas); mirar la hora justo tras teclear: la regla da 1 cabeceo y el modelo lo descarta (5 semillas, p(Normal) ≈ 0,6); con el ajuste desactivado ambos alertan; la inactividad no pasa por el modelo |
| Cambio de escenario (fase 11) | cabeceo → inactividad: sacudida < 100 mg (antes ≈ 1 228), ningún cabeceo de más; ciclo completo de DOWN: un solo cabeceo; mirar la hora → normal sin lotes Cabeceo |

### 6.3 Simulador (fr165, español)

Recorrido en *Detector en vivo* con la fuente simulada:

- **Inactividad**: "Calibrando…" con Inerte subiendo; "Evento: Inactividad" a los **8,0 s**,
  Inerte 100 %.
- **Cabeceo**: Normal 98 % → "Caída detectada" con Cabeceo 82 % e inclinación 70° →
  "Evento: Cabeceo" a los **6,0 s** (inclinación 76°) → Inerte 84 %. Sin pausar, siguieron
  inactividades a los 16 y 26 s. Cambiando a cabeceo con la guardia ya calibrada, también
  sale (a los 21 s de esa guardia).
- **Tecleo**: Vigilando, Activo 89 %, 0 eventos en 20 s; la línea base aprendió 9,8 (el
  umbral sigue en 100).
- **Normal**: Normal 97 %, 0 eventos en 20 s, línea base 6,8 ± 0,13.
- **Esfera**: la píldora dice "Calibrando…" los primeros 5 s y luego "Guardia activa".
- **Pausa**: el detector vuelve a la línea base por defecto y Normal 100 %; el último
  evento sigue a la vista.

## 7. Limitaciones

- Los umbrales (400 mg, 35°, 50 mg, 25 mg²) salen de escenarios simulados y los pesos v2, de
  datos sintéticos. Falta validarlos con datos de muñeca reales (ver
  [PENDIENTES.md](PENDIENTES.md) e [IA.md](IA.md) §10).
- Un cabeceo sin cambio de postura del brazo (la cabeza cae pero la muñeca sigue apoyada)
  no da cabeceo; si el usuario queda inmóvil, lo cubre la inactividad.
- **Mirar la hora y quedarse leyendo.** El escenario de referencia del simulador no
  dispara con la sensibilidad media (el giro da 366 mg, por debajo de 400). En el dataset
  sintético la regla da un evento CABECEO en 15 de 24 secuencias de mirar la hora de la
  prueba, casi todas mirando la hora **justo después de teclear** (la sacudida del tecleo deja
  abierta una caída candidata, el brazo sostenido cuenta como quieto y el giro supera los
  35°). **Desde la fase 11 la confirmación del modelo (§3.7) deja 3 de 24** sin perder
  cabeceos; esos 3 son lecturas con el brazo casi inmóvil, que el modelo ve como Inerte.
  Hay que confirmarlo con datos reales.
- El detector por reglas solo detecta el 61 % de los cabeceos sintéticos de la prueba (22 de
  36): las caídas lentas no llegan a 400 mg de sacudida. Si el usuario queda inmóvil, lo
  cubre la inactividad.
- **Cambio de escenario en el simulador (resuelto en la fase 11).** Antes, pasar con DOWN
  de *cabeceo* a *inactividad* saltaba de postura en una sola muestra (≈ 1 200 mg y 75°) y el
  detector daba un cabeceo de más a los ≈ 4 s. Ahora `SimulatedAccelSource` desliza la
  gravedad hasta la postura del escenario nuevo en 38 muestras (≈ 1,5 s), conservando el
  ruido del escenario nuevo: cada muestra se mueve ≈ 30–40 mg y no hay sacudida. Como el
  brazo se mueve durante la transición, la inactividad tras DOWN llega a los ≈ 10 s en lugar
  de 8.
- El acelerómetro del simulador (*Activity Data*) entrega vectores de 1 g en direcciones
  al azar: varianza de la magnitud ≈ 0, sacudidas enormes e inclinaciones grandes. Con esa
  fuente el detector daría cabeceos sin parar; para probar se usa la fuente simulada.
- El clasificador usa características absolutas (no relativas a la línea base): la línea
  base solo ajusta el umbral de quietud.

## 8. Predictor de fatiga (`FatiguePredictor`, fase 9)

El detector dice **cuándo** hubo un micro-sueño; el predictor resume **cómo va la guardia**
en tres niveles, Bajo / Moderado / Alto, para recomendar un descanso. Es un predictor
**por reglas**: no aprende ni tiene pesos, y cada resultado se explica con una frase.

### 8.1 Entradas

Los **episodios** de la guardia actual: cada alerta que abrió el detector (cabeceo o
inactividad) es un `AlertRecord` con

- su **hora** (ms desde el inicio de la guardia),
- su **tiempo de respuesta** ("Estoy despierto"), o ninguno si la guardia se pausó con la
  alerta abierta,
- su **nivel máximo** (1–3) con el escalamiento.

Además: la **duración** de la guardia hasta ahora (el "ahora" del predictor), la ventana
del modo y desde cuándo contar (`sinceMs`: 0, o el final del último descanso completo). Las
alertas de "Probar alerta" no son episodios.

### 8.2 Reglas

| # | Regla | Efecto |
|---|---|---|
| 1 | **Episodios recientes**: los que empezaron en los últimos **30 min** (**5 min** en modo demo). Un episodio justo en el borde cuenta. | 0 → **Bajo** · 1–2 → **Moderado** · 3 o más → **Alto** |
| 2 | **Respuestas cada vez más lentas**: las 3 últimas respuestas de la guardia van en aumento estricto (cada una más lenta que la anterior) y la última tarda **al menos 1 s más** que la primera. Las alertas sin respuesta no cuentan. | sube **un nivel** (Bajo → Moderado, Moderado → Alto) |
| 3 | **Nivel 3 de alerta**: alguna alerta de la guardia llegó al nivel 3 (20 s sin respuesta; 12 s en demo). | **al menos Moderado** |

Se aplican en ese orden y el resultado nunca pasa de Alto. Ejemplos:

- 3 cabeceos respondidos en 10 minutos → regla 1 → **Alto**: la esfera muestra "Micro-sueños
  repetidos · descansa 15 min".
- 1 episodio hace 5 min → regla 1 → **Moderado**.
- Respuestas de 1,0, 1,5 y 2,3 s y solo la última en la ventana → regla 1 da Moderado, la 2
  lo sube a **Alto**.
- Una alerta que llegó al nivel 3 hace una hora y nada desde entonces → la regla 1 da Bajo,
  la 3 lo deja en **Moderado**.

**Por qué las reglas 2 y 3 miran toda la guardia y no solo la ventana.** Si miraran solo la
ventana nunca cambiarían nada: un episodio en la ventana ya da Moderado y tres dan Alto.
Mirando toda la guardia aportan lo que la regla 1 no ve: una tendencia que empezó antes de
la ventana, o que el usuario ya necesitó la vibración máxima una vez.

**Descanso.** Un descanso guiado **completo** (los 15 min, o 30 s en demo) reinicia las tres
reglas: los episodios anteriores a su final no cuentan, y la fatiga vuelve a Bajo. Uno
cancelado con BACK no reinicia nada.

### 8.3 Cuándo se calcula

`GuardController` lo recalcula con cada lote (una vez por segundo, así la ventana avanza y
un Alto puede bajar solo) y con cada episodio nuevo. El costo es mínimo: como mucho 32
episodios (`AlertLog.CAPACITY`). La fatiga final de la guardia queda en su resumen y en el
historial.

### 8.4 Umbrales

| Constante | Valor | Dónde |
|---|---|---|
| Ventana | 30 min · 5 min demo | `FatiguePredictor.WINDOW_MS`, `WINDOW_DEMO_MS` |
| Episodios para Moderado / Alto | 1 / 3 | `MODERATE_EPISODES`, `HIGH_EPISODES` |
| Respuestas de la tendencia | 3 | `TREND_RESPONSES` |
| Aumento mínimo de la tendencia | 1 000 ms | `TREND_MIN_INCREASE_MS` |
| Nivel de alerta de la regla 3 | 3 | `MAX_ALERT_LEVEL` |
| Escalamiento de la alerta | 10 s · 6 s demo | `AlertController.ESCALATION_MS`, `ESCALATION_DEMO_MS` |

### 8.5 Pruebas y simulador

- `tests/FatiguePredictorTest.mc` (7 pruebas): cada regla por separado con sus límites
  (30 min justos frente a 30 min + 1 ms, 999 ms frente a 1 000 ms de aumento, respuestas
  iguales, alertas sin respuesta fuera de la tendencia, nivel 2 frente a 3), la ventana de
  5 min del modo demo y el reinicio tras el descanso.
- Simulador, modo demo, escenario de inactividad: con 3 alertas respondidas en ≈ 40 s la
  consola pasa de "fatiga 1" a "fatiga 2" en la tercera y la esfera muestra el aviso; tras
  un descanso completo el resumen de esa guardia dice "Fatiga: Bajo".

### 8.6 Limitaciones

- Los números (30 min, 3 episodios, 1 s) son razonables pero **no están validados** con
  personas: salen de criterio, no de datos. Igual que los umbrales del detector, se
  revisarán con datos reales (fase de IA).
- La ventana cuenta episodios, no su gravedad: tres cabeceos cortos pesan lo mismo que tres
  inactividades largas.
- La tendencia necesita 3 respuestas; en una guardia corta casi nunca interviene.
