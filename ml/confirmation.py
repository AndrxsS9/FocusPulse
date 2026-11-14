"""Confirmación del cabeceo por el modelo (fase 11): elige el retardo y el umbral y mide
su efecto sobre el detector por reglas.

En la app, un evento CABECEO del detector por reglas (DrowsinessDetector) solo abre la
alerta si el clasificador v2 lo confirma (NodConfirmation.mc). La inactividad no pasa
por el modelo. Este script reproduce las dos cosas sobre el dataset SINTÉTICO, con las
ventanas y los eventos que calcula features.py (idénticos al reloj) y la misma EMA de
StateClassifier, y mide antes y después:

- falsos cabeceos en las secuencias de *mirar la hora* (episodios con algún evento
  CABECEO que abriría la alerta);
- recall de los cabeceos reales (secuencias de *cabeceo* con algún evento confirmado);
- falsos cabeceos en el resto (apoyar el brazo, guardias mixtas, tecleo → normal…).

**Regla.** Al llegar el evento, la confirmación espera D lotes (D s) y mira la
probabilidad **suavizada de Normal** en ese lote: si es menor que θ, el cabeceo se
confirma; si no, se descarta. Es la forma "Normal no es la clase dominante" de la
consigna: un brazo que cayó dormido pasa a Inerte en un par de segundos, uno que mira la
hora vuelve a Normal. Se compara con la alternativa "p(Cabeceo) máxima ≥ θ" en la
ventana del evento, que no separa los dos casos (en el instante del evento las dos
secuencias tienen casi la misma p(Cabeceo)).

**Elección sin mirar la prueba.** D y θ se eligen con los 36 usuarios de
entrenamiento:

1. D ≤ MAX_DELAY_BATCHES (2 s): más espera retrasa una alerta que tiene que ser rápida.
2. Para cada D, θ es el **menor** valor de la rejilla que confirma todos los cabeceos de
   entrenamiento que el detector ve (no perder ninguno).
3. Entre los D, el que menos falsos cabeceos deja en *mirar la hora*; si empatan, el de
   mayor AUC entre p(Normal) de cabeceos y de miradas (separa mejor, más margen).

Los 12 usuarios de prueba (los de model_v2.json) solo se usan para el informe.

Además se repite la medición con las tres sensibilidades del detector (Baja, Media,
Alta; DetectorThresholds.mc), con el modelo entrenado en Media.

Salidas: ml/reports/confirmation.json y ml/reports/confirmation.md. Datos SINTÉTICOS.

Uso:  python confirmation.py      (lo llama scripts\\train.ps1 después de train.py)
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.metrics import roc_auc_score

import evaluate
import features

ML_DIR = Path(__file__).resolve().parent
DATA_DIR = ML_DIR / "data"
MODEL_FILE = ML_DIR / "models" / "model_v2.json"
REPORTS_DIR = ML_DIR / "reports"

DELAYS = (0, 1, 2, 3)
THRESHOLDS = tuple(round(0.20 + 0.05 * i, 2) for i in range(9))  # 0,20 … 0,60
MAX_DELAY_BATCHES = 2
NOD_LOOKBACK_BATCHES = 5  # ventana del evento para la alternativa p(Cabeceo) máxima

NORMAL = features.LABELS.index("normal")
NOD = features.LABELS.index("cabeceo")
NOD_KIND = "cabeceo"
GLANCE_KIND = "mirar_hora"


def smoothed_probabilities(windows: pd.DataFrame, coef: np.ndarray, intercept: np.ndarray) -> np.ndarray:
    """Probabilidades suavizadas como StateClassifier (EMA 0,6, Normal = 1 al empezar)."""
    x = windows[list(features.FEATURE_NAMES)].to_numpy()
    raw = evaluate.softmax(x @ coef.T + intercept)
    out = np.empty_like(raw)
    previous_sequence = None
    p = None
    for i, sequence in enumerate(windows["secuencia"].to_numpy()):
        if sequence != previous_sequence:
            p = np.eye(len(features.LABELS))[NORMAL]
            previous_sequence = sequence
        p = evaluate.SMOOTHING * raw[i] + (1.0 - evaluate.SMOOTHING) * p
        out[i] = p
    return out


def nod_events(windows: pd.DataFrame, probs: np.ndarray) -> pd.DataFrame:
    """Un renglón por evento CABECEO del detector, con p(Normal) suavizada D lotes después
    (NaN si la secuencia termina antes), si Normal es la clase dominante entonces y la
    p(Cabeceo) máxima en la ventana del evento."""
    rows = []
    frame = windows.reset_index(drop=True)
    for sequence, group in frame.groupby("secuencia", sort=True):
        index = group.index.to_numpy()
        events = np.flatnonzero(group["evento_detector"].to_numpy() == features.EVENT_NOD)
        for e in events:
            row = {
                "secuencia": int(sequence),
                "usuario": int(group["usuario"].iloc[0]),
                "tipo": group["tipo"].iloc[0],
                "lote": int(group["lote"].iloc[e]),
                "pc_max": float(probs[index[max(0, e - NOD_LOOKBACK_BATCHES):e + 1], NOD].max()),
            }
            for d in DELAYS:
                j = e + d
                row[f"pn_{d}"] = float(probs[index[j], NORMAL]) if j < len(index) else float("nan")
                row[f"top_{d}"] = int(probs[index[j]].argmax()) if j < len(index) else -1
            rows.append(row)
    return pd.DataFrame(rows)


def confirmed_by_normal(events: pd.DataFrame, delay: int, threshold: float) -> np.ndarray:
    values = events[f"pn_{delay}"].to_numpy()
    return np.nan_to_num(values, nan=1.0) < threshold


def outcome(windows: pd.DataFrame, events: pd.DataFrame, keep: np.ndarray | None) -> dict:
    """Por tipo de secuencia: cuántas hay y cuántas tienen un cabeceo que abre la alerta
    (todos los eventos si keep es None; si no, solo los confirmados)."""
    per_type = windows.groupby("tipo")["secuencia"].nunique().to_dict()
    kept = events if keep is None else events[keep]
    alerted = kept.groupby("tipo")["secuencia"].nunique().to_dict()
    result = {kind: {"secuencias": int(n), "con_alerta_cabeceo": int(alerted.get(kind, 0))}
              for kind, n in sorted(per_type.items())}
    result["_eventos"] = int(len(kept))
    return result


def summary(result: dict) -> dict:
    nod = result[NOD_KIND]
    glance = result[GLANCE_KIND]
    others = sum(v["con_alerta_cabeceo"] for k, v in result.items()
                 if not k.startswith("_") and k not in (NOD_KIND, GLANCE_KIND))
    return {
        "recall_cabeceo": f"{nod['con_alerta_cabeceo']} de {nod['secuencias']}",
        "recall_cabeceo_tasa": nod["con_alerta_cabeceo"] / nod["secuencias"],
        "falsos_mirar_hora": f"{glance['con_alerta_cabeceo']} de {glance['secuencias']}",
        "falsos_mirar_hora_tasa": glance["con_alerta_cabeceo"] / glance["secuencias"],
        "falsos_otros": int(others),
    }


def choose(train_windows: pd.DataFrame, train_events: pd.DataFrame) -> dict:
    """Elige (D, θ) con los usuarios de entrenamiento (ver el docstring del módulo)."""
    is_nod = (train_events["tipo"] == NOD_KIND).to_numpy()
    is_glance = (train_events["tipo"] == GLANCE_KIND).to_numpy()
    candidates = []
    for d in DELAYS:
        if d > MAX_DELAY_BATCHES:
            continue
        theta = next((t for t in THRESHOLDS if confirmed_by_normal(train_events, d, t)[is_nod].all()), None)
        if theta is None:
            continue
        keep = confirmed_by_normal(train_events, d, theta)
        result = outcome(train_windows, train_events, keep)
        pn = np.nan_to_num(train_events[f"pn_{d}"].to_numpy(), nan=1.0)
        both = is_nod | is_glance
        auc = roc_auc_score(is_nod[both], -pn[both])
        candidates.append({"retardo_lotes": d, "umbral_normal": theta,
                           "falsos_mirar_hora": result[GLANCE_KIND]["con_alerta_cabeceo"], "auc": float(auc)})
    best = min(candidates, key=lambda c: (c["falsos_mirar_hora"], -c["auc"]))
    return {"elegido": best, "candidatos": candidates}


def grid(windows: pd.DataFrame, events: pd.DataFrame) -> list[dict]:
    rows = []
    for d in DELAYS:
        for t in THRESHOLDS:
            s = summary(outcome(windows, events, confirmed_by_normal(events, d, t)))
            rows.append({"retardo_lotes": d, "umbral_normal": t, **s})
    return rows


def alternative_nod_max(windows: pd.DataFrame, events: pd.DataFrame) -> list[dict]:
    """La alternativa descartada: p(Cabeceo) suavizada máxima ≥ θ en la ventana del evento."""
    return [{"umbral_cabeceo": t, **summary(outcome(windows, events, events["pc_max"].to_numpy() >= t))}
            for t in (0.3, 0.4, 0.5, 0.6, 0.7)]


def load_windows() -> pd.DataFrame:
    path = DATA_DIR / "windows.csv"
    if path.exists():
        return pd.read_csv(path)
    samples = pd.read_csv(DATA_DIR / "samples.csv")
    sequences = pd.read_csv(DATA_DIR / "sequences.csv")
    return features.dataset_windows(samples, sequences)


def by_sensitivity(test_users: set[int], coef: np.ndarray, intercept: np.ndarray, delay: int,
                   threshold: float) -> dict:
    """Regla sola y con confirmación en la prueba, con cada preajuste de sensibilidad."""
    samples = pd.read_csv(DATA_DIR / "samples.csv")
    sequences = pd.read_csv(DATA_DIR / "sequences.csv")
    samples = samples[samples["usuario"].isin(test_users)]
    sequences = sequences[sequences["usuario"].isin(test_users)]
    out = {}
    for preset in features.SENSITIVITY_PRESETS:
        windows = features.dataset_windows(samples, sequences, preset)
        probs = smoothed_probabilities(windows, coef, intercept)
        events = nod_events(windows, probs)
        out[preset] = {
            "regla": summary(outcome(windows, events, None)),
            "con_confirmacion": summary(outcome(windows, events, confirmed_by_normal(events, delay, threshold))),
        }
    return out


def _pct(value: float) -> str:
    return f"{100 * value:.1f} %".replace(".", ",")


def _num(value: float) -> str:
    return f"{value:.2f}".replace(".", ",")


def write_report(m: dict, path: Path) -> None:
    c = m["eleccion"]["elegido"]
    before, after = m["prueba"]["regla"], m["prueba"]["con_confirmacion"]
    tb, ta = m["entrenamiento"]["regla"], m["entrenamiento"]["con_confirmacion"]
    cand = "\n".join(f"| {k['retardo_lotes']} s | {_num(k['umbral_normal'])} | {k['falsos_mirar_hora']} | "
                     f"{k['auc']:.3f} |".replace(".", ",") for k in m["eleccion"]["candidatos"])
    grid_rows = "\n".join(
        f"| {r['retardo_lotes']} s | {_num(r['umbral_normal'])} | {r['recall_cabeceo']} | {r['falsos_mirar_hora']} | "
        f"{r['falsos_otros']} |" for r in m["rejilla_prueba"] if r["retardo_lotes"] == c["retardo_lotes"])
    alt_rows = "\n".join(f"| {_num(r['umbral_cabeceo'])} | {r['recall_cabeceo']} | {r['falsos_mirar_hora']} |"
                         for r in m["alternativa_p_cabeceo_prueba"])
    sens_rows = "\n".join(
        f"| {name.capitalize()} | {v['regla']['recall_cabeceo']} | {v['con_confirmacion']['recall_cabeceo']} | "
        f"{v['regla']['falsos_mirar_hora']} | {v['con_confirmacion']['falsos_mirar_hora']} | "
        f"{v['regla']['falsos_otros']} → {v['con_confirmacion']['falsos_otros']} |"
        for name, v in m["por_sensibilidad_prueba"].items())
    text = f"""# Confirmación del cabeceo por el modelo

> **Datos sintéticos** (`ml/generate_dataset.py`). Las cifras comparan la regla sola con
> la regla + confirmación en igualdad de condiciones; **no son precisión en muñecas reales**.

Generado por `ml/confirmation.py` con el modelo `{m['modelo']}` (semilla {m['semilla']}).

## Regla elegida

Un evento CABECEO del detector por reglas abre la alerta solo si, **{c['retardo_lotes']} lotes
({c['retardo_lotes']} s) después**, la probabilidad suavizada de **Normal** es menor que
**{_num(c['umbral_normal'])}**. La inactividad no pasa por el modelo.

Elegida con los usuarios de **entrenamiento** (retardo de 2 s como máximo; para cada
retardo, el menor umbral que confirma todos sus cabeceos; gana el que menos falsos deja en
*mirar la hora* y, si empatan, el de mayor AUC):

| Retardo | Umbral | Falsos en mirar la hora (entrenamiento) | AUC p(Normal), cabeceo frente a mirar la hora |
|---|---|---|---|
{cand}

## Resultado en la prueba (12 usuarios no vistos)

| | Regla sola | Regla + confirmación |
|---|---|---|
| Falsos cabeceos en *mirar la hora* | **{before['falsos_mirar_hora']}** ({_pct(before['falsos_mirar_hora_tasa'])}) | **{after['falsos_mirar_hora']}** ({_pct(after['falsos_mirar_hora_tasa'])}) |
| Recall de cabeceos reales (secuencias) | **{before['recall_cabeceo']}** ({_pct(before['recall_cabeceo_tasa'])}) | **{after['recall_cabeceo']}** ({_pct(after['recall_cabeceo_tasa'])}) |
| Falsos cabeceos en el resto (apoyar el brazo, mixtas, tecleo → normal, inactividad) | {before['falsos_otros']} | {after['falsos_otros']} |
| Retraso de la alerta de cabeceo | — | + {c['retardo_lotes']} s |

En entrenamiento (36 usuarios): mirar la hora {tb['falsos_mirar_hora']} → {ta['falsos_mirar_hora']},
cabeceos {tb['recall_cabeceo']} → {ta['recall_cabeceo']}.

El recall de cabeceos lo limita el detector por reglas (las caídas lentas no llegan a la
sacudida mínima): la confirmación no puede recuperar cabeceos que la regla no ve; solo
filtra los que ve.

### Rejilla de umbrales con el retardo elegido (prueba, solo informativa)

| Retardo | Umbral | Cabeceos | Mirar la hora | Otros falsos |
|---|---|---|---|---|
{grid_rows}

### Alternativa descartada: p(Cabeceo) máxima ≥ θ en la ventana del evento (prueba)

| Umbral | Cabeceos | Mirar la hora |
|---|---|---|
{alt_rows}

En el instante del evento la p(Cabeceo) de una mirada a la hora y la de un cabeceo son
casi iguales: cualquier umbral que quita falsos también quita cabeceos.

## Por sensibilidad del detector (prueba, con la regla elegida)

| Sensibilidad | Cabeceos, regla | Cabeceos, + confirmación | Mirar la hora, regla | Mirar la hora, + confirmación | Otros falsos |
|---|---|---|---|---|---|
{sens_rows}
"""
    path.write_text(text, encoding="utf-8")


def main() -> None:
    model = json.loads(MODEL_FILE.read_text(encoding="utf-8"))
    coef, intercept = np.array(model["coef"]), np.array(model["intercept"])
    test_users = set(model["dataset"]["usuarios_prueba"])

    windows = load_windows()
    probs = smoothed_probabilities(windows, coef, intercept)
    is_test = windows["usuario"].isin(test_users).to_numpy()
    sets = {}
    for name, mask in (("entrenamiento", ~is_test), ("prueba", is_test)):
        w = windows[mask].reset_index(drop=True)
        sets[name] = (w, nod_events(w, probs[mask]))

    choice = choose(*sets["entrenamiento"])
    d, theta = choice["elegido"]["retardo_lotes"], choice["elegido"]["umbral_normal"]
    metrics = {
        "aviso": "Datos SINTÉTICOS: no es precisión en el mundo real.",
        "modelo": model["version"],
        "semilla": model["semilla"],
        "regla": "confirmar si p(Normal) suavizada, retardo_lotes después del evento, < umbral_normal",
        "eleccion": choice,
    }
    for name, (w, e) in sets.items():
        metrics[name] = {
            "regla": summary(outcome(w, e, None)),
            "con_confirmacion": summary(outcome(w, e, confirmed_by_normal(e, d, theta))),
            "detalle_regla": outcome(w, e, None),
            "detalle_con_confirmacion": outcome(w, e, confirmed_by_normal(e, d, theta)),
        }
    metrics["rejilla_prueba"] = grid(*sets["prueba"])
    metrics["alternativa_p_cabeceo_prueba"] = alternative_nod_max(*sets["prueba"])
    metrics["por_sensibilidad_prueba"] = by_sensitivity(test_users, coef, intercept, d, theta)

    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    (REPORTS_DIR / "confirmation.json").write_text(json.dumps(metrics, indent=2, ensure_ascii=False) + "\n",
                                                   encoding="utf-8")
    write_report(metrics, REPORTS_DIR / "confirmation.md")
    b, a = metrics["prueba"]["regla"], metrics["prueba"]["con_confirmacion"]
    print(f"Confirmación: retardo {d} lotes, p(Normal) < {theta}. Prueba: mirar la hora "
          f"{b['falsos_mirar_hora']} -> {a['falsos_mirar_hora']}, cabeceos {b['recall_cabeceo']} -> "
          f"{a['recall_cabeceo']} (datos sintéticos)")


if __name__ == "__main__":
    main()
