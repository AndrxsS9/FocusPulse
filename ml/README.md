# /ml — Entrenamiento del clasificador de estado

Pipeline reproducible en Python que entrena los pesos **v2** del clasificador del reloj
(`StateClassifier`: Activo / Normal / Cabeceo / Inerte) y los exporta a Monkey C. Esta
carpeta **no forma parte del paquete del reloj**: el compilador de Connect IQ solo usa
`source/`, `tests/` y `resources*/` (ver `monkey.jungle`).

> **Los datos son SINTÉTICOS.** `generate_dataset.py` los fabrica a partir de las firmas de
> movimiento del simulador del reloj (`SimulatedAccelSource`), con variaciones por usuario.
> No hay ni una muestra de una muñeca real. Las métricas de `reports/` sirven para comparar
> v1 con v2 en igualdad de condiciones y para comprobar que el pipeline funciona; **no son
> la precisión de la app en el mundo real.** El porqué y las limitaciones están en
> [docs/IA.md](../docs/IA.md).

## Cómo entrenar, paso a paso

Desde la raíz del repositorio, en PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\train.ps1
```

1. **Python 3.12.** Si no está, el script lo dice; se instala con
   `winget install Python.Python.3.12`.
2. **Entorno virtual.** La primera vez crea `ml\.venv` con `py -3.12 -m venv`; después
   reutiliza el que hay. No hace falta activarlo a mano: el script llama a
   `ml\.venv\Scripts\python.exe` directamente.
3. **Dependencias** de `requirements.txt` (versiones fijas: numpy, pandas, scikit-learn,
   matplotlib).
4. **Dataset** (`generate_dataset.py`): 48 usuarios sintéticos, 528 secuencias, ≈ 450 000
   muestras a 25 Hz en `ml\data\` (no se versionan; se regeneran idénticas con la misma
   semilla).
5. **Entrenamiento y evaluación** (`train.py` + `evaluate.py`): características con
   `features.py`, división por usuario, validación cruzada agrupada, regresión logística
   multinomial, pesos con la estandarización plegada y comparación v1 frente a v2 en el mismo
   conjunto de prueba. Escribe `models\model_v2.json` y `reports\`.
   Después, `confirmation.py` elige con los usuarios de entrenamiento el retardo y el
   umbral con que el modelo confirma los cabeceos del detector y mide el efecto en la
   prueba (`reports\confirmation.md`).
6. **Exportación** (`export_weights.py`): reescribe `source\core\ClassifierWeights.mc`
   (GENERADO, no editar a mano), `tests\ModelVectors.mc` y `tests\FeatureVectors.mc`.
7. Compilar y probar en el reloj: `scripts\build.ps1` y `scripts\test.ps1`.

Tarda unos 30 s. Con la misma semilla el resultado es idéntico bit a bit: si nada cambió,
`git status` queda limpio después de correrlo.

| Opción | Efecto |
|---|---|
| `-Seed 7` | Otra semilla para el dataset, la división y el entrenamiento (por defecto `20261114`). |
| `-NoExport` | Entrena y evalúa, pero no toca `source\` ni `tests\`. Ojo: sí reescribe `ml\models\` y `ml\reports\`, que están versionados; para volver a los oficiales, `git checkout -- ml/models ml/reports`. |

## Archivos

| Archivo | Qué hace |
|---|---|
| `requirements.txt` | Dependencias con versión fija. |
| `generate_dataset.py` | Dataset sintético: usuarios con su propia amplitud, ruido, ritmo de tecleo y forma del cabeceo; orientación aleatoria de la muñeca; transiciones entre estados; **negativos difíciles** etiquetados Normal (mirar la hora y quedarse leyendo, apoyar el brazo despacio). El usuario 0 usa exactamente las constantes del simulador. |
| `features.py` | Las 5 características del reloj, traducidas línea a línea de `TelemetryEngine`, `SlidingWindow`, `DrowsinessDetector` y `Baseline` (con `float32` donde Monkey C usa `Float`). Etiqueta cada ventana. |
| `test_vectors.py` | Exporta muestras fijas con sus características y eventos esperados a `tests/FeatureVectors.mc`; la prueba `featuresMatchPythonVectors` comprueba en el reloj que coinciden. |
| `train.py` | División por usuario, `GroupKFold`, elección de C y del peso de las clases, plegado de la estandarización, `models/model_v2.json`. |
| `evaluate.py` | Métricas de v1 y v2 con la misma EMA que el reloj, informe y gráficas. |
| `confirmation.py` | Confirmación del cabeceo por el modelo (fase 11): reproduce la regla y la confirmación, elige retardo y umbral con el entrenamiento y mide falsos cabeceos al mirar la hora y recall de cabeceos, también con las tres sensibilidades. `reports/confirmation.md` y `.json`. |
| `export_weights.py` | Genera `ClassifierWeights.mc` y `tests/ModelVectors.mc`. |
| `import_real.py` | **Esqueleto** para importar datos reales futuros (CSV implementado; FIT de SensorLogging por hacer). No se ejecuta en el pipeline. |
| `data/` | Dataset generado (ignorado por git, salvo su README). |
| `models/model_v2.json` | Pesos plegados, estandarización original, hiperparámetros y resultados de la validación cruzada. |
| `reports/` | `report.md`, `metrics.json`, `confusion_v1.png`, `confusion_v2.png`, `per_class_v1_v2.png`, `confirmation.md`, `confirmation.json`. |

## Resultado actual (semilla 20261114)

Conjunto de prueba: 12 usuarios sintéticos que el entrenamiento no vio (4 310 ventanas),
salida suavizada como en el reloj. Detalle en [reports/report.md](reports/report.md).

| | v1 (a mano) | v2 (entrenado) |
|---|---|---|
| Exactitud | 89,7 % | 93,3 % |
| F1 macro | 0,811 | 0,820 |
| Falsos cabeceos (episodios de negativos difíciles) | 16 de 48 (33,3 %) | 12 de 48 (25,0 %) |

## Datos reales (trabajo futuro)

`import_real.py --csv grabacion.csv --labels etiquetas.csv --user 101` convierte una
grabación etiquetada al mismo formato (`ml\data\real\`), así el resto del pipeline sirve sin
cambios. Leer el FIT de `SensorLogging` está documentado pero sin implementar. Ver
[docs/IA.md](../docs/IA.md) §8.
