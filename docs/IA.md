# IA entrenada — clasificador de estado v2 (fase 10)

Cómo se entrenaron los pesos del clasificador `StateClassifier` (Activo / Normal / Cabeceo /
Inerte), qué tan bien funcionan y, sobre todo, qué **no** dicen sus números.

> **Datos sintéticos.** El modelo v2 se entrenó y se evaluó solo con datos fabricados a partir
> de las firmas de movimiento del simulador del reloj, con variaciones por usuario. No se usó
> ni una muestra de una muñeca real. Las métricas de este documento comparan v1 con v2 en
> igualdad de condiciones y demuestran que el pipeline funciona; **no son precisión en el
> mundo real.** La app lo dice en su pantalla *Modelo IA* ("Entrenado con datos sintéticos").

## 1. Qué cambió

| | v1 (fase 6) | v2 (fase 10) |
|---|---|---|
| Origen de los pesos | Ajustados a mano con los escenarios simulados | Regresión logística multinomial entrenada en Python |
| Datos | 4 escenarios del simulador | 48 usuarios sintéticos, 528 secuencias, 17 376 ventanas, con negativos difíciles |
| Archivo | `ClassifierWeightsV1.mc` (referencia, no la usa la app) | `ClassifierWeights.mc`, **generado** por `ml/export_weights.py` |
| Cálculo en el reloj | x' = (x − media) / escala; z = coef · x' + b | z = COEF · x + INTERCEPT (estandarización plegada) |

Lo demás no cambia: las mismas 5 características, la misma softmax, la misma EMA (0,6) y
el mismo detector por reglas, que sigue siendo quien detecta los eventos
([DETECTOR.md](DETECTOR.md)). El clasificador mueve el orbe y el puntaje de alerta y, desde
la fase 11, **confirma los cabeceos** del detector antes de abrir la alerta (§12).

## 2. Pipeline

```
 scripts\train.ps1  (-Seed, -NoExport)
   │
   ├─ ml\.venv + requirements.txt (Python 3.12, versiones fijas)
   │
   ├─ generate_dataset.py ──► data\samples.csv, sequences.csv     (sintético, no versionado)
   │     usuarios, rotación de muñeca, transiciones, negativos difíciles
   │
   ├─ train.py
   │     features.py ──► 5 características por lote, idénticas al reloj
   │     división por USUARIO (75 % / 25 %)
   │     GroupKFold(5) ──► peso de clase y C
   │     StandardScaler + LogisticRegression ──► pesos plegados ──► models\model_v2.json
   │     evaluate.py ──► reports\ (v1 y v2 sobre la misma prueba)
   │
   └─ export_weights.py ──► source\core\ClassifierWeights.mc   (GENERADO)
                            tests\ModelVectors.mc, tests\FeatureVectors.mc
```

Con la misma semilla todo sale idéntico bit a bit (pesos, informe y PNG): después de correr
`scripts\train.ps1`, `git status` queda limpio. Paso a paso en [ml/README.md](../ml/README.md).

## 3. Datos sintéticos

`ml/generate_dataset.py` reproduce `SimulatedAccelSource`: 25 Hz, mili-g enteros, gravedad de
≈ 1 000 mg, el mismo ruido (uniforme y triangular) y la misma caída del cabeceo
(interpolación recta con el perfil `NOD_PROFILE`). Encima añade:

- **Usuarios.** Cada uno tiene su amplitud de movimiento normal (±45–100 mg), su ruido de
  brazo inerte (±2–6 mg), la fuerza (±170–320 mg) y el ritmo (2,5–6 Hz) del tecleo, el ángulo
  (50–100°) y la duración (8–16 muestras) de la caída. El usuario 0 usa exactamente las
  constantes del simulador.
- **Orientación de la muñeca.** Cada secuencia gira todas sus muestras con una rotación al
  azar. Las características no dependen de la orientación (varianza de la magnitud, |Δ|
  vectorial, ángulo entre gravedades), así que esto comprueba justamente eso.
- **Transiciones** dentro de una misma guardia: normal ↔ tecleo, inactividad, cabeceo con o
  sin despertar, tecleo → normal.
- **Negativos difíciles**, etiquetados Normal, que son los casos que más se parecen a un
  cabeceo:
  - **mirar la hora y quedarse leyendo**: giro rápido de la muñeca (60–110°, 0,24–0,56 s, con
    módulo constante más la aceleración de subir el brazo) y 3–8 s con el brazo sostenido y un
    temblor pequeño (±6–30 mg), a veces justo después de teclear;
  - **apoyar el brazo despacio** en la mesa (30–70° en 1–3 s), dejarlo 3–6 s con la mano
    moviéndose un poco y volver a moverse.

Un tipo de secuencia por línea de `sequences.csv`; seis tipos, 11 secuencias por usuario.

**Etiqueta de cada ventana** (lote de 1 s con la ventana de 2 s llena): Cabeceo si la
ventana contiene alguna muestra de la caída; si no, el estado en curso. Es la misma regla
que usaban las pruebas del reloj (`trueClass`). Reparto: 9 522 Normal, 3 796 Inerte,
3 713 Activo y solo **345 Cabeceo** (2 %): un cabeceo dura un par de lotes.

## 4. Características idénticas en Python y en el reloj

`ml/features.py` traduce línea a línea `TelemetryEngine`, `SlidingWindow`,
`DrowsinessDetector` y `Baseline`, porque tres de las cinco características dependen del
estado del detector:

| # | Característica | Unidad |
|---|---|---|
| 0 | ln(varianza + 1) de la magnitud en la ventana de 2 s | ln(mg²) |
| 1 | Sacudida máxima del lote | mg |
| 2 | Segundos de quietud del detector (tope 30) | s |
| 3 | Cambio de inclinación (tope 90) | grados |
| 4 | Caída pendiente (0/1) | — |

Se copian también los detalles que cambian los números: magnitud redondeada a mg enteros,
sumas enteras exactas, `float32` donde Monkey C usa `Float`, tiempo del lote k = k × 1 000 ms.

**Prueba de equivalencia.** `ml/test_vectors.py` exporta a `tests/FeatureVectors.mc` dos
secuencias fijas (1 600 muestras: tecleo, cabeceo, miradas a la hora, brazo apoyado,
inactividad; una con la muñeca girada) con el evento esperado de cada lote y las
características de cada ventana. `featuresMatchPythonVectors` las pasa por la cadena del
reloj: los 64 eventos coinciden y la mayor diferencia es **0** en cuatro características y
**8 × 10⁻⁶ grados** en la inclinación. `classifierMatchesPythonProbabilities` hace lo mismo con
las probabilidades de 16 ventanas de prueba: diferencia máxima < 10⁻⁶.

## 5. Por qué regresión logística

- **Cabe en el reloj.** 4 × 5 pesos + 4 sesgos: 24 números en `Float`, ≈ 20 multiplicaciones
  y 4 exponenciales por segundo. Ni dependencias ni intérprete: Connect IQ no ejecuta modelos
  de ML, y no hace falta.
- **Es interpretable.** Cada peso dice cuánto empuja una característica hacia una clase.
  Coeficientes estandarizados de v2 (una desviación típica de cada característica):

  | Clase | ln var | sacudida | quietud | inclinación | caída pend. |
  |---|---|---|---|---|---|
  | Activo | **+5,48** | +0,90 | +1,06 | −2,94 | −0,87 |
  | Normal | +0,22 | −1,57 | −0,07 | +0,91 | −0,14 |
  | Cabeceo | −1,14 | +0,34 | −1,28 | **+1,38** | +0,35 |
  | Inerte | **−4,55** | +0,34 | +0,29 | +0,65 | +0,65 |

  (En una softmax solo importan las diferencias entre filas.) La varianza separa Activo de
  Inerte; Cabeceo se distingue de Normal por más inclinación, menos quietud acumulada y la
  caída pendiente; la sacudida empuja fuera de Normal.
- **Es rápida y estable de entrenar**, con pocos datos y sin sobreajustar: con 24 parámetros
  y miles de ventanas no puede memorizar usuarios (ver §6).
- **Mantiene el formato de v1** (scikit-learn), así que el clasificador solo cambió en una
  línea: ya no estandariza.

Un árbol o una red pequeña podrían separar mejor el Cabeceo, pero con datos sintéticos esa
ganancia sería sobre todo aprender el generador. Es trabajo para cuando haya datos reales.

## 6. Fuga de datos y cómo se evitó

Dos ventanas seguidas de una secuencia comparten 1 s de muestras y casi todo el estado del
detector (quietud, caída pendiente). Si se reparten ventanas sueltas al azar entre
entrenamiento y prueba, el modelo se evalúa con casi las mismas ventanas con que se entrenó.
Además, las ventanas de un usuario se parecen entre sí más que a las de otro.

Cómo se evitó:

1. **División por usuario**: `GroupShuffleSplit` deja 12 de los 48 usuarios (con todas sus
   secuencias) solo para la prueba. `train.py` comprueba que ningún usuario ni secuencia esté
   en los dos lados.
2. **Validación cruzada agrupada**: `GroupKFold(5)` por usuario dentro de los 36 de
   entrenamiento, para elegir los hiperparámetros sin mirar la prueba.
3. La prueba se usa una sola vez, para el informe.

Medido (`metrics.json`, `fuga_de_datos`): exactitud de validación cruzada con ventanas sueltas
93,8 %, agrupada por usuario 93,7 %. **En estos datos la diferencia es mínima**: un modelo
lineal de 24 parámetros no tiene capacidad para memorizar, y los usuarios sintéticos varían
dentro de rangos acotados. Con datos reales, en los que cada persona se mueve a su manera, y
con modelos más grandes, la diferencia sí sería grande. Por eso la división por usuario es
obligatoria aunque aquí no cambie la cifra.

## 7. Entrenamiento y elección del modelo

- `StandardScaler` + `LogisticRegression` (lbfgs, softmax multinomial: con más de dos clases
  es lo que ajusta scikit-learn ≥ 1.5).
- **Peso de las clases**: ninguno, `balanced` o solo Cabeceo ×2, ×3, ×5, ×8. Lo elige la
  validación cruzada con un criterio que pesa más la **precisión** de Cabeceo: media de la F1
  de Activo, Normal e Inerte y la F0,5 de Cabeceo. En la app un falso Cabeceo baja el puntaje
  justo cuando el usuario mira el reloj, mientras que un cabeceo que el clasificador no ve
  igual dispara la alerta del detector. Elegido: **Cabeceo ×2**.
- **C** (13 valores entre 0,001 y 1 000): el criterio casi no cambia con C (menos que su
  desviación entre grupos), pero las probabilidades sí, y el puntaje de alerta las usa. Se
  toma el menor C que alcanza el mejor log-loss de ese peso (tolerancia 0,001): **C = 1**.
- **Plegado**: z = W(x − μ)/σ + b = (W/σ)·x + (b − W·μ/σ). `train.py` comprueba que los pesos
  plegados reproducen `predict_proba` (diferencia < 10⁻⁹).

Durante el desarrollo se probaron otros dos criterios: sin pesos de clase (F1 macro, el
primer `model_v2.json` del historial) el recall de Cabeceo caía al 29 %; con Cabeceo ×5
recuperaba el recall pero volvía a 16 de 48 falsos cabeceos. El criterio actual es el compromiso explícito
entre los dos.

## 8. Resultados v1 frente a v2

### 8.1 Python: mismo conjunto de prueba

12 usuarios no vistos, 4 310 ventanas, salida suavizada con la EMA del reloj
([ml/reports/report.md](../ml/reports/report.md)):

| Métrica | v1 (a mano) | v2 (entrenado) |
|---|---|---|
| **Exactitud** | 89,7 % | **93,3 %** |
| F1 macro | 0,811 | 0,820 |
| **Falsos cabeceos**, episodios de negativos difíciles | 16 de 48 (33,3 %) | **12 de 48 (25,0 %)** |
| — mirar la hora | 16 de 24 | 12 de 24 |
| — apoyar el brazo | 0 de 24 | 0 de 24 |
| Falsos cabeceos, ventanas de negativos difíciles | 3,9 % | 3,6 % |
| Cabeceo al pasar de tecleo a normal | 0 de 365 ventanas | 0 de 365 |
| F1 Activo / Normal / Inerte | 0,943 / 0,904 / 0,876 | 0,952 / 0,942 / 0,938 |
| Cabeceo: precisión / recall / F1 | 0,475 / 0,578 / 0,522 | 0,421 / 0,482 / 0,449 |

Un *episodio* es una secuencia de negativo difícil; cuenta como falso cabeceo si al menos una
de sus ventanas sale Cabeceo. La pantalla *Modelo IA* muestra la exactitud (93,3 %) y esta
tasa de episodios (25,0 %).

Lectura honesta:

- v2 mejora sobre todo **Normal e Inerte**: v1 tomaba por Inerte 208 ventanas Normales (la
  lectura con el brazo sostenido, apoyar el brazo); v2, 44.
- Los falsos cabeceos bajan, pero **mirar la hora sigue siendo difícil**: la mitad de esos
  episodios tienen al menos un lote tomado por Cabeceo.
- **v2 ve menos cabeceos que v1** (recall 0,48 frente a 0,58). Es el precio de priorizar la
  precisión, y el clasificador no decide la alerta. Con solo 83 ventanas de Cabeceo en la
  prueba, la diferencia es de unas 8 ventanas.
- Con otra semilla (`-Seed 7`: otro dataset, otra división) se repite el patrón: exactitud
  90,7 % → 93,3 %, falsos cabeceos 16 → 13 de 48.

### 8.2 Reloj: matriz de confusión en los escenarios del simulador

`classifierConfusionMatrixOnSimulatedScenarios` pasa por la cadena del reloj los escenarios
del simulador (tecleo, normal, cabeceo, inactividad y el nuevo *mirar la hora*, con 5
semillas) y una guardia mixta, con v1 plegado y con v2:

| | v1 | v2 |
|---|---|---|
| Exactitud | 978 de 1 050 = 93,1 % | **1 032 de 1 050 = 98,3 %** (98,4 % antes de la transición de postura de la fase 11) |
| Normal (incluye mirar la hora) | 412 de 475 (59 lotes de lectura tomados por Inerte) | 472 de 475 |
| Lotes de *mirar la hora* tomados por Cabeceo | 0 de 175 | 0 de 175 |
| Cabeceo al pasar de tecleo a normal | 0 | 0 |

A v2 se le exige lo mismo que a v1: la diagonal gana en cada fila, más del 90 % de acierto y
nunca Activo con Inerte. Además, 0 cabeceos al mirar la hora y al dejar de teclear.

### 8.3 Simulador (fr165, compilación de depuración y de release, español e inglés)

- **Mirar la hora**: 31 de 31 lotes Normal (español) y 32 de 32 (inglés); ningún evento. Al
  leer, p(Inerte) sube como mucho a 0,40.
- **Tecleo → normal**: ningún lote Cabeceo ni evento.
- **Cabeceo**: Normal → Cabeceo (0,51 y 0,64 con la caída pendiente) → evento a los 6 s →
  Inerte.
- **Guion automático completo** en los dos idiomas: alertas en los pasos 3 y 5, escalamiento
  a nivel 3 en el paso 6 y resumen automático (3 episodios, nivel máximo 3 de 3, fatiga Alto).

## 9. Limitaciones

- **Datos sintéticos.** El modelo aprende el generador. Si el movimiento real no se parece a
  las firmas del simulador (ruido del sensor, temblor al leer, cómo cae de verdad un brazo
  dormido), las cifras no valen. Es la limitación principal.
- **Sin giroscopio.** El fr165 no tiene; la postura sale solo de la gravedad media de 2 s. Un
  giro rápido de muñeca y una caída se distinguen peor de lo que se distinguirían con
  velocidad angular.
- **Las mismas 5 características de v1.** Son las que el reloj ya calcula; un modelo lineal
  sobre ellas no puede separar del todo mirar la hora de un cabeceo (el 50 % de esos
  episodios todavía da algún lote Cabeceo).
- **El clasificador filtra, pero no detecta.** Los eventos los da el detector por reglas.
  Desde la fase 11 el modelo confirma cada cabeceo (§12) y los falsos al mirar la hora bajan
  de 15 a 3 de 24, pero no puede añadir cabeceos que la regla no ve: el recall sigue en el
  61 % (22 de 36), porque los de caída lenta no llegan a 400 mg. La confirmación también
  retrasa 2 s la alerta de cabeceo.
- **Pocas ventanas de Cabeceo** (345 en total, 83 en la prueba): las métricas de esa clase
  tienen mucha incertidumbre.
- Las etiquetas son exactas porque el generador las conoce; con datos reales habrá ruido de
  etiquetado.

## 10. Trabajo futuro

1. **Datos reales.** Grabar el acelerómetro en el reloj con `SensorLogging` (y a la vez vídeo
   o un pulsador del observador para etiquetar), importarlo con `ml/import_real.py` (CSV ya
   implementado; FIT documentado) y repetir el pipeline sin cambios. Mantener la división por
   usuario y la prueba de equivalencia.
2. ~~Que el detector pida confirmación al modelo~~ — hecho en la fase 11 (§12). Siguiente
   paso: entrenar directamente la decisión del evento (con las etiquetas en el instante de
   la decisión) para ganar también recall de cabeceos y quitar el retraso de 2 s.
3. **Características nuevas** (dirección final de la gravedad, energía por eje, varianza de la
   inclinación) y modelos un poco más grandes, solo con datos reales y midiendo en el reloj el
   costo en memoria y CPU.
4. Calibrar las probabilidades con datos reales (el puntaje de alerta las usa directamente).

## 11. Pruebas relacionadas

| Prueba | Qué comprueba |
|---|---|
| `featuresMatchPythonVectors` | Eventos y características iguales en Python y en el reloj. |
| `classifierMatchesPythonProbabilities` | Probabilidades iguales con los pesos exportados. |
| `classifierWeightTableHasTheRightShape` | Forma de v2 y v1, versión, métricas en rango. |
| `classifierSoftmaxSeparatesTypicalFeatures` | Puntos típicos de cada clase (mirar la hora con ventanas medidas → Normal). |
| `classifierTopClassMatchesScenario` | Clase y probabilidad > 0,9 en cada escenario; Cabeceo con la caída pendiente. |
| `classifierConfusionMatrixOnSimulatedScenarios` | Matriz v1 y v2 en el reloj (§8.2). |
| `simulatedGlanceTurnsTheWristAndHoldsIt`, `detectorGlanceAtWatchTwoMinutesHasNoNod` | Firma del escenario *mirar la hora* y 0 eventos en 2 min. |
| `modelInfoShowsPercentWithOneDecimal` | Formato de la pantalla *Modelo IA* en los dos idiomas. |
| `nodConfirmation*` (fase 11) | Confirmación: retardo y umbral, desactivada, cabeceo real con alerta a los 8 s, mirar la hora tras teclear descartado, inactividad sin modelo. |

## 12. Confirmación del cabeceo por el modelo (fase 11)

**Regla.** Un evento CABECEO del detector abre la alerta solo si, **2 lotes (2 s)
después**, la probabilidad **suavizada de Normal** es **menor que 0,35**
(`NodConfirmation.DELAY_BATCHES`, `NORMAL_MAX`). Es la forma "Normal no es la clase
dominante" de la idea: el brazo que cayó dormido pasa a Inerte en un par de segundos; el
que mira la hora vuelve a Normal. La inactividad no pasa por el modelo. Se puede
desactivar (ajuste *Confirmación por IA*).

**Cómo se eligió** (`ml/confirmation.py`, lo corre `scripts\train.ps1`). Reproduce sobre
el dataset sintético la regla del detector y la confirmación con las mismas ventanas,
eventos y EMA que el reloj, y elige con los **36 usuarios de entrenamiento**, sin mirar la
prueba:

1. retardo de 2 s como máximo (más espera retrasa una alerta que tiene que ser rápida);
2. para cada retardo, el **menor** umbral de la rejilla 0,20–0,60 que confirma **todos** los
   cabeceos de entrenamiento que ve la regla;
3. gana el que menos falsos deja al mirar la hora y, si empatan, el de mayor AUC.

| Retardo | Umbral | Falsos en mirar la hora (entrenamiento, de 72) | AUC p(Normal) cabeceo / mirar la hora |
|---|---|---|---|
| 0 s | 0,55 | 23 | 0,900 |
| 1 s | 0,40 | 5 | 0,954 |
| **2 s** | **0,35** | **5** | **0,964** |

**Resultado en los 12 usuarios de prueba** ([ml/reports/confirmation.md](../ml/reports/confirmation.md)):

| Conjunto de prueba sintético (12 usuarios no vistos) | Regla sola (fases 6–10) | Regla + confirmación (fase 11) |
|---|---|---|
| Falsos cabeceos en *mirar la hora* (secuencias con alerta de cabeceo) | **15 de 24** (62,5 %) | **3 de 24** (12,5 %) |
| Recall de cabeceos reales (secuencias de cabeceo con alerta) | **22 de 36** (61,1 %) | **22 de 36** (61,1 %) |
| Falsos cabeceos en el resto (apoyar el brazo, mixtas, tecleo → normal, inactividad) | 0 | 0 |
| Retraso de la alerta de cabeceo | — | + 2 s |

**Compromiso.** No se pierde recall de cabeceos (los 22 que la regla ve se confirman todos),
a cambio de **2 s más** hasta la alerta de cabeceo. Con un umbral más bajo (0,30) quedarían
2 de 24 falsos con el mismo recall en la prueba, pero en entrenamiento se perdía un
cabeceo, así que no se elige: el criterio no puede mirar la prueba.

**Alternativa descartada: p(Cabeceo) máxima ≥ θ en la ventana del evento.** En el
instante del evento las dos situaciones tienen casi la misma p(Cabeceo): con θ = 0,5 quedan
10 de 24 falsos, pero el recall cae a 16 de 36; con 0,3, 15 de 24 falsos y 21 de 36.

**En el reloj.** `nodConfirmationRejectsGlanceAfterTyping` reproduce la mirada a la hora
justo tras teclear con la fuente simulada: la regla da un cabeceo en las 5 semillas y el
modelo lo descarta (p(Normal) ≈ 0,6); `nodConfirmationAlertsOnRealNod`: el cabeceo
simulado se confirma (alerta a los 8 s). En el simulador, con sensibilidad Alta (el giro de
366 mg ya abre la caída), *mirar la hora* dio eventos CABECEO descartados con p(Normal) 0,70
y 0,59 y ninguna alerta; con la confirmación desactivada, alerta. Con la sensibilidad media,
el cabeceo se confirmó con p(Normal) 0,14. El guion automático sigue dando alertas en los
pasos 3 y 5 y nivel 3 en el 6.

**Límites.** Datos sintéticos; el retraso de 2 s y el umbral se revisarán con datos
reales (trabajo futuro, [PENDIENTES.md](PENDIENTES.md)). Los 3 falsos que quedan son lecturas con el brazo casi inmóvil, que el
modelo ve como Inerte.
