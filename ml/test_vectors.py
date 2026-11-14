"""Vectores de prueba para comprobar en el reloj que las características coinciden.

Genera dos secuencias fijas con generate_dataset.py, calcula con features.py las
características y el evento del detector de cada lote, y escribe todo en
tests/FeatureVectors.mc. La prueba Monkey C `featuresMatchPythonVectors`
(tests/FeatureMatchTest.mc) pasa las mismas muestras por TelemetryEngine →
DrowsinessDetector → StateClassifier.featuresInto y compara.

1. Usuario de referencia (las constantes del simulador), modo demo, sin girar:
   normal → tecleo → normal → cabeceo → despertar → mirar la hora → normal.
2. Usuario al azar con la muñeca girada, modo normal: tecleo → normal → mirar la hora
   → apoyar el brazo → inactividad.

Uso:  python test_vectors.py        (lo llama también export_weights.py)
"""

from __future__ import annotations

from pathlib import Path

import numpy as np

import features
import generate_dataset as gen

ROOT = Path(__file__).resolve().parent.parent
FEATURE_VECTORS_FILE = ROOT / "tests" / "FeatureVectors.mc"

VECTOR_SEED = 4242


def fixed_sequences() -> list[tuple[np.ndarray, bool]]:
    """Las dos secuencias de prueba: (muestras n × 3 en mg, modo demo)."""
    sequences = []

    rng = np.random.default_rng([VECTOR_SEED, 0])
    b = gen.SequenceBuilder(gen.reference_user(), rng)
    b.normal(b.seconds(4))
    b.typing(b.seconds(5))
    b.normal(b.seconds(3))
    b.nod(lead=b.seconds(3), hang=b.seconds(7))
    b.wake(b.seconds(1))
    b.normal(b.seconds(3))
    b.glance(hold=b.seconds(5))
    b.normal(b.seconds(3))
    xyz, _ = b.build(np.eye(3))
    sequences.append((xyz, True))

    rng = np.random.default_rng([VECTOR_SEED, 1])
    b = gen.SequenceBuilder(gen.random_user(1, rng), rng)
    b.typing(b.seconds(4))
    b.normal(b.seconds(1))
    b.glance(hold=b.seconds(4), target=gen.random_direction(rng))
    b.normal(b.seconds(3))
    b.rest_arm(lower=b.seconds(2), rest=b.seconds(4), lift=b.seconds(1), angle_deg=50.0,
               target=gen.random_direction(rng))
    b.inert(b.seconds(10))
    xyz, _ = b.build(gen.random_rotation(rng))
    sequences.append((xyz, False))

    # Solo lotes completos de 25 muestras.
    return [(xyz[: len(xyz) // features.BATCH_SAMPLES * features.BATCH_SAMPLES], demo)
            for xyz, demo in sequences]


def mc_float(value: float) -> str:
    """Literal Float de Monkey C en notación decimal (sin exponente)."""
    text = np.format_float_positional(np.float32(value), unique=True, trim="0")
    if text.endswith("."):
        text += "0"
    return text + "f"


def mc_array(values: list[str], indent: str = "        ", per_line: int = 16) -> str:
    lines = [", ".join(values[i:i + per_line]) for i in range(0, len(values), per_line)]
    return "[\n" + ",\n".join(indent + "    " + line for line in lines) + "\n" + indent + "]"


# El compilador de Monkey C (SDK 9.3.0) se queda sin pila (StackOverflowError) con un
# arreglo literal de más de unos cientos de elementos al compilar con -t -l 3. Los
# arreglos largos se parten en filas de ROW elementos; la prueba las recorre en orden.
ROW = 100


def mc_rows(values: list[str], indent: str = "    ", per_line: int = 20) -> str:
    rows = [mc_array(values[i:i + ROW], indent + "    ", per_line) for i in range(0, len(values), ROW)]
    return "[\n" + ",\n".join(indent + "    " + row for row in rows) + "\n" + indent + "]"


def write_feature_vectors(path: Path = FEATURE_VECTORS_FILE) -> None:
    sequences = fixed_sequences()
    starts = [0]
    xs, ys, zs, feats, events = [], [], [], [], []
    for xyz, demo in sequences:
        for r in features.sequence_features(xyz, demo):
            events.append(str(r.event))
            if r.features is not None:
                feats.extend(mc_float(v) for v in r.features)
        xs.extend(str(v) for v in xyz[:, 0])
        ys.extend(str(v) for v in xyz[:, 1])
        zs.extend(str(v) for v in xyz[:, 2])
        starts.append(starts[-1] + len(xyz))

    demo_flags = ", ".join("true" if demo else "false" for _, demo in sequences)
    text = f"""import Toybox.Lang;

//! GENERADO por ml/test_vectors.py, no editar a mano.
//!
//! Muestras fijas (mg, 25 Hz) y lo que calcula ml/features.py para ellas: un evento del
//! detector por lote y las 5 características de StateClassifier por cada lote con la
//! ventana llena. featuresMatchPythonVectors (FeatureMatchTest.mc) comprueba que el
//! reloj calcula lo mismo. Datos SINTÉTICOS (ml/generate_dataset.py).
(:test)
class FeatureVectors {{

    //! Modo demo de cada secuencia.
    static const DEMO = [{demo_flags}];

    //! Los arreglos van en filas de {ROW} elementos (el compilador no admite literales
    //! mucho más largos); FeatureMatchTest los aplana.

    //! Primera muestra de cada secuencia en X/Y/Z; el último valor es el total.
    static const STARTS = [{", ".join(str(s) for s in starts)}];

    static const X = {mc_rows(xs)};

    static const Y = {mc_rows(ys)};

    static const Z = {mc_rows(zs)};

    //! DrowsinessEvent de cada lote de 1 s (0 nada, 1 cabeceo, 2 inactividad).
    static const EVENTS = {mc_rows(events, per_line=25)};

    //! 5 características por lote con la ventana llena, en el orden de
    //! StateClassifier.FEATURE_*.
    static const FEATURES = {mc_rows(feats, per_line=5)};
}}
"""
    path.write_text(text, encoding="utf-8", newline="\n")
    print(f"Vectores de características: {len(sequences)} secuencias, {starts[-1]} muestras, "
          f"{len(feats) // features.FEATURE_COUNT} ventanas → {path.relative_to(ROOT)}")


if __name__ == "__main__":
    write_feature_vectors()
