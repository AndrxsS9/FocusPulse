# Confirmación del cabeceo por el modelo

> **Datos sintéticos** (`ml/generate_dataset.py`). Las cifras comparan la regla sola con
> la regla + confirmación en igualdad de condiciones; **no son precisión en muñecas reales**.

Generado por `ml/confirmation.py` con el modelo `v2` (semilla 20261114).

## Regla elegida

Un evento CABECEO del detector por reglas abre la alerta solo si, **2 lotes
(2 s) después**, la probabilidad suavizada de **Normal** es menor que
**0,35**. La inactividad no pasa por el modelo.

Elegida con los usuarios de **entrenamiento** (retardo de 2 s como máximo; para cada
retardo, el menor umbral que confirma todos sus cabeceos; gana el que menos falsos deja en
*mirar la hora* y, si empatan, el de mayor AUC):

| Retardo | Umbral | Falsos en mirar la hora (entrenamiento) | AUC p(Normal), cabeceo frente a mirar la hora |
|---|---|---|---|
| 0 s | 0,55 | 23 | 0,900 |
| 1 s | 0,40 | 5 | 0,954 |
| 2 s | 0,35 | 5 | 0,964 |

## Resultado en la prueba (12 usuarios no vistos)

| | Regla sola | Regla + confirmación |
|---|---|---|
| Falsos cabeceos en *mirar la hora* | **15 de 24** (62,5 %) | **3 de 24** (12,5 %) |
| Recall de cabeceos reales (secuencias) | **22 de 36** (61,1 %) | **22 de 36** (61,1 %) |
| Falsos cabeceos en el resto (apoyar el brazo, mixtas, tecleo → normal, inactividad) | 0 | 0 |
| Retraso de la alerta de cabeceo | — | + 2 s |

En entrenamiento (36 usuarios): mirar la hora 31 de 72 → 5 de 72,
cabeceos 67 de 108 → 67 de 108.

El recall de cabeceos lo limita el detector por reglas (las caídas lentas no llegan a la
sacudida mínima): la confirmación no puede recuperar cabeceos que la regla no ve; solo
filtra los que ve.

### Rejilla de umbrales con el retardo elegido (prueba, solo informativa)

| Retardo | Umbral | Cabeceos | Mirar la hora | Otros falsos |
|---|---|---|---|---|
| 2 s | 0,20 | 16 de 36 | 2 de 24 | 0 |
| 2 s | 0,25 | 20 de 36 | 2 de 24 | 0 |
| 2 s | 0,30 | 22 de 36 | 2 de 24 | 0 |
| 2 s | 0,35 | 22 de 36 | 3 de 24 | 0 |
| 2 s | 0,40 | 22 de 36 | 6 de 24 | 0 |
| 2 s | 0,45 | 22 de 36 | 6 de 24 | 0 |
| 2 s | 0,50 | 22 de 36 | 7 de 24 | 0 |
| 2 s | 0,55 | 22 de 36 | 7 de 24 | 0 |
| 2 s | 0,60 | 22 de 36 | 7 de 24 | 0 |

### Alternativa descartada: p(Cabeceo) máxima ≥ θ en la ventana del evento (prueba)

| Umbral | Cabeceos | Mirar la hora |
|---|---|---|
| 0,30 | 21 de 36 | 15 de 24 |
| 0,40 | 20 de 36 | 15 de 24 |
| 0,50 | 16 de 36 | 10 de 24 |
| 0,60 | 10 de 36 | 7 de 24 |
| 0,70 | 3 de 36 | 5 de 24 |

En el instante del evento la p(Cabeceo) de una mirada a la hora y la de un cabeceo son
casi iguales: cualquier umbral que quita falsos también quita cabeceos.

## Por sensibilidad del detector (prueba, con la regla elegida)

| Sensibilidad | Cabeceos, regla | Cabeceos, + confirmación | Mirar la hora, regla | Mirar la hora, + confirmación | Otros falsos |
|---|---|---|---|---|---|
| Baja | 17 de 36 | 17 de 36 | 13 de 24 | 2 de 24 | 0 → 0 |
| Media | 22 de 36 | 22 de 36 | 15 de 24 | 3 de 24 | 0 → 0 |
| Alta | 30 de 36 | 30 de 36 | 17 de 24 | 4 de 24 | 0 → 0 |
