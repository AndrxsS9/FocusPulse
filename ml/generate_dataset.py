"""Generador del dataset SINTÉTICO de FocusPulse AI.

**Los datos no son reales.** Salen de las mismas firmas de movimiento que la fuente
simulada del reloj (`source/platform/SimulatedAccelSource.mc`): 25 Hz, mili-g enteros y
gravedad de unos 1000 mg. Sirven para entrenar y comparar el clasificador con un
pipeline reproducible, no para medir su precisión en muñecas reales.

Lo que añade sobre el simulador:

- **Usuarios sintéticos**: cada uno con su amplitud de movimiento, ruido del brazo
  inerte, fuerza y ritmo del tecleo y forma del cabeceo (ángulo y duración de la caída).
  El usuario 0 es el de referencia: usa exactamente las constantes del simulador.
- **Orientación aleatoria de la muñeca**: cada secuencia gira todas sus muestras con una
  rotación al azar (la gravedad apunta a otro lado). Las características del reloj no
  dependen de la orientación, así que esto prueba justamente eso.
- **Negativos difíciles**, etiquetados como Normal: (a) mirar la hora y quedarse
  leyendo (giro rápido y luego quietud con la muñeca inclinada) y (b) apoyar el brazo
  despacio sobre la mesa. Son los dos casos que más se parecen a un cabeceo.
- **Transiciones** entre estados dentro de una misma secuencia (una guardia): normal →
  tecleo → normal → inactividad, cabeceo y despertar, etc.

Salida en ml/data/:

- samples.csv: t, x, y, z, etiqueta, usuario, secuencia (una fila por muestra).
- sequences.csv: una fila por secuencia (tipo, modo demo, guion de segmentos).

Uso:  python generate_dataset.py --seed 20261114
"""

from __future__ import annotations

import argparse
import math
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd

# --- Constantes del reloj (SimulatedAccelSource / SlidingWindow) ----------------------

SAMPLE_RATE_HZ = 25
SAMPLE_MS = 1000 // SAMPLE_RATE_HZ  # 40 ms

NORMAL_POSTURE = (40, -180, 975)
NORMAL_NOISE = 70  # triangular: suma de dos uniformes de ±35

TYPING_Z = 960
TYPING_NOISE_XY = 250
TYPING_NOISE_Z = 220

INERT_POSTURE = (22, -18, 996)
INERT_NOISE = 4

NOD_FROM = (0, 0, 980)
NOD_TO = (-240, -940, 240)
NOD_LEAD_SAMPLES = 75
NOD_PROFILE = (10, 25, 45, 80, 300, 680, 950, 1000, 1040, 1010, 985, 1000)

# Negativos difíciles (se etiquetan Normal). El usuario de referencia los hace con estos
# valores, los mismos que el escenario "mirar la hora" (GLANCE) de SimulatedAccelSource.
GLANCE_TARGET = (0, 1000, 0)  # hacia dónde gira la gravedad al levantar la esfera
GLANCE_ANGLE_DEG = 80.0
GLANCE_RAISE_SAMPLES = 8  # giro rápido: 0,32 s
GLANCE_LIFT_MG = 300  # aceleración de subir el brazo (módulo + / − durante el giro)
GLANCE_HOLD_NOISE = 16  # temblor del brazo sostenido mientras se lee (triangular)
GLANCE_LOWER_SAMPLES = 15

# Etiquetas (mismo orden que DrowsinessClass en Monkey C).
LABELS = ("activo", "normal", "cabeceo", "inerte")

DATA_DIR = Path(__file__).resolve().parent / "data"


# --- Usuarios sintéticos --------------------------------------------------------------

@dataclass(frozen=True)
class UserProfile:
    """Parámetros de movimiento de un usuario sintético (mg, muestras, grados)."""

    user: int
    normal_noise: int
    typing_xy: int
    typing_z: int
    typing_rhythm_hz: float  # 0: tecleo sin ritmo marcado (como el simulador)
    typing_rhythm_depth: float  # 0–1: cuánto modula el ritmo la amplitud
    inert_noise: int
    nod_angle_deg: float
    nod_samples: int
    glance_angle_deg: float
    glance_samples: int
    glance_lift: int
    hold_noise: int
    rest_noise: int


def nod_reference_angle() -> float:
    """Ángulo (°) entre la postura despierta y la del brazo colgando del simulador."""
    a = np.array(NOD_FROM, float)
    b = np.array(NOD_TO, float)
    return math.degrees(math.acos(a @ b / (np.linalg.norm(a) * np.linalg.norm(b))))


def reference_user() -> UserProfile:
    """Usuario 0: exactamente las firmas de SimulatedAccelSource."""
    return UserProfile(
        user=0,
        normal_noise=NORMAL_NOISE,
        typing_xy=TYPING_NOISE_XY,
        typing_z=TYPING_NOISE_Z,
        typing_rhythm_hz=0.0,
        typing_rhythm_depth=0.0,
        inert_noise=INERT_NOISE,
        nod_angle_deg=nod_reference_angle(),
        nod_samples=len(NOD_PROFILE),
        glance_angle_deg=GLANCE_ANGLE_DEG,
        glance_samples=GLANCE_RAISE_SAMPLES,
        glance_lift=GLANCE_LIFT_MG,
        hold_noise=GLANCE_HOLD_NOISE,
        rest_noise=12,
    )


def random_user(user: int, rng: np.random.Generator) -> UserProfile:
    """Usuario con parámetros al azar alrededor de los del simulador."""
    return UserProfile(
        user=user,
        normal_noise=int(rng.integers(45, 101)),
        typing_xy=int(rng.integers(170, 321)),
        typing_z=int(rng.integers(150, 281)),
        typing_rhythm_hz=float(rng.uniform(2.5, 6.0)),
        typing_rhythm_depth=float(rng.uniform(0.0, 0.35)),
        inert_noise=int(rng.integers(2, 7)),
        nod_angle_deg=float(rng.uniform(50.0, 100.0)),
        nod_samples=int(rng.integers(8, 17)),
        glance_angle_deg=float(rng.uniform(60.0, 110.0)),
        glance_samples=int(rng.integers(6, 15)),
        glance_lift=int(rng.integers(100, 451)),
        hold_noise=int(rng.integers(6, 31)),
        rest_noise=int(rng.integers(8, 21)),
    )


# --- Utilidades de señal --------------------------------------------------------------

def uniform_noise(rng: np.random.Generator, amplitude: int | np.ndarray, size) -> np.ndarray:
    """Ruido entero uniforme en [-amplitude, amplitude] (como SimulatedAccelSource.noise)."""
    amplitude = np.asarray(amplitude)
    return np.floor(rng.random(size) * (2 * amplitude + 1)).astype(int) - amplitude


def soft_noise(rng: np.random.Generator, amplitude: int, size) -> np.ndarray:
    """Ruido triangular: suma de dos uniformes de la mitad (SimulatedAccelSource.softNoise)."""
    half = amplitude // 2
    return uniform_noise(rng, half, size) + uniform_noise(rng, amplitude - half, size)


def random_rotation(rng: np.random.Generator) -> np.ndarray:
    """Matriz de rotación 3×3 uniforme (cuaternión unitario al azar)."""
    q = rng.normal(size=4)
    w, x, y, z = q / np.linalg.norm(q)
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ])


def rotate_towards(v: np.ndarray, target: np.ndarray, angle_deg: float) -> np.ndarray:
    """Gira v hacia la dirección de target angle_deg grados, conservando su módulo."""
    norm = np.linalg.norm(v)
    u = v / norm
    t = target - (target @ u) * u
    t = t / np.linalg.norm(t)
    a = math.radians(angle_deg)
    return norm * (math.cos(a) * u + math.sin(a) * t)


def smoothstep(k: np.ndarray) -> np.ndarray:
    return k * k * (3.0 - 2.0 * k)


def turn_path(start: np.ndarray, target: np.ndarray, angle_deg: float, n: int,
              lift: float) -> np.ndarray:
    """Giro controlado de la muñeca en n muestras: la gravedad gira angle_deg hacia
    target (con módulo constante, no como la caída del cabeceo) y se suma la aceleración
    de mover el brazo: el módulo sube lift mg y luego baja otro tanto al frenar."""
    k = smoothstep(np.arange(1, n + 1) / n)
    path = np.array([rotate_towards(start, target, angle_deg * ki) for ki in k])
    unit = path / np.linalg.norm(path, axis=1, keepdims=True)
    push = lift * np.sin(2 * math.pi * (np.arange(n) + 0.5) / n)
    return path + unit * push[:, None]


def resample_profile(profile: tuple[int, ...], samples: int) -> np.ndarray:
    """Estira o encoge el perfil de la caída a samples muestras (milésimas)."""
    if samples == len(profile):
        return np.array(profile, float)
    src = np.linspace(0.0, 1.0, len(profile))
    dst = np.linspace(0.0, 1.0, samples)
    return np.interp(dst, src, np.array(profile, float))


# --- Segmentos ------------------------------------------------------------------------

class SequenceBuilder:
    """Acumula las muestras (en el marco del cuerpo) y la etiqueta de cada una."""

    def __init__(self, profile: UserProfile, rng: np.random.Generator):
        self.p = profile
        self.rng = rng
        self.xyz: list[np.ndarray] = []
        self.labels: list[np.ndarray] = []
        self.script: list[str] = []
        self.posture = np.array(NORMAL_POSTURE, float)

    def _add(self, xyz: np.ndarray, label: str) -> None:
        self.xyz.append(xyz)
        self.labels.append(np.full(len(xyz), LABELS.index(label)))

    def seconds(self, s: float) -> int:
        return int(round(s * SAMPLE_RATE_HZ))

    def normal(self, n: int, posture=NORMAL_POSTURE) -> None:
        self.posture = np.array(posture, float)
        noise = soft_noise(self.rng, self.p.normal_noise, (n, 3))
        self._add(self.posture + noise, "normal")
        self.script.append(f"normal:{n}")

    def typing(self, n: int) -> None:
        self.posture = np.array((0, 0, TYPING_Z), float)
        amp = np.array([self.p.typing_xy, self.p.typing_xy, self.p.typing_z], float)
        if self.p.typing_rhythm_depth > 0:
            t = np.arange(n) / SAMPLE_RATE_HZ
            phase = self.rng.uniform(0, 2 * math.pi)
            env = 1.0 + self.p.typing_rhythm_depth * np.sin(2 * math.pi * self.p.typing_rhythm_hz * t + phase)
            amp = np.outer(env, amp)
        else:
            amp = np.tile(amp, (n, 1))
        noise = uniform_noise(self.rng, np.rint(amp).astype(int), (n, 3))
        self._add(self.posture + noise, "activo")
        self.script.append(f"tecleo:{n}")

    def inert(self, n: int, posture=INERT_POSTURE) -> None:
        self.posture = np.array(posture, float)
        noise = uniform_noise(self.rng, self.p.inert_noise, (n, 3))
        self._add(self.posture + noise, "inerte")
        self.script.append(f"inerte:{n}")

    def nod(self, lead: int, hang: int) -> None:
        """Cabeceo: movimiento normal en la postura despierta, caída hacia el brazo
        colgando (interpolación recta, como el simulador: el módulo baja durante la
        caída) y quietud colgando. Etiquetas: normal, cabeceo, inerte."""
        start = np.array(NOD_FROM, float)
        if self.p.user == 0:
            end = np.array(NOD_TO, float)
        else:
            end = rotate_towards(start, np.array(NOD_TO, float), self.p.nod_angle_deg)
        self._add(start + soft_noise(self.rng, self.p.normal_noise, (lead, 3)), "normal")
        permille = resample_profile(NOD_PROFILE, self.p.nod_samples)
        # El simulador interpola con enteros: from + (to - from) * permille / 1000, con la
        # división truncada hacia cero.
        drop = start + np.trunc(np.outer(permille, end - start) / 1000.0)
        drop = drop + uniform_noise(self.rng, self.p.inert_noise, drop.shape)
        self._add(drop, "cabeceo")
        self._add(end + uniform_noise(self.rng, self.p.inert_noise, (hang, 3)), "inerte")
        self.posture = end
        self.script.append(f"cabeceo:{lead}+{self.p.nod_samples}+{hang}")

    def wake(self, n: int) -> None:
        """Despertar tras un cabeceo: el brazo vuelve despacio a la postura normal."""
        target = np.array(NORMAL_POSTURE, float)
        k = np.linspace(0.0, 1.0, n)[:, None]
        path = self.posture + k * (target - self.posture)
        noise = soft_noise(self.rng, max(10, self.p.normal_noise // 2), (n, 3))
        self._add(path + noise, "normal")
        self.posture = target
        self.script.append(f"despertar:{n}")

    def glance(self, hold: int, target=None) -> None:
        """Negativo difícil (a): giro rápido para mirar la hora y quedarse leyendo, con
        el brazo sostenido (temblor pequeño) y luego bajarlo. Todo es Normal."""
        p = self.p
        start = self.posture.copy()
        target = np.array(GLANCE_TARGET if target is None else target, float)
        raise_path = turn_path(start, target, p.glance_angle_deg, p.glance_samples, p.glance_lift)
        held = rotate_towards(start, target, p.glance_angle_deg)
        noise = lambda n, a: soft_noise(self.rng, a, (n, 3))
        self._add(raise_path + noise(p.glance_samples, p.hold_noise), "normal")
        self._add(held + noise(hold, p.hold_noise), "normal")
        lower = turn_path(held, start, p.glance_angle_deg, GLANCE_LOWER_SAMPLES, p.glance_lift / 2)
        self._add(lower + noise(GLANCE_LOWER_SAMPLES, max(10, p.normal_noise // 2)), "normal")
        self.posture = start
        self.script.append(f"mirar_hora:{p.glance_samples}+{hold}+{GLANCE_LOWER_SAMPLES}")

    def rest_arm(self, lower: int, rest: int, lift: int, angle_deg: float, target) -> None:
        """Negativo difícil (b): apoyar el brazo despacio sobre la mesa, dejarlo un rato
        (la mano todavía se mueve un poco) y volver a moverse. Todo es Normal."""
        p = self.p
        start = self.posture.copy()
        target = np.asarray(target, float)
        down = turn_path(start, target, angle_deg, lower, 0.0)
        rested = rotate_towards(start, target, angle_deg)
        self._add(down + soft_noise(self.rng, max(10, p.normal_noise // 2), (lower, 3)), "normal")
        self._add(rested + soft_noise(self.rng, p.rest_noise, (rest, 3)), "normal")
        up = turn_path(rested, start, angle_deg, lift, 0.0)
        self._add(up + soft_noise(self.rng, max(10, p.normal_noise // 2), (lift, 3)), "normal")
        self.posture = start
        self.script.append(f"apoyar_brazo:{lower}+{rest}+{lift}")

    def build(self, rotation: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
        xyz = np.concatenate(self.xyz) @ rotation.T
        return np.rint(xyz).astype(int), np.concatenate(self.labels)


# --- Tipos de secuencia ---------------------------------------------------------------

def seq_mixed(b: SequenceBuilder, rng: np.random.Generator) -> None:
    """Guardia con varios cambios: normal / tecleo encadenados y, a veces, inactividad."""
    for _ in range(int(rng.integers(3, 6))):
        if rng.random() < 0.5:
            b.normal(b.seconds(rng.uniform(6, 20)))
        else:
            b.typing(b.seconds(rng.uniform(6, 20)))
    if rng.random() < 0.5:
        b.inert(b.seconds(rng.uniform(10, 25)))


def seq_nod(b: SequenceBuilder, rng: np.random.Generator) -> None:
    """Cabeceo precedido de movimiento normal o tecleo, a veces seguido de despertar."""
    if rng.random() < 0.5:
        b.typing(b.seconds(rng.uniform(4, 12)))
    else:
        b.normal(b.seconds(rng.uniform(4, 12)))
    b.nod(lead=b.seconds(rng.uniform(2, 5)), hang=b.seconds(rng.uniform(6, 20)))
    if rng.random() < 0.5:
        b.wake(b.seconds(rng.uniform(0.8, 1.6)))
        b.normal(b.seconds(rng.uniform(5, 12)))


def seq_typing_then_normal(b: SequenceBuilder, rng: np.random.Generator) -> None:
    """Dejar de teclear y seguir moviéndose con normalidad (no debe dar cabeceo)."""
    b.typing(b.seconds(rng.uniform(10, 25)))
    b.normal(b.seconds(rng.uniform(10, 20)))


def seq_inactivity(b: SequenceBuilder, rng: np.random.Generator) -> None:
    """Movimiento normal y luego el brazo inerte un buen rato."""
    b.normal(b.seconds(rng.uniform(3, 10)))
    b.inert(b.seconds(rng.uniform(15, 40)))


def random_direction(rng: np.random.Generator) -> np.ndarray:
    v = rng.normal(size=3)
    return 1000.0 * v / np.linalg.norm(v)


def seq_glance(b: SequenceBuilder, rng: np.random.Generator) -> None:
    """Negativo difícil (a): una o dos miradas a la hora entre movimiento normal o tecleo."""
    if rng.random() < 0.5:
        b.typing(b.seconds(rng.uniform(5, 10)))
        b.normal(b.seconds(rng.uniform(1, 2)))
    else:
        b.normal(b.seconds(rng.uniform(5, 10)))
    target = None if b.p.user == 0 else random_direction(rng)
    for _ in range(int(rng.integers(1, 3))):
        b.glance(hold=b.seconds(rng.uniform(3, 8)), target=target)
        b.normal(b.seconds(rng.uniform(4, 8)))


def seq_rest_arm(b: SequenceBuilder, rng: np.random.Generator) -> None:
    """Negativo difícil (b): apoyar el brazo despacio en la mesa y volver a moverse."""
    b.normal(b.seconds(rng.uniform(5, 10)))
    b.rest_arm(lower=b.seconds(rng.uniform(1, 3)), rest=b.seconds(rng.uniform(3, 6)),
               lift=b.seconds(rng.uniform(1, 2)), angle_deg=float(rng.uniform(30, 70)),
               target=random_direction(rng))
    b.normal(b.seconds(rng.uniform(5, 10)))


# Tipo → (función, secuencias por usuario, ¿negativo difícil?)
SEQUENCE_KINDS = {
    "mixta": (seq_mixed, 2, False),
    "cabeceo": (seq_nod, 3, False),
    "tecleo_normal": (seq_typing_then_normal, 1, False),
    "inactividad": (seq_inactivity, 1, False),
    "mirar_hora": (seq_glance, 2, True),
    "apoyar_brazo": (seq_rest_arm, 2, True),
}


# --- Dataset --------------------------------------------------------------------------

def generate(seed: int, users: int) -> tuple[pd.DataFrame, pd.DataFrame]:
    master = np.random.default_rng(seed)
    profiles = [reference_user()] + [random_user(u, master) for u in range(1, users)]
    sample_frames = []
    sequence_rows = []
    sequence_id = 0
    for profile in profiles:
        for kind, (fn, count, hard) in SEQUENCE_KINDS.items():
            for _ in range(count):
                # Un generador por secuencia: el resultado no depende del orden.
                rng = np.random.default_rng([seed, profile.user, sequence_id])
                builder = SequenceBuilder(profile, rng)
                fn(builder, rng)
                rotation = random_rotation(rng)
                xyz, labels = builder.build(rotation)
                demo = bool(rng.random() < 0.5)
                n = len(xyz)
                sample_frames.append(pd.DataFrame({
                    "t": np.arange(n) * SAMPLE_MS,
                    "x": xyz[:, 0], "y": xyz[:, 1], "z": xyz[:, 2],
                    "etiqueta": np.array(LABELS)[labels],
                    "usuario": profile.user,
                    "secuencia": sequence_id,
                }))
                sequence_rows.append({
                    "secuencia": sequence_id,
                    "usuario": profile.user,
                    "tipo": kind,
                    "negativo_dificil": hard,
                    "demo": demo,
                    "muestras": n,
                    "guion": " ".join(builder.script),
                })
                sequence_id += 1
    return pd.concat(sample_frames, ignore_index=True), pd.DataFrame(sequence_rows)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--seed", type=int, default=20261114)
    parser.add_argument("--users", type=int, default=48)
    parser.add_argument("--out", type=Path, default=DATA_DIR)
    args = parser.parse_args()

    samples, sequences = generate(args.seed, args.users)
    args.out.mkdir(parents=True, exist_ok=True)
    samples.to_csv(args.out / "samples.csv", index=False)
    sequences.to_csv(args.out / "sequences.csv", index=False)

    counts = samples["etiqueta"].value_counts()
    print(f"Dataset SINTÉTICO (semilla {args.seed}): {args.users} usuarios, "
          f"{len(sequences)} secuencias, {len(samples)} muestras "
          f"({len(samples) / SAMPLE_RATE_HZ / 60:.1f} min a 25 Hz).")
    print("Muestras por etiqueta: " + ", ".join(f"{k} {counts.get(k, 0)}" for k in LABELS))
    print(f"Escrito en {args.out}")


if __name__ == "__main__":
    main()
