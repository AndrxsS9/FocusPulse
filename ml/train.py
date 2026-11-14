"""Entrena el clasificador de estado v2: regresión logística multinomial.

Pasos:

1. Lee el dataset SINTÉTICO de ml/data/ y calcula las 5 características de cada lote
   con features.py (las mismas que el reloj). Guarda las ventanas en data/windows.csv.
2. Divide **por usuario**: el 25 % de los usuarios sintéticos queda para la prueba, con
   todas sus secuencias. Nunca se reparten ventanas sueltas: dos ventanas seguidas de
   una misma secuencia comparten 1 s de muestras y casi todo el estado del detector, así
   que repartirlas daría una exactitud inflada (fuga de datos).
3. Elige C (y el peso de las clases) con validación cruzada agrupada por usuario
   (GroupKFold) sobre los usuarios de entrenamiento, con la F1 macro.
4. Ajusta StandardScaler + LogisticRegression con lo elegido y **pliega** la media y la
   desviación dentro de los pesos:

       z = W · (x − μ) / σ + b  =  (W / σ) · x + (b − W · μ / σ)

   así el reloj calcula z = COEF · x + INTERCEPT directamente, sin estandarizar.
5. Guarda el modelo en models/model_v2.json (lo lee export_weights.py).

Uso:  python train.py --seed 20261114
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import GridSearchCV, GroupKFold, GroupShuffleSplit
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

import features

ML_DIR = Path(__file__).resolve().parent
DATA_DIR = ML_DIR / "data"
MODEL_FILE = ML_DIR / "models" / "model_v2.json"

TEST_FRACTION = 0.25
CV_FOLDS = 5
C_GRID = [float(c) for c in np.logspace(-2, 3, 11)]
CLASS_WEIGHT_GRID = [None, "balanced"]


def load_windows(data_dir: Path = DATA_DIR) -> pd.DataFrame:
    samples = pd.read_csv(data_dir / "samples.csv")
    sequences = pd.read_csv(data_dir / "sequences.csv")
    windows = features.dataset_windows(samples, sequences)
    windows.to_csv(data_dir / "windows.csv", index=False)
    return windows


def split_by_user(windows: pd.DataFrame, seed: int) -> tuple[np.ndarray, np.ndarray]:
    """Índices de entrenamiento y prueba con los usuarios separados."""
    splitter = GroupShuffleSplit(n_splits=1, test_size=TEST_FRACTION, random_state=seed)
    train, test = next(splitter.split(windows, groups=windows["usuario"]))
    overlap = set(windows["usuario"].iloc[train]) & set(windows["usuario"].iloc[test])
    assert not overlap, f"usuarios en los dos conjuntos: {overlap}"
    overlap = set(windows["secuencia"].iloc[train]) & set(windows["secuencia"].iloc[test])
    assert not overlap, f"secuencias en los dos conjuntos: {overlap}"
    return train, test


def make_pipeline(c: float = 1.0, class_weight=None) -> Pipeline:
    # Con lbfgs y más de dos clases, LogisticRegression ajusta la softmax multinomial
    # (scikit-learn ≥ 1.5 ya no tiene el parámetro multi_class).
    return Pipeline([
        ("scaler", StandardScaler()),
        ("logreg", LogisticRegression(C=c, class_weight=class_weight, max_iter=5000)),
    ])


def grouped_search(x: np.ndarray, y: np.ndarray, groups: np.ndarray) -> GridSearchCV:
    search = GridSearchCV(
        make_pipeline(),
        {"logreg__C": C_GRID, "logreg__class_weight": CLASS_WEIGHT_GRID},
        cv=GroupKFold(n_splits=CV_FOLDS),
        scoring="f1_macro",
        refit=True,
    )
    search.fit(x, y, groups=groups)
    return search


def fold_standardization(pipeline: Pipeline) -> tuple[np.ndarray, np.ndarray]:
    """Pesos y sesgos con la estandarización plegada (para x sin estandarizar)."""
    scaler: StandardScaler = pipeline.named_steps["scaler"]
    logreg: LogisticRegression = pipeline.named_steps["logreg"]
    coef = logreg.coef_ / scaler.scale_
    intercept = logreg.intercept_ - coef @ scaler.mean_
    return coef, intercept


def softmax(z: np.ndarray) -> np.ndarray:
    z = z - z.max(axis=1, keepdims=True)
    e = np.exp(z)
    return e / e.sum(axis=1, keepdims=True)


def raw_probabilities(x: np.ndarray, coef: np.ndarray, intercept: np.ndarray) -> np.ndarray:
    """StateClassifier.probabilitiesInto: softmax(COEF · x + INTERCEPT), sin suavizar."""
    return softmax(x @ coef.T + intercept)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--seed", type=int, default=20261114)
    args = parser.parse_args()

    windows = load_windows()
    names = list(features.FEATURE_NAMES)
    x = windows[names].to_numpy()
    y = windows["clase"].to_numpy()
    users = windows["usuario"].to_numpy()
    train, test = split_by_user(windows, args.seed)
    print(f"Ventanas: {len(windows)} ({len(train)} de entrenamiento, {len(test)} de prueba); "
          f"usuarios: {len(set(users[train]))} + {len(set(users[test]))}")

    search = grouped_search(x[train], y[train], users[train])
    best = search.best_params_
    print(f"Validación cruzada agrupada ({CV_FOLDS} grupos de usuarios): mejor C = "
          f"{best['logreg__C']:.4g}, class_weight = {best['logreg__class_weight']}, "
          f"F1 macro = {search.best_score_:.4f}")

    pipeline: Pipeline = search.best_estimator_
    coef, intercept = fold_standardization(pipeline)
    check = np.abs(raw_probabilities(x[test], coef, intercept) - pipeline.predict_proba(x[test])).max()
    assert check < 1e-9, f"los pesos plegados no reproducen el modelo: {check}"

    cv = search.cv_results_
    model = {
        "version": "v2",
        "tipo": "LogisticRegression multinomial (lbfgs), 4 clases",
        "fecha": dt.date.today().isoformat(),
        "semilla": args.seed,
        "datos": "SINTÉTICOS (ml/generate_dataset.py), no de muñecas reales",
        "caracteristicas": names,
        "clases": list(features.LABELS),
        "coef": coef.tolist(),
        "intercept": intercept.tolist(),
        "estandarizacion_plegada": {
            "media": pipeline.named_steps["scaler"].mean_.tolist(),
            "desviacion": pipeline.named_steps["scaler"].scale_.tolist(),
            "coef_estandarizado": pipeline.named_steps["logreg"].coef_.tolist(),
            "intercept_estandarizado": pipeline.named_steps["logreg"].intercept_.tolist(),
        },
        "hiperparametros": {"C": best["logreg__C"], "class_weight": best["logreg__class_weight"]},
        "validacion_cruzada": {
            "esquema": f"GroupKFold({CV_FOLDS}) por usuario, F1 macro",
            "mejor_f1_macro": float(search.best_score_),
            "resultados": [
                {"C": p["logreg__C"], "class_weight": p["logreg__class_weight"],
                 "f1_macro": float(m), "desviacion": float(s)}
                for p, m, s in zip(cv["params"], cv["mean_test_score"], cv["std_test_score"])
            ],
        },
        "dataset": {
            "ventanas": int(len(windows)),
            "usuarios": int(windows["usuario"].nunique()),
            "secuencias": int(windows["secuencia"].nunique()),
            "ventanas_entrenamiento": int(len(train)),
            "ventanas_prueba": int(len(test)),
            "usuarios_prueba": sorted(int(u) for u in set(users[test])),
        },
    }
    MODEL_FILE.parent.mkdir(parents=True, exist_ok=True)
    MODEL_FILE.write_text(json.dumps(model, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Modelo guardado en {MODEL_FILE.relative_to(ML_DIR.parent)}")


if __name__ == "__main__":
    main()
