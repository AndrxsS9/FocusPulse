"""Evaluación de los pesos v1 (a mano) y v2 (entrenados) sobre el MISMO conjunto de prueba.

Se evalúa lo que ve el reloj: por cada secuencia de prueba (una guardia), la softmax de
cada lote se suaviza con la misma EMA que StateClassifier (peso 0,6 para el lote nuevo,
empezando en Normal = 1) y la clase predicha es la de mayor probabilidad suavizada.
También se guardan las métricas sin suavizar.

Métricas: exactitud; precisión, recall y F1 por clase; matriz de confusión; **tasa de
falsos cabeceos en los negativos difíciles** (mirar la hora, apoyar el brazo), por
ventana y por episodio (secuencias con al menos una ventana tomada por Cabeceo).

Como referencia se miden también los eventos del **detector por reglas**
(DrowsinessDetector), que es quien abre la alerta en la app: no cambia entre v1 y v2.

Salidas en ml/reports/: metrics.json, report.md, confusion_v1.png, confusion_v2.png y
per_class_v1_v2.png. Los datos son SINTÉTICOS: las cifras no son precisión en el mundo real.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from sklearn.metrics import confusion_matrix, precision_recall_fscore_support  # noqa: E402
from sklearn.model_selection import GroupKFold, KFold, cross_val_score  # noqa: E402

import features  # noqa: E402

ML_DIR = Path(__file__).resolve().parent
ROOT = ML_DIR.parent
REPORTS_DIR = ML_DIR / "reports"
CORE_DIR = ROOT / "source" / "core"

SMOOTHING = 0.6  # StateClassifier.SMOOTHING
CLASS_NAMES = ("Activo", "Normal", "Cabeceo", "Inerte")
NOD = features.LABELS.index("cabeceo")
NORMAL = features.LABELS.index("normal")


# --- Pesos v1 -------------------------------------------------------------------------

def _mc_floats(text: str, name: str) -> np.ndarray:
    match = re.search(rf"const {name} = (\[.*?\]);", text, re.S)
    if not match:
        raise ValueError(f"no se encontró {name}")
    body = re.sub(r"//[^\n]*", "", match.group(1)).replace("f", "")
    return np.array(json.loads(body), dtype=float)


def load_v1() -> tuple[np.ndarray, np.ndarray]:
    """Pesos v1 (a mano) leídos del archivo Monkey C y plegados como los de v2."""
    path = CORE_DIR / "ClassifierWeightsV1.mc"
    if not path.exists():
        path = CORE_DIR / "ClassifierWeights.mc"  # antes de la integración de v2
    text = path.read_text(encoding="utf-8")
    if '"v1-manual"' not in text:
        raise ValueError(f"{path.name} no contiene los pesos v1")
    mean = _mc_floats(text, "FEATURE_MEAN")
    scale = _mc_floats(text, "FEATURE_SCALE")
    coef = _mc_floats(text, "COEF") / scale
    intercept = _mc_floats(text, "INTERCEPT") - coef @ mean
    return coef, intercept


# --- Predicción como en el reloj ------------------------------------------------------

def softmax(z: np.ndarray) -> np.ndarray:
    z = z - z.max(axis=1, keepdims=True)
    e = np.exp(z)
    return e / e.sum(axis=1, keepdims=True)


def predict(windows: pd.DataFrame, coef: np.ndarray, intercept: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Clase sin suavizar y clase suavizada (EMA por secuencia) de cada ventana."""
    x = windows[list(features.FEATURE_NAMES)].to_numpy()
    raw = softmax(x @ coef.T + intercept)
    smooth = np.empty_like(raw)
    previous_sequence = None
    p = None
    for i, sequence in enumerate(windows["secuencia"].to_numpy()):
        if sequence != previous_sequence:
            p = np.eye(len(CLASS_NAMES))[NORMAL]
            previous_sequence = sequence
        p = SMOOTHING * raw[i] + (1.0 - SMOOTHING) * p
        smooth[i] = p
    return raw.argmax(axis=1), smooth.argmax(axis=1)


def class_metrics(y: np.ndarray, pred: np.ndarray) -> dict:
    labels = list(range(len(CLASS_NAMES)))
    precision, recall, f1, support = precision_recall_fscore_support(y, pred, labels=labels, zero_division=0)
    return {
        "exactitud": float((y == pred).mean()),
        "f1_macro": float(f1.mean()),
        "por_clase": {
            name: {"precision": float(precision[k]), "recall": float(recall[k]), "f1": float(f1[k]),
                   "ventanas": int(support[k])}
            for k, name in enumerate(CLASS_NAMES)
        },
        "matriz_confusion": confusion_matrix(y, pred, labels=labels).tolist(),
    }


def false_nods(windows: pd.DataFrame, pred: np.ndarray) -> dict:
    """Ventanas y episodios de los negativos difíciles que el modelo toma por Cabeceo."""
    hard = windows["negativo_dificil"].to_numpy()
    frame = windows.loc[hard, ["secuencia", "tipo"]].assign(nod=pred[hard] == NOD)
    per_sequence = frame.groupby("secuencia").agg(tipo=("tipo", "first"), nod=("nod", "any"))
    result = {
        "ventanas": int(len(frame)),
        "ventanas_cabeceo": int(frame["nod"].sum()),
        "tasa_ventanas": float(frame["nod"].mean()),
        "episodios": int(len(per_sequence)),
        "episodios_con_cabeceo": int(per_sequence["nod"].sum()),
        "tasa_episodios": float(per_sequence["nod"].mean()),
        "por_tipo": {},
    }
    for kind, group in per_sequence.groupby("tipo"):
        windows_kind = frame[frame["tipo"] == kind]
        result["por_tipo"][kind] = {
            "tasa_ventanas": float(windows_kind["nod"].mean()),
            "episodios": int(len(group)),
            "episodios_con_cabeceo": int(group["nod"].sum()),
            "tasa_episodios": float(group["nod"].mean()),
        }
    return result


def typing_to_normal(windows: pd.DataFrame, pred: np.ndarray) -> dict:
    """Ventanas tomadas por Cabeceo al dejar de teclear y seguir con normalidad."""
    mask = (windows["tipo"] == "tecleo_normal").to_numpy()
    return {"ventanas": int(mask.sum()), "ventanas_cabeceo": int((pred[mask] == NOD).sum())}


def detector_events(windows: pd.DataFrame) -> dict:
    """Eventos del detector por reglas (igual con v1 y v2): quien abre la alerta."""
    per_sequence = windows.groupby("secuencia").agg(
        tipo=("tipo", "first"),
        nod=("evento_detector", lambda e: bool((e == features.EVENT_NOD).any())),
    )
    out = {}
    for kind, group in per_sequence.groupby("tipo"):
        out[kind] = {"secuencias": int(len(group)), "con_evento_cabeceo": int(group["nod"].sum()),
                     "tasa": float(group["nod"].mean())}
    return out


def leakage_check(pipeline, x: np.ndarray, y: np.ndarray, groups: np.ndarray, seed: int) -> dict:
    """Exactitud de validación cruzada con ventanas sueltas frente a grupos de usuarios."""
    loose = cross_val_score(pipeline, x, y, cv=KFold(5, shuffle=True, random_state=seed), scoring="accuracy")
    grouped = cross_val_score(pipeline, x, y, cv=GroupKFold(5), groups=groups, scoring="accuracy")
    return {"ventanas_sueltas": float(loose.mean()), "agrupada_por_usuario": float(grouped.mean())}


# --- Gráficas -------------------------------------------------------------------------

INK = "#0b0b0b"
INK_SECONDARY = "#52514e"
GRID = "#e1e0d9"
AXIS = "#c3c2b7"
SURFACE = "#fcfcfb"
SERIES = {"v1": "#2a78d6", "v2": "#eb6834"}  # paleta categórica de referencia, 1 y 2
BLUE_RAMP = ["#fcfcfb", "#cde2fb", "#9ec5f4", "#6da7ec", "#3987e5", "#256abf", "#184f95", "#0d366b"]


def _style(ax) -> None:
    ax.set_facecolor(SURFACE)
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        ax.spines[side].set_color(AXIS)
    ax.tick_params(colors=INK_SECONDARY, labelsize=9)


def plot_confusion(matrix: list[list[int]], title: str, path: Path) -> None:
    from matplotlib.colors import LinearSegmentedColormap

    m = np.array(matrix, dtype=float)
    share = m / np.maximum(m.sum(axis=1, keepdims=True), 1)
    cmap = LinearSegmentedColormap.from_list("azul", BLUE_RAMP)
    fig, ax = plt.subplots(figsize=(5.2, 4.4), dpi=150)
    fig.patch.set_facecolor(SURFACE)
    ax.imshow(share, cmap=cmap, vmin=0, vmax=1)
    for i in range(m.shape[0]):
        for j in range(m.shape[1]):
            color = "#ffffff" if share[i, j] > 0.55 else INK
            ax.text(j, i, f"{int(m[i, j])}\n{_pct(share[i, j])}", ha="center", va="center",
                    fontsize=8.5, color=color)
    ax.set_xticks(range(4), CLASS_NAMES)
    ax.set_yticks(range(4), CLASS_NAMES)
    ax.set_xlabel("Clase predicha", color=INK_SECONDARY, fontsize=9)
    ax.set_ylabel("Clase real", color=INK_SECONDARY, fontsize=9)
    ax.tick_params(colors=INK_SECONDARY, labelsize=9, length=0)
    for spine in ax.spines.values():
        spine.set_visible(False)
    ax.set_title(title, color=INK, fontsize=10.5, loc="left")
    fig.text(0.01, 0.01, "Datos sintéticos · porcentaje por fila (recall)", color=INK_SECONDARY, fontsize=7.5)
    fig.tight_layout()
    fig.savefig(path, facecolor=SURFACE)
    plt.close(fig)


def plot_per_class(v1: dict, v2: dict, path: Path) -> None:
    groups = list(CLASS_NAMES) + ["Falsos cabeceos\n(episodios)"]
    values = {
        "v1": [v1["smooth"]["por_clase"][c]["f1"] for c in CLASS_NAMES] + [v1["falsos_cabeceos"]["tasa_episodios"]],
        "v2": [v2["smooth"]["por_clase"][c]["f1"] for c in CLASS_NAMES] + [v2["falsos_cabeceos"]["tasa_episodios"]],
    }
    fig, ax = plt.subplots(figsize=(7.2, 3.8), dpi=150)
    fig.patch.set_facecolor(SURFACE)
    _style(ax)
    width = 0.36
    x = np.arange(len(groups))
    for offset, key, label in ((-0.5, "v1", "v1 · a mano"), (0.5, "v2", "v2 · entrenado")):
        bars = ax.bar(x + offset * (width + 0.02), values[key], width, color=SERIES[key], label=label,
                      edgecolor=SURFACE, linewidth=1)
        for bar, value in zip(bars, values[key]):
            ax.text(bar.get_x() + bar.get_width() / 2, value + 0.015, f"{value:.2f}".replace(".", ","), ha="center",
                    va="bottom", fontsize=7.5, color=INK_SECONDARY)
    ax.axvline(len(CLASS_NAMES) - 0.5, color=GRID, linewidth=1)
    ax.set_xticks(x, groups)
    ax.set_ylim(0, 1.1)
    ax.yaxis.grid(True, color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)
    ax.set_ylabel("F1 por clase · tasa", color=INK_SECONDARY, fontsize=9)
    ax.set_title("v1 frente a v2 en el mismo conjunto de prueba (más alto es mejor; "
                 "en falsos cabeceos, más bajo)", color=INK, fontsize=9.5, loc="left")
    ax.legend(frameon=False, fontsize=8.5, labelcolor=INK, loc="upper left", bbox_to_anchor=(0.0, -0.12), ncol=2)
    fig.text(0.01, 0.01, "Datos sintéticos · salida suavizada como en el reloj", color=INK_SECONDARY, fontsize=7.5)
    fig.tight_layout()
    fig.savefig(path, facecolor=SURFACE)
    plt.close(fig)


# --- Informe --------------------------------------------------------------------------

def _pct(value: float) -> str:
    return f"{100 * value:.1f} %".replace(".", ",")


def _matrix_md(matrix: list[list[int]]) -> str:
    lines = ["| Real \\ Predicha | " + " | ".join(CLASS_NAMES) + " | Recall |", "|---" * 6 + "|"]
    for k, row in enumerate(matrix):
        cells = [f"**{v}**" if j == k else str(v) for j, v in enumerate(row)]
        lines.append(f"| **{CLASS_NAMES[k]}** | " + " | ".join(cells) + f" | {_pct(row[k] / max(sum(row), 1))} |")
    return "\n".join(lines)


def write_report(metrics: dict, path: Path) -> None:
    v1, v2 = metrics["v1"], metrics["v2"]
    d = metrics["dataset"]
    rows = []
    for name in CLASS_NAMES:
        a, b = v1["smooth"]["por_clase"][name], v2["smooth"]["por_clase"][name]
        rows.append(f"| {name} | {a['precision']:.3f} / {a['recall']:.3f} / {a['f1']:.3f} | "
                    f"{b['precision']:.3f} / {b['recall']:.3f} / {b['f1']:.3f} | {b['ventanas']} |")
    hard_rows = []
    for kind in sorted(v2["falsos_cabeceos"]["por_tipo"]):
        a, b = v1["falsos_cabeceos"]["por_tipo"][kind], v2["falsos_cabeceos"]["por_tipo"][kind]
        hard_rows.append(f"| {kind} | {a['episodios_con_cabeceo']} de {a['episodios']} ({_pct(a['tasa_episodios'])}) | "
                         f"{b['episodios_con_cabeceo']} de {b['episodios']} ({_pct(b['tasa_episodios'])}) | "
                         f"{_pct(a['tasa_ventanas'])} → {_pct(b['tasa_ventanas'])} |")
    det = metrics["detector_por_reglas"]
    det_rows = [f"| {kind} | {v['con_evento_cabeceo']} de {v['secuencias']} ({_pct(v['tasa'])}) |"
                for kind, v in sorted(det.items())]
    leak = metrics["fuga_de_datos"]
    text = f"""# Informe de entrenamiento — clasificador de estado v2

> **Datos sintéticos.** Todo sale de `ml/generate_dataset.py`, que reproduce las firmas
> del simulador del reloj con variaciones por usuario. Estas cifras dicen si el
> pipeline funciona y comparan v1 con v2 en igualdad de condiciones; **no son precisión
> en muñecas reales**.

Generado por `ml/train.py` el {metrics['fecha']} (semilla {metrics['semilla']}).

## Dataset y división

- {d['usuarios']} usuarios sintéticos, {d['secuencias']} secuencias, {d['ventanas']} ventanas de 1 s.
- Prueba: {len(d['usuarios_prueba'])} usuarios completos ({d['ventanas_prueba']} ventanas), que no
  aparecen en el entrenamiento ({d['ventanas_entrenamiento']} ventanas).
- Validación cruzada: {metrics['validacion_cruzada']['esquema']}. Elegido: C = {metrics['hiperparametros']['C']:.4g},
  class_weight = {metrics['hiperparametros']['class_weight']} (criterio {metrics['validacion_cruzada']['criterio_elegido']:.3f}, log-loss
  {metrics['validacion_cruzada']['log_loss_elegido']:.3f}). El criterio pesa más la precisión de Cabeceo
  (F0,5) porque en la app un falso Cabeceo baja el puntaje y la alerta la abre el detector
  por reglas; C se elige por log-loss porque el puntaje usa las probabilidades.
- **Fuga de datos:** con la misma configuración, la exactitud de validación cruzada con
  ventanas sueltas es {_pct(leak['ventanas_sueltas'])} y agrupada por usuario {_pct(leak['agrupada_por_usuario'])}.

## Resultado (salida suavizada, como en el reloj)

| Métrica | v1 (a mano) | v2 (entrenado) |
|---|---|---|
| Exactitud | {_pct(v1['smooth']['exactitud'])} | {_pct(v2['smooth']['exactitud'])} |
| F1 macro | {v1['smooth']['f1_macro']:.3f} | {v2['smooth']['f1_macro']:.3f} |
| Falsos cabeceos, episodios de negativos difíciles | {v1['falsos_cabeceos']['episodios_con_cabeceo']} de {v1['falsos_cabeceos']['episodios']} ({_pct(v1['falsos_cabeceos']['tasa_episodios'])}) | {v2['falsos_cabeceos']['episodios_con_cabeceo']} de {v2['falsos_cabeceos']['episodios']} ({_pct(v2['falsos_cabeceos']['tasa_episodios'])}) |
| Falsos cabeceos, ventanas de negativos difíciles | {_pct(v1['falsos_cabeceos']['tasa_ventanas'])} | {_pct(v2['falsos_cabeceos']['tasa_ventanas'])} |
| Cabeceos al pasar de tecleo a normal (ventanas) | {v1['tecleo_a_normal']['ventanas_cabeceo']} de {v1['tecleo_a_normal']['ventanas']} | {v2['tecleo_a_normal']['ventanas_cabeceo']} de {v2['tecleo_a_normal']['ventanas']} |
| Exactitud sin suavizar | {_pct(v1['raw']['exactitud'])} | {_pct(v2['raw']['exactitud'])} |

Un *episodio* es una secuencia de negativo difícil (mirar la hora o apoyar el brazo);
cuenta como falso cabeceo si al menos una de sus ventanas sale Cabeceo.

### Por clase — precisión / recall / F1

| Clase | v1 | v2 | Ventanas |
|---|---|---|---|
{chr(10).join(rows)}

### Negativos difíciles por tipo

| Tipo | v1, episodios | v2, episodios | Ventanas v1 → v2 |
|---|---|---|---|
{chr(10).join(hard_rows)}

### Matriz de confusión v1

{_matrix_md(v1['smooth']['matriz_confusion'])}

![Matriz de confusión v1](confusion_v1.png)

### Matriz de confusión v2

{_matrix_md(v2['smooth']['matriz_confusion'])}

![Matriz de confusión v2](confusion_v2.png)

![v1 frente a v2](per_class_v1_v2.png)

## Detector por reglas (referencia)

Quien abre la alerta en la app es `DrowsinessDetector` (sacudida + quietud + inclinación),
no el clasificador; sus eventos son los mismos con v1 y con v2. Secuencias de prueba con
al menos un evento CABECEO:

| Tipo de secuencia | Con evento CABECEO |
|---|---|
{chr(10).join(det_rows)}
"""
    path.write_text(text, encoding="utf-8")


def evaluate(windows: pd.DataFrame, train: np.ndarray, test: np.ndarray, model: dict,
             pipeline, seed: int) -> dict:
    """Calcula todas las métricas, escribe ml/reports/ y devuelve el diccionario."""
    test_windows = windows.iloc[test].reset_index(drop=True)
    y = test_windows["clase"].to_numpy()
    weights = {"v1": load_v1(), "v2": (np.array(model["coef"]), np.array(model["intercept"]))}
    results = {}
    for name, (coef, intercept) in weights.items():
        raw, smooth = predict(test_windows, coef, intercept)
        results[name] = {
            "raw": class_metrics(y, raw),
            "smooth": class_metrics(y, smooth),
            "falsos_cabeceos": false_nods(test_windows, smooth),
            "falsos_cabeceos_sin_suavizar": false_nods(test_windows, raw),
            "tecleo_a_normal": typing_to_normal(test_windows, smooth),
        }
    names = list(features.FEATURE_NAMES)
    metrics = {
        "aviso": "Datos SINTÉTICOS: no es precisión en el mundo real.",
        "fecha": model["fecha"],
        "semilla": seed,
        "dataset": model["dataset"],
        "hiperparametros": model["hiperparametros"],
        "validacion_cruzada": {k: v for k, v in model["validacion_cruzada"].items() if k != "resultados"},
        "conjunto_prueba": "usuarios separados; salida suavizada con la EMA del reloj",
        "v1": results["v1"],
        "v2": results["v2"],
        "detector_por_reglas": detector_events(test_windows),
        "fuga_de_datos": leakage_check(pipeline, windows.iloc[train][names].to_numpy(),
                                       windows.iloc[train]["clase"].to_numpy(),
                                       windows.iloc[train]["usuario"].to_numpy(), seed),
    }
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    (REPORTS_DIR / "metrics.json").write_text(json.dumps(metrics, indent=2, ensure_ascii=False) + "\n",
                                              encoding="utf-8")
    plot_confusion(results["v1"]["smooth"]["matriz_confusion"], "v1 · pesos a mano", REPORTS_DIR / "confusion_v1.png")
    plot_confusion(results["v2"]["smooth"]["matriz_confusion"], "v2 · regresión logística entrenada",
                   REPORTS_DIR / "confusion_v2.png")
    plot_per_class(results["v1"], results["v2"], REPORTS_DIR / "per_class_v1_v2.png")
    write_report(metrics, REPORTS_DIR / "report.md")
    return metrics
