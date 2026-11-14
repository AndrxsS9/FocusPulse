"""Características del clasificador, idénticas a las que calcula el reloj.

Es una traducción línea a línea de la cadena de `source/core` que alimenta a
`StateClassifier`, en el mismo orden que `GuardController.onBatch`:

    lote de 25 muestras (1 s) → TelemetryEngine.addBatch → SlidingWindow (2 s, 50 muestras)
    → TelemetrySnapshot → DrowsinessDetector.update (+ Baseline) → StateClassifier.featuresInto

Las 5 características, en el orden de StateClassifier.FEATURE_* y con sus unidades:

| # | Característica | Unidad |
|---|---|---|
| 0 | ln(varianza + 1) de la magnitud en la ventana de 2 s | ln(mg²) |
| 1 | Sacudida máxima del lote: mayor \\|Δ\\| vectorial entre muestras seguidas | mg |
| 2 | Segundos de quietud del detector, con tope de 30 | s |
| 3 | Cambio de inclinación (ángulo entre gravedades), con tope de 90 | grados |
| 4 | Caída pendiente del detector (0 o 1) | — |

Detalles que se copian a propósito para que coincidan bit a bit (o casi):

- La magnitud se redondea a mg enteros y la varianza sale de sumas enteras exactas,
  como `RingBuffer` y `SlidingWindow` (Long en Monkey C, int en Python).
- `Float` de Monkey C es de 32 bits: la línea base, la varianza, la gravedad media y la
  inclinación se calculan con numpy.float32 donde el reloj usa Float.
- El tiempo de cada lote es k × 1000 ms (k = 1, 2, …), como `tests/DetectorRig.mc`.

La prueba `tests/FeatureMatchTest.mc` comprueba en el reloj que estas características
coinciden con las de Monkey C para unas secuencias fijas (`tests/FeatureVectors.mc`,
generado por `export_test_vectors`).
"""

from __future__ import annotations

import math
from collections import deque
from dataclasses import dataclass

import numpy as np

f32 = np.float32

# --- Constantes (source/core) ---------------------------------------------------------

SAMPLE_RATE_HZ = 25  # SlidingWindow.SAMPLE_RATE_HZ
BATCH_SAMPLES = 25  # 1 s por lote
WINDOW_SECONDS = 2
WINDOW_SAMPLES = SAMPLE_RATE_HZ * WINDOW_SECONDS
JERK_SAMPLES = 10
STILL_VARIANCE_MAX = f32(100.0)

NOD_JERK_MIN = 400  # DrowsinessDetector
NOD_CALM_JERK = 50
NOD_STILL_WITHIN_MS = 5000
NOD_TILT_MIN = f32(35.0)
INACTIVITY_MS = 60000
INACTIVITY_DEMO_MS = 8000
REFRACTORY_MS = 10000
STILL_CREDIT_MS = WINDOW_SECONDS * 1000

CALIBRATION_MS = 30000  # Baseline
CALIBRATION_DEMO_MS = 5000
DEFAULT_MEAN = f32(6.55)
DEFAULT_STD = f32(0.5)
MIN_STD = f32(0.05)
EMA_ALPHA = f32(0.01)
STILL_FRACTION = f32(0.25)
STILL_FLOOR = f32(25.0)

TILT_MIN_NORM = f32(100.0)  # Tilt.MIN_NORM

STILL_CAP_S = f32(30.0)  # StateClassifier
TILT_CAP_DEG = f32(90.0)

FEATURE_NAMES = ("ln_varianza", "sacudida_lote", "quietud_s", "inclinacion_deg", "caida_pendiente")
FEATURE_COUNT = len(FEATURE_NAMES)

EVENT_NONE, EVENT_NOD, EVENT_INACTIVITY = 0, 1, 2

# Umbrales por sensibilidad (DetectorThresholds.mc, fase 11): sacudida (mg), inclinación
# (grados), inactividad y su versión demo (ms). "media" son las constantes de arriba.
SENSITIVITY_PRESETS = {
    "baja": (440, f32(45.0), 90000, 12000),
    "media": (NOD_JERK_MIN, NOD_TILT_MIN, INACTIVITY_MS, INACTIVITY_DEMO_MS),
    "alta": (340, f32(28.0), 45000, 6000),
}


def magnitude_of(x: int, y: int, z: int) -> int:
    """RingBuffer.magnitudeOf: módulo redondeado al mg entero."""
    return int(math.sqrt(float(x * x + y * y + z * z)) + 0.5)


# --- SlidingWindow + TelemetryEngine --------------------------------------------------

class Window:
    """SlidingWindow con la sacudida del lote de TelemetryEngine."""

    def __init__(self) -> None:
        self.samples: deque[tuple[int, int, int, int]] = deque(maxlen=WINDOW_SAMPLES)
        self.sum = 0
        self.sum_sq = 0
        self.sx = self.sy = self.sz = 0
        self.deltas: deque[int] = deque(maxlen=JERK_SAMPLES - 1)
        self.last_delta = 0

    def push(self, x: int, y: int, z: int) -> None:
        m = magnitude_of(x, y, z)
        if self.samples:
            lx, ly, lz, _ = self.samples[-1]
            self.last_delta = magnitude_of(x - lx, y - ly, z - lz)
            self.deltas.append(self.last_delta)
        if len(self.samples) == WINDOW_SAMPLES:
            ox, oy, oz, om = self.samples[0]
            self.sum -= om
            self.sum_sq -= om * om
            self.sx -= ox
            self.sy -= oy
            self.sz -= oz
        self.samples.append((x, y, z, m))
        self.sx += x
        self.sy += y
        self.sz += z
        self.sum += m
        self.sum_sq += m * m

    def full(self) -> bool:
        return len(self.samples) == WINDOW_SAMPLES

    def variance(self) -> np.float32:
        n = len(self.samples)
        if n < 2:
            return f32(0.0)
        return f32((n * self.sum_sq - self.sum * self.sum) / float(n * n))

    def gravity(self) -> tuple[np.float32, np.float32, np.float32]:
        n = len(self.samples)
        if n == 0:
            return f32(0), f32(0), f32(0)
        return f32(self.sx) / f32(n), f32(self.sy) / f32(n), f32(self.sz) / f32(n)

    def jerk(self) -> int:
        return max(self.deltas, default=0)


@dataclass
class Snapshot:
    """Los campos de TelemetrySnapshot que usan el detector y el clasificador."""

    window_full: bool
    variance: np.float32
    gravity: tuple[np.float32, np.float32, np.float32]
    jerk: int
    batch_peak_jerk: int


def add_batch(window: Window, xs, ys, zs) -> Snapshot:
    """TelemetryEngine.addBatch + snapshot()."""
    peak = 0
    for x, y, z in zip(xs, ys, zs):
        had = len(window.samples) > 0
        window.push(int(x), int(y), int(z))
        if had and window.last_delta > peak:
            peak = window.last_delta
    return Snapshot(window.full(), window.variance(), window.gravity(), window.jerk(), peak)


# --- Tilt -----------------------------------------------------------------------------

def angle_degrees(a, b) -> np.float32:
    """Tilt.angleDegrees en float32."""
    ax, ay, az = (f32(v) for v in a)
    bx, by, bz = (f32(v) for v in b)
    norm_a = f32(math.sqrt(ax * ax + ay * ay + az * az))
    norm_b = f32(math.sqrt(bx * bx + by * by + bz * bz))
    if norm_a < TILT_MIN_NORM or norm_b < TILT_MIN_NORM:
        return f32(0.0)
    cos = (ax * bx + ay * by + az * bz) / (norm_a * norm_b)
    cos = min(max(cos, f32(-1.0)), f32(1.0))
    return f32(math.degrees(math.acos(cos)))


# --- Baseline -------------------------------------------------------------------------

def log_variance(variance) -> np.float32:
    """Baseline.logVariance: ln(varianza + 1)."""
    return f32(math.log(f32(variance) + f32(1.0)))


class Baseline:

    def __init__(self) -> None:
        self.reset()

    def reset(self) -> None:
        self.calibrating = False
        self.ready = False
        self.start_ms = 0
        self.duration_ms = CALIBRATION_MS
        self.count = 0
        self.sum = f32(0.0)
        self.sum_sq = f32(0.0)
        self.mean = DEFAULT_MEAN
        self.var = DEFAULT_STD * DEFAULT_STD

    def start(self, now_ms: int, duration_ms: int) -> None:
        self.reset()
        self.calibrating = True
        self.start_ms = now_ms
        self.duration_ms = duration_ms

    def observe(self, variance, time_ms: int) -> None:
        if self.calibrating:
            if variance is not None:
                x = log_variance(variance)
                self.count += 1
                self.sum += x
                self.sum_sq += x * x
            if time_ms - self.start_ms >= self.duration_ms:
                self._finish()
            return
        if self.ready and variance is not None:
            x = log_variance(variance)
            d = x - self.mean
            self.mean += EMA_ALPHA * d
            self.var = (f32(1.0) - EMA_ALPHA) * (self.var + EMA_ALPHA * d * d)

    def _finish(self) -> None:
        self.calibrating = False
        self.ready = True
        if self.count == 0:
            return
        self.mean = self.sum / f32(self.count)
        if self.count >= 2:
            v = self.sum_sq / f32(self.count) - self.mean * self.mean
            self.var = v if v > f32(0.0) else f32(0.0)
        if self.var < MIN_STD * MIN_STD:
            self.var = MIN_STD * MIN_STD

    def still_threshold(self) -> np.float32:
        if not self.ready:
            return STILL_VARIANCE_MAX
        typical = f32(math.pow(math.e, self.mean) - f32(1.0))
        threshold = STILL_FRACTION * typical
        if threshold > STILL_VARIANCE_MAX:
            return STILL_VARIANCE_MAX
        return STILL_FLOOR if threshold < STILL_FLOOR else threshold


# --- DrowsinessDetector ---------------------------------------------------------------

class Detector:

    def __init__(self, demo: bool, sensitivity: str = "media") -> None:
        self.baseline = Baseline()
        self.demo = demo
        (self.jerk_min, self.tilt_min, self.inactivity_normal_ms,
         self.inactivity_demo_ms) = SENSITIVITY_PRESETS[sensitivity]
        self.has_previous = False
        self.prev = (f32(0), f32(0), f32(0))
        self.fall_ms: int | None = None
        self.fall = (f32(0), f32(0), f32(0))
        self.fall_calm = False
        self.still_since_ms: int | None = None
        self.last_time_ms = 0
        self.tilt = f32(0.0)
        self.refractory_until_ms: int | None = None
        # start(0, demo)
        self.baseline.start(0, CALIBRATION_DEMO_MS if demo else CALIBRATION_MS)

    def inactivity_ms(self) -> int:
        return self.inactivity_demo_ms if self.demo else self.inactivity_normal_ms

    def can_emit(self, time_ms: int) -> bool:
        return self.refractory_until_ms is None or time_ms >= self.refractory_until_ms

    def update(self, s: Snapshot, time_ms: int) -> int:
        self.last_time_ms = time_ms
        if not s.window_full:
            self.baseline.observe(None, time_ms)
            return EVENT_NONE
        g = s.gravity

        if s.batch_peak_jerk >= self.jerk_min:
            self.fall_ms = time_ms
            self.fall = self.prev if self.has_previous else g
        if self.fall_ms is not None and time_ms - self.fall_ms > NOD_STILL_WITHIN_MS:
            self.fall_ms = None

        still = bool(s.variance < self.baseline.still_threshold())
        if not still:
            self.still_since_ms = None
        elif self.still_since_ms is None:
            self.still_since_ms = time_ms - STILL_CREDIT_MS

        pending = self.fall_ms is not None
        if pending:
            self.tilt = angle_degrees(self.fall, g)
        elif self.has_previous:
            self.tilt = angle_degrees(self.prev, g)
        else:
            self.tilt = f32(0.0)
        self.prev = g
        self.has_previous = True

        event = self._decide(time_ms, still, pending)
        if event != EVENT_NONE:
            self.refractory_until_ms = time_ms + REFRACTORY_MS
            self.fall_ms = None
            if still:
                self.still_since_ms = time_ms
        self.fall_calm = self.fall_ms is not None and s.jerk < NOD_CALM_JERK

        ordinary = event == EVENT_NONE and not still and not self.fall_calm and self.can_emit(time_ms)
        self.baseline.observe(s.variance if ordinary else None, time_ms)
        return event

    def _decide(self, time_ms: int, still: bool, pending: bool) -> int:
        blocked = not self.can_emit(time_ms)
        if pending and still:
            if self.tilt < self.tilt_min:
                self.fall_ms = None
            elif not blocked:
                return EVENT_NOD
        since = self.still_since_ms
        if not blocked and since is not None and time_ms - since >= self.inactivity_ms():
            return EVENT_INACTIVITY
        return EVENT_NONE

    def still_seconds(self) -> np.float32:
        if self.still_since_ms is None:
            return f32(0.0)
        return f32((self.last_time_ms - self.still_since_ms) / 1000.0)


# --- StateClassifier.featuresInto -----------------------------------------------------

def feature_vector(s: Snapshot, d: Detector) -> list[float]:
    variance = s.variance if s.variance >= f32(0.0) else f32(0.0)
    still = d.still_seconds()
    tilt = d.tilt
    return [
        float(log_variance(variance)),
        float(s.batch_peak_jerk),
        float(STILL_CAP_S if still > STILL_CAP_S else still),
        float(TILT_CAP_DEG if tilt > TILT_CAP_DEG else tilt),
        1.0 if d.fall_calm else 0.0,
    ]


@dataclass
class BatchResult:
    """Un lote de 1 s ya procesado."""

    batch: int  # 1, 2, … (el lote k termina en k × 1000 ms)
    time_ms: int
    window_full: bool
    features: list[float] | None  # None mientras la ventana no está llena
    event: int


def sequence_features(xyz: np.ndarray, demo: bool, sensitivity: str = "media") -> list[BatchResult]:
    """Pasa una secuencia completa (n × 3 enteros en mg, una guardia que empieza en
    t = 0) por la cadena del reloj y devuelve un resultado por lote completo de 25
    muestras. Las muestras sobrantes del final se ignoran. sensitivity: preajuste del
    detector (SENSITIVITY_PRESETS)."""
    window = Window()
    detector = Detector(demo, sensitivity)
    results = []
    for k in range(len(xyz) // BATCH_SAMPLES):
        chunk = xyz[k * BATCH_SAMPLES:(k + 1) * BATCH_SAMPLES]
        time_ms = (k + 1) * 1000
        snapshot = add_batch(window, chunk[:, 0], chunk[:, 1], chunk[:, 2])
        event = detector.update(snapshot, time_ms)
        features = feature_vector(snapshot, detector) if snapshot.window_full else None
        results.append(BatchResult(k + 1, time_ms, snapshot.window_full, features, event))
    return results


# --- Dataset → ventanas ---------------------------------------------------------------

LABELS = ("activo", "normal", "cabeceo", "inerte")  # orden de DrowsinessClass


def window_label(labels: np.ndarray, end: int) -> int:
    """Etiqueta de la ventana de 2 s que termina en la muestra end (excluida).

    Cabeceo si la ventana contiene alguna muestra de la caída (el clasificador la está
    viendo); si no, la etiqueta de la última muestra, es decir, el estado en curso. Es
    la misma regla que `trueClass` en tests/StateClassifierTest.mc."""
    window = labels[max(0, end - WINDOW_SAMPLES):end]
    nod = LABELS.index("cabeceo")
    return nod if (window == nod).any() else int(window[-1])


def dataset_windows(samples, sequences, sensitivity: str = "media"):
    """Una fila por lote con la ventana llena: características, etiqueta y grupos.

    samples y sequences son los DataFrames de generate_dataset.py (o de
    import_real.py, con las mismas columnas). El modelo se entrena con la sensibilidad
    media; las otras solo se usan para evaluar (confirmation.py)."""
    import pandas as pd

    label_index = {name: i for i, name in enumerate(LABELS)}
    meta = sequences.set_index("secuencia")
    rows = []
    for sequence, group in samples.groupby("secuencia", sort=True):
        info = meta.loc[sequence]
        xyz = group[["x", "y", "z"]].to_numpy()
        labels = group["etiqueta"].map(label_index).to_numpy()
        for r in sequence_features(xyz, bool(info["demo"]), sensitivity):
            if r.features is None:
                continue
            rows.append([sequence, int(info["usuario"]), info["tipo"], bool(info["negativo_dificil"]),
                         r.batch, r.time_ms, r.event, window_label(labels, r.batch * BATCH_SAMPLES),
                         *r.features])
    columns = ["secuencia", "usuario", "tipo", "negativo_dificil", "lote", "t_ms", "evento_detector",
               "clase", *FEATURE_NAMES]
    return pd.DataFrame(rows, columns=columns)
