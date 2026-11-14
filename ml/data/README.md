# ml/data — dataset sintético (no versionado)

`generate_dataset.py` escribe aquí el dataset. Pesa varias decenas de MB y se regenera
idéntico con la misma semilla, así que git lo ignora (solo se versiona este archivo):

| Archivo | Contenido |
|---|---|
| `samples.csv` | Una fila por muestra de 25 Hz: `t` (ms desde el inicio de la secuencia), `x`, `y`, `z` (mg enteros), `etiqueta` (`activo`, `normal`, `cabeceo`, `inerte`), `usuario`, `secuencia`. |
| `sequences.csv` | Una fila por secuencia: usuario, guion de segmentos, modo demo, si es un negativo difícil y de qué tipo. |
| `windows.csv` | Lo escribe `train.py`: las 5 características de cada lote de 1 s (`features.py`), su etiqueta y su grupo. |

Los datos son **sintéticos**: salen de las firmas de movimiento del simulador
(`SimulatedAccelSource`), no de muñecas reales.
