# Detector de somnolencia — FocusPulse AI

Cómo decide la app que el usuario cabeceó o lleva demasiado tiempo inmóvil (fase 6). Todo
vive en `source/core` (lógica pura, sin `WatchUi`, `Graphics` ni `Sensor`): el tiempo entra
como parámetro y las pruebas recorren secuencias completas de la fuente simulada con el
reloj controlado. La pantalla de alerta y la vibración llegan en la fase 7; aquí el
detector emite eventos y se ven en la depuración (*Detector en vivo*).

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
 StateClassifier (softmax, ClassifierWeights)
        │   p(Activo), p(Normal), p(Cabeceo), p(Inerte), suavizadas
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
  usuario sigue inmóvil, en demo llega otra inactividad a los 10 s (8, 18, 28 s…): es la
  señal que usará el escalado de alertas de la fase 7.
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

### 3.6 Umbrales

| Constante | Valor | Dónde |
|---|---|---|
| Sacudida de caída | 400 mg | `DrowsinessDetector.NOD_JERK_MIN` |
| Sacudida "calmada" | 50 mg | `NOD_CALM_JERK` |
| Quietud tras la caída | antes de 5 s | `NOD_STILL_WITHIN_MS` |
| Inclinación de caída | 35° | `NOD_TILT_MIN` |
| Inactividad | 60 s · 8 s demo | `INACTIVITY_MS`, `INACTIVITY_DEMO_MS` |
| Refractario | 10 s | `REFRACTORY_MS` |
| Umbral de quietud | 25–100 mg² (§4) | `Baseline.stillThreshold()` |

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

## 5. Clasificador v1 (`StateClassifier`)

Regresión logística multiclase con cuatro clases: **Activo, Normal, Cabeceo, Inerte**.

| # | Característica (por lote) | Escala |
|---|---|---|
| 0 | ln(varianza + 1) | ÷ 3 |
| 1 | Sacudida del lote (mg) | ÷ 400 |
| 2 | Segundos de quietud (tope 30) | ÷ 10 |
| 3 | Cambio de inclinación en grados (tope 90): desde antes de la caída si hay una pendiente, si no respecto al lote anterior | ÷ 30 |
| 4 | Caída pendiente (0/1) | ÷ 1 |

```
x' = (x − media) / escala
z_k = intercepto_k + Σ_j coef_kj · x'_j
p_k = e^z_k / Σ e^z            (se resta el máximo de z para no desbordar)
p̂_k ← 0,6 · p_k + 0,4 · p̂_k     (EMA; al empezar, Normal = 1)
```

Pesos v1, ajustados a mano con los escenarios simulados (`source/core/ClassifierWeights.mc`):

| Clase | Intercepto | ln var | sacudida | quietud | inclinación | caída pend. |
|---|---|---|---|---|---|---|
| Activo | −14 | 4 | 2,5 | −2 | −2 | −2 |
| Normal | 0 | 0 | 0 | 0 | 0 | 0 |
| Cabeceo | −5 | 0 | 0 | −1 | 1,5 | 6 |
| Inerte | 11,5 | −7,5 | 0 | 1,5 | 0 | 0 |

Cómo se eligieron (Normal es la referencia):

- **Activo** gana con varianza y sacudida altas: frontera ≈ 5 600 mg² con una sacudida
  de 400 mg (el tecleo está en ≈ 18 000).
- **Inerte** gana por debajo de ≈ 100 mg², el umbral de quietud, y crece con la quietud
  acumulada. Quien apenas se mueve (≈ 200 mg²) sigue siendo Normal.
- **Cabeceo** depende sobre todo de la caída pendiente; la inclinación ayuda, pero sola
  no basta: girar la muñeca 90° para mirar la hora sigue siendo Normal.

El archivo de pesos tiene el formato de scikit-learn (`StandardScaler.mean_` y `.scale_`,
`LogisticRegression(multi_class="multinomial").coef_` e `.intercept_`), así que la fase
de IA lo podrá generar desde Python sin tocar el clasificador.

**Puntaje y orbe.** `AlertnessScore` se acerca a Σ p̂_k × nivel_k (Activo 100, Normal 85,
Cabeceo 0, Inerte 10) a +3 / −2 puntos por segundo como mucho: de 88 a ≈ 84 con
movimiento normal, de 88 a 50 en 20 s de inactividad, de 84 a 60 en 12 s tras un
cabeceo. El orbe va a cámara lenta con Cabeceo o Inerte, al doble con Activo y normal en
el resto (y lento si el puntaje baja de 60).

## 6. Resultados

### 6.1 Matriz de confusión

`classifierConfusionMatrixOnSimulatedScenarios` (en `tests/StateClassifierTest.mc`)
la escribe en el registro de pruebas. Con 5 semillas, se recorre cada escenario (tecleo
40 s, normal 40 s, cabeceo 15 s, inactividad 40 s) más una guardia mixta (normal →
tecleo → normal → inactividad, 10 s cada uno y 15 la inactividad), y se cuenta cada lote
de 1 s desde que la ventana está llena.

Clase real: la del escenario en curso. En el cabeceo, Normal antes de la caída, Cabeceo
desde la caída hasta 2 s después de terminar (mientras la ventana la contiene) e Inerte
después (el usuario quedó dormido).

| Real \ Predicha | Activo | Normal | Cabeceo | Inerte | Acierto |
|---|---|---|---|---|---|
| **Activo** | **241** | 4 | 0 | 0 | 98,4 % |
| **Normal** | 4 | **296** | 0 | 0 | 98,7 % |
| **Cabeceo** | 0 | 0 | **10** | 0 | 100 % |
| **Inerte** | 0 | 5 | 0 | **315** | 98,4 % |

**Exactitud global: 862 de 875 lotes = 98,5 %.**

Los 13 errores están todos en los cambios de escenario de la guardia mixta y son retraso,
no confusión. La ventana de 2 s y la EMA tardan uno o dos lotes en cambiar de clase:
normal → tecleo (4), tecleo → normal (4) y normal → inactividad (5, porque la ventana
tiene que llenarse de muestras quietas). Nunca se confunden los extremos (Activo con
Inerte). Hay pocas muestras de Cabeceo porque un cabeceo dura ≈ 2 lotes.

Ojo: son datos **simulados** y muy separables; la matriz demuestra que el algoritmo hace lo
que se diseñó, no su exactitud en muñecas reales. Eso se medirá con datos del reloj en la
fase de IA.

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

- Los umbrales (400 mg, 35°, 50 mg, 25 mg²) y los pesos salen de escenarios simulados. Falta
  validarlos con datos de muñeca reales (ver [PENDIENTES.md](PENDIENTES.md)).
- Un cabeceo sin cambio de postura del brazo (la cabeza cae pero la muñeca sigue apoyada)
  no da cabeceo; si el usuario queda inmóvil, lo cubre la inactividad.
- **Posible falso positivo sin probar: girar la muñeca rápido para mirar la hora y
  quedarse leyendo.** Un giro rápido da sacudida, la varianza de la *magnitud* no ve los
  giros (|g| no cambia) y la inclinación pasa de 35°. Que dispare depende de si el brazo
  sostenido en el aire queda por debajo del umbral de quietud, y eso solo se sabe en el
  reloj. Si pasa, la salida es exigir también la *dirección* de la caída (la gravedad debe
  acabar en la postura de brazo colgando o apoyado, no con la esfera hacia la cara).
- El acelerómetro del simulador (*Activity Data*) entrega vectores de 1 g en direcciones
  al azar: varianza de la magnitud ≈ 0, sacudidas enormes e inclinaciones grandes. Con esa
  fuente el detector daría cabeceos sin parar; para probar se usa la fuente simulada.
- El clasificador usa características absolutas (no relativas a la línea base): la línea
  base solo ajusta el umbral de quietud.
