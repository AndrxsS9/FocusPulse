"""Exporta el modelo v2 a Monkey C.

Lee ml/models/model_v2.json (train.py) y ml/reports/metrics.json (evaluate.py) y escribe:

- source/core/ClassifierWeights.mc: COEF e INTERCEPT con la estandarización ya plegada
  (z = COEF · x + INTERCEPT), la versión, la fecha, la semilla, el tamaño del dataset y
  las métricas que muestra la pantalla "Modelo IA" (exactitud y falsos cabeceos).
- tests/ModelVectors.mc: unas ventanas del conjunto de prueba con las probabilidades que
  da Python, para comprobar en el reloj que la softmax y los pesos coinciden.
- tests/FeatureVectors.mc: los vectores de características (test_vectors.py).

Los números se escriben como Float de Monkey C en notación decimal (sin exponente), que
compila sin errores con -l 3.

Uso:  python export_weights.py
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd

import features
import test_vectors
from test_vectors import mc_float

ML_DIR = Path(__file__).resolve().parent
ROOT = ML_DIR.parent
MODEL_FILE = ML_DIR / "models" / "model_v2.json"
METRICS_FILE = ML_DIR / "reports" / "metrics.json"
WINDOWS_FILE = ML_DIR / "data" / "windows.csv"
WEIGHTS_FILE = ROOT / "source" / "core" / "ClassifierWeights.mc"
MODEL_VECTORS_FILE = ROOT / "tests" / "ModelVectors.mc"

CLASS_ROWS = ("Activo", "Normal", "Cabeceo", "Inerte")
VECTORS_PER_CLASS = 4


def mc_row(values) -> str:
    return "[" + ", ".join(mc_float(v) for v in values) + "]"


def write_weights(model: dict, metrics: dict) -> None:
    v2 = metrics["v2"]
    dataset = model["dataset"]
    accuracy = v2["smooth"]["exactitud"]
    false_nods = v2["falsos_cabeceos"]
    coef_rows = ",\n".join(f"        {mc_row(row)}" for row in model["coef"])
    feature_list = ", ".join(model["caracteristicas"])
    text = f"""import Toybox.Lang;

//! GENERADO por ml/export_weights.py, no editar a mano. Para cambiarlo, vuelve a
//! entrenar con scripts\\train.ps1 (ver ml/README.md y docs/IA.md).
//!
//! Pesos {model['version']} del clasificador de estado (StateClassifier): regresión logística
//! multinomial con 4 clases, entrenada el {model['fecha']} con semilla {model['semilla']} sobre
//! {dataset['ventanas']} ventanas de {dataset['usuarios']} usuarios ({dataset['secuencias']} secuencias).
//! Exactitud en la prueba (usuarios separados, salida suavizada): {100 * accuracy:.1f} %.
//!
//! **Datos SINTÉTICOS** (ml/generate_dataset.py, a partir de las firmas del simulador):
//! las métricas no son precisión en muñecas reales.
//!
//! La estandarización (StandardScaler) ya va plegada en los pesos, así que el reloj
//! calcula directamente, con x sin normalizar:
//!
//!     z = COEF · x + INTERCEPT,   p = softmax(z)
//!
//! - Filas: clases en el orden de DrowsinessClass (Activo, Normal, Cabeceo, Inerte).
//! - Columnas: características en el orden de StateClassifier.FEATURE_*
//!   ({feature_list}).
//!
//! Los pesos v1 (a mano) siguen en ClassifierWeightsV1.mc como referencia.
module ClassifierWeights {{

    //! Identificador de los pesos.
    const VERSION = "{model['version']}";

    //! Fecha del entrenamiento y semilla del dataset y de la división.
    const TRAINED_ON = "{model['fecha']}";
    const SEED = {model['semilla']};

    //! Tamaño del dataset sintético.
    const DATASET_WINDOWS = {dataset['ventanas']};
    const DATASET_USERS = {dataset['usuarios']};

    //! Exactitud en el conjunto de prueba (0–1), como la ve el reloj (con la EMA).
    const TEST_ACCURACY = {mc_float(accuracy)};

    //! Falsos cabeceos en los negativos difíciles de la prueba (mirar la hora, apoyar el
    //! brazo): fracción de episodios con al menos una ventana tomada por Cabeceo
    //! ({false_nods['episodios_con_cabeceo']} de {false_nods['episodios']}) y fracción de ventanas.
    const FALSE_NOD_RATE = {mc_float(false_nods['tasa_episodios'])};
    const FALSE_NOD_WINDOW_RATE = {mc_float(false_nods['tasa_ventanas'])};

    //! Una fila por clase: Activo, Normal, Cabeceo, Inerte.
    const COEF = [
{coef_rows}
    ];

    const INTERCEPT = {mc_row(model['intercept'])};
}}
"""
    WEIGHTS_FILE.write_text(text, encoding="utf-8", newline="\n")
    print(f"Pesos {model['version']} → {WEIGHTS_FILE.relative_to(ROOT)}")


def write_model_vectors(model: dict) -> None:
    """Ventanas de prueba de cada clase con sus probabilidades según Python."""
    windows = pd.read_csv(WINDOWS_FILE)
    test = windows[windows["usuario"].isin(model["dataset"]["usuarios_prueba"])]
    picked = pd.concat([
        group.sample(min(VECTORS_PER_CLASS, len(group)), random_state=model["semilla"])
        for _, group in test.groupby("clase")
    ])
    x = picked[list(features.FEATURE_NAMES)].to_numpy()
    z = x @ np.array(model["coef"]).T + np.array(model["intercept"])
    z -= z.max(axis=1, keepdims=True)
    p = np.exp(z) / np.exp(z).sum(axis=1, keepdims=True)
    feature_rows = ",\n".join(f"        {mc_row(row)}" for row in x)
    probability_rows = ",\n".join(f"        {mc_row(row)}" for row in p)
    text = f"""import Toybox.Lang;

//! GENERADO por ml/export_weights.py, no editar a mano.
//!
//! Ventanas del conjunto de prueba (datos SINTÉTICOS), {VECTORS_PER_CLASS} por clase, con las
//! probabilidades sin suavizar que calcula Python con los pesos {model['version']}.
//! classifierMatchesPythonProbabilities (StateClassifierTest.mc) comprueba que
//! StateClassifier.probabilitiesInto da lo mismo en el reloj.
(:test)
class ModelVectors {{

    //! Versión de ClassifierWeights con la que se calcularon.
    static const VERSION = "{model['version']}";

    //! Características sin normalizar, en el orden de StateClassifier.FEATURE_*.
    static const FEATURES = [
{feature_rows}
    ];

    //! Probabilidades de Activo, Normal, Cabeceo e Inerte.
    static const PROBABILITIES = [
{probability_rows}
    ];
}}
"""
    MODEL_VECTORS_FILE.write_text(text, encoding="utf-8", newline="\n")
    print(f"Vectores del modelo: {len(picked)} ventanas → {MODEL_VECTORS_FILE.relative_to(ROOT)}")


def main() -> None:
    model = json.loads(MODEL_FILE.read_text(encoding="utf-8"))
    metrics = json.loads(METRICS_FILE.read_text(encoding="utf-8"))
    write_weights(model, metrics)
    write_model_vectors(model)
    test_vectors.write_feature_vectors()


if __name__ == "__main__":
    main()
