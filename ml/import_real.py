"""Esqueleto para importar datos REALES de acelerómetro (trabajo futuro).

**No forma parte del pipeline**: scripts\\train.ps1 no lo ejecuta y el modelo v2 se entrenó
solo con datos sintéticos. Sirve para el día en que haya grabaciones del reloj: las
convierte al mismo formato que generate_dataset.py (samples.csv y sequences.csv), así
features.py, train.py y evaluate.py funcionan sin cambios.

Formato de salida (ml/data/real/):

- samples.csv: t (ms desde el inicio de la secuencia), x, y, z (mg enteros, 25 Hz),
  etiqueta (activo, normal, cabeceo, inerte), usuario, secuencia.
- sequences.csv: secuencia, usuario, tipo, negativo_dificil, demo, muestras, guion.

Fuentes previstas:

1. **CSV** (implementado): una grabación por archivo con columnas t_ms, x, y, z en mg
   (p. ej. exportada desde la telemetría del reloj) y un CSV de etiquetas con
   inicio_ms, fin_ms, etiqueta. Las muestras sin etiqueta se descartan.
2. **FIT de SensorLogging** (por hacer): la app de captura grabaría el acelerómetro con
   Toybox.SensorLogging, que guarda mensajes accelerometer_data en el FIT de la actividad.
   Pasos previstos, comentados en load_fit():
     a) leer los mensajes con el FIT SDK de Garmin para Python (garmin-fit-sdk; no está
        en requirements.txt para no cargar el pipeline);
     b) usar calibrated_accel_x/y/z (en g) × 1000 → mg, o los conteos crudos con la
        calibración del mensaje three_d_sensor_calibration;
     c) reconstruir el tiempo de cada muestra con timestamp + sample_time_offset;
     d) remuestrear a 25 Hz (resample_25hz) si se grabó a otra frecuencia.

Etiquetado: las clases tienen que significar lo mismo que en el dataset sintético. En
particular, Cabeceo marca solo las muestras de la caída del brazo (unos 0,5 s), no el
rato de sueño después (eso es Inerte). Etiquetar con vídeo o con un pulsador del
observador; nunca con la salida del propio detector (sería circular).

Antes de entrenar con datos reales: repetir la prueba de equivalencia de
características y separar SIEMPRE por usuario (cada persona entera en entrenamiento o
en prueba), como train.py.

Uso:  python import_real.py --csv grabacion.csv --labels etiquetas.csv --user 101
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd

ML_DIR = Path(__file__).resolve().parent
REAL_DIR = ML_DIR / "data" / "real"
SAMPLE_RATE_HZ = 25
LABELS = ("activo", "normal", "cabeceo", "inerte")


def load_csv(path: Path) -> pd.DataFrame:
    """Grabación en CSV: columnas t_ms, x, y, z (mg). Devuelve t, x, y, z ordenados."""
    frame = pd.read_csv(path)
    missing = {"t_ms", "x", "y", "z"} - set(frame.columns)
    if missing:
        raise ValueError(f"{path}: faltan columnas {sorted(missing)}")
    frame = frame.rename(columns={"t_ms": "t"}).sort_values("t")
    return frame[["t", "x", "y", "z"]].reset_index(drop=True)


def load_fit(path: Path) -> pd.DataFrame:
    """Grabación FIT de SensorLogging (por hacer; ver los pasos en el docstring del módulo).

    Esquema previsto:

        from garmin_fit_sdk import Decoder, Stream
        messages, errors = Decoder(Stream.from_file(path)).read()
        for m in messages["accelerometer_data_mesgs"]:
            base = m["timestamp"] (s) y m["timestamp_ms"]
            for offset, ax, ay, az in zip(m["sample_time_offset"], m["calibrated_accel_x"], ...):
                t = base_ms + offset;  x = round(ax * 1000) …
    """
    raise NotImplementedError(
        "La lectura de FIT de SensorLogging está por hacer: ver ml/import_real.py y docs/IA.md.")


def resample_25hz(frame: pd.DataFrame) -> pd.DataFrame:
    """Remuestrea t, x, y, z a 25 Hz exactos (40 ms) con interpolación lineal."""
    t = frame["t"].to_numpy(dtype=float)
    grid = np.arange(t[0], t[-1] + 1, 1000 / SAMPLE_RATE_HZ)
    out = {"t": np.rint(grid - grid[0]).astype(int)}
    for axis in ("x", "y", "z"):
        out[axis] = np.rint(np.interp(grid, t, frame[axis].to_numpy(dtype=float))).astype(int)
    return pd.DataFrame(out)


def apply_labels(frame: pd.DataFrame, labels: pd.DataFrame) -> pd.DataFrame:
    """Pone la etiqueta de cada muestra según los tramos inicio_ms–fin_ms (fin excluido).
    Descarta las muestras fuera de todo tramo y valida los nombres de las clases."""
    unknown = set(labels["etiqueta"]) - set(LABELS)
    if unknown:
        raise ValueError(f"etiquetas desconocidas: {sorted(unknown)}; válidas: {LABELS}")
    frame = frame.copy()
    frame["etiqueta"] = None
    for row in labels.itertuples():
        inside = (frame["t"] >= row.inicio_ms) & (frame["t"] < row.fin_ms)
        frame.loc[inside, "etiqueta"] = row.etiqueta
    frame = frame.dropna(subset=["etiqueta"]).reset_index(drop=True)
    # El reloj ve muestras seguidas: un hueco en medio rompería la ventana de 2 s.
    if (np.diff(frame["t"].to_numpy()) != 1000 // SAMPLE_RATE_HZ).any():
        raise ValueError("hay tramos sin etiqueta en medio de la grabación: pártela en varias secuencias")
    frame["t"] -= frame["t"].iloc[0]
    return frame


def to_sequence(frame: pd.DataFrame, user: int, sequence: int, kind: str, demo: bool) -> tuple[pd.DataFrame, dict]:
    """Una grabación etiquetada → filas de samples.csv y su fila de sequences.csv."""
    samples = frame.assign(usuario=user, secuencia=sequence)[["t", "x", "y", "z", "etiqueta", "usuario", "secuencia"]]
    meta = {"secuencia": sequence, "usuario": user, "tipo": kind, "negativo_dificil": False,
            "demo": demo, "muestras": len(samples), "guion": "real"}
    return samples, meta


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--csv", type=Path, help="grabación CSV (t_ms, x, y, z en mg)")
    parser.add_argument("--fit", type=Path, help="grabación FIT de SensorLogging (por hacer)")
    parser.add_argument("--labels", type=Path, required=True, help="CSV inicio_ms, fin_ms, etiqueta")
    parser.add_argument("--user", type=int, required=True, help="id del usuario real (≥ 100)")
    parser.add_argument("--sequence", type=int, default=0)
    parser.add_argument("--kind", default="real")
    parser.add_argument("--demo", action="store_true", help="tiempos del modo demo en el detector")
    parser.add_argument("--out", type=Path, default=REAL_DIR)
    args = parser.parse_args()

    if args.fit:
        recording = load_fit(args.fit)
    elif args.csv:
        recording = load_csv(args.csv)
    else:
        parser.error("indica --csv o --fit")
    labelled = apply_labels(resample_25hz(recording), pd.read_csv(args.labels))
    samples, meta = to_sequence(labelled, args.user, args.sequence, args.kind, args.demo)

    args.out.mkdir(parents=True, exist_ok=True)
    samples_path, sequences_path = args.out / "samples.csv", args.out / "sequences.csv"
    samples.to_csv(samples_path, mode="a", header=not samples_path.exists(), index=False)
    pd.DataFrame([meta]).to_csv(sequences_path, mode="a", header=not sequences_path.exists(), index=False)
    print(f"Secuencia {args.sequence} del usuario {args.user}: {len(samples)} muestras → {args.out}")


if __name__ == "__main__":
    main()
