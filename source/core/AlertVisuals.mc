import Toybox.Lang;

//! Curvas de animación de la alerta a pantalla completa (AlertView). Lógica pura: el
//! tiempo entra como parámetro (ms desde que se abrió la alerta) y no se dibuja nada.
//!
//! - **Entrada**: en ENTRANCE_MS (300 ms) el fondo crece desde el centro y el botón
//!   entra con un pequeño rebote de escala (llega a ≈ 108 % y vuelve a 100 %).
//! - **Pulso de brillo** del fondo: una onda triangular 0 → 1 → 0 por periodo, sin
//!   saltos. El periodo es de 2,4 / 1,8 / 1,2 s según el nivel: **menos de 1 ciclo por
//!   segundo**, muy por debajo del límite de 3 destellos por segundo para personas
//!   fotosensibles (WCAG 2.3.1). PHOTOSENSITIVE_MIN_PERIOD_MS es ese límite.
//! - **Sacudida**: mientras el motor está encendido (VibePatterns.isOnAt, con el patrón
//!   del ajuste de vibración) el contenido se desplaza ±SHAKE_PX (2 / 4 / 6 px según el
//!   nivel), cambiando de lado cada SHAKE_STEP_MS. En las pausas, o con la vibración
//!   apagada, no se mueve.
//! - **Animaciones reducidas** (ajuste, fase 11): sin sacudida y con el pulso de brillo
//!   REDUCED_PULSE_FACTOR veces más lento (4,8 / 3,6 / 2,4 s). La alerta sigue siendo
//!   inconfundible por el color de pantalla completa de cada nivel y por sus textos;
//!   la entrada de 300 ms no cambia (es un solo movimiento, no se repite).
module AlertVisuals {

    //! Duración de la animación de entrada (ms).
    const ENTRANCE_MS = 300;

    //! Exceso del rebote (easeOutBack): con 1,5 la escala llega a ≈ 1,08.
    const ENTRANCE_OVERSHOOT = 1.5f;

    //! Periodo del pulso de brillo por nivel (ms).
    const PULSE_PERIOD_MS = [2400, 1800, 1200];

    //! Periodo mínimo admisible: 3 ciclos por segundo (≈ 333 ms) es el umbral de
    //! destellos peligrosos; cualquier periodo debe ser mayor.
    const PHOTOSENSITIVE_MIN_PERIOD_MS = 334;

    //! Con animaciones reducidas, el pulso de brillo dura este múltiplo del normal.
    const REDUCED_PULSE_FACTOR = 2;

    //! Desplazamiento de la sacudida por nivel (px) y cada cuánto cambia de lado (ms).
    const SHAKE_PX = [2, 4, 6];
    const SHAKE_STEP_MS = 50;

    //! Avance de la entrada, de 0 (recién abierta) a 1 (terminada).
    function entranceProgress(elapsedMs as Number) as Float {
        if (elapsedMs <= 0) {
            return 0.0f;
        }
        if (elapsedMs >= ENTRANCE_MS) {
            return 1.0f;
        }
        return elapsedMs / ENTRANCE_MS.toFloat();
    }

    //! Escala del rebote de entrada (easeOutBack): 0 al empezar, pasa un poco de 1 y
    //! termina exactamente en 1 a los ENTRANCE_MS.
    function entranceScale(elapsedMs as Number) as Float {
        var t = entranceProgress(elapsedMs);
        if (t >= 1.0f) {
            return 1.0f;
        }
        var c1 = ENTRANCE_OVERSHOOT;
        var c3 = c1 + 1.0f;
        var u = t - 1.0f;
        return 1.0f + c3 * u * u * u + c1 * u * u;
    }

    //! Periodo del pulso de brillo del nivel (ms); reduced: animaciones reducidas.
    function pulsePeriodMs(level as Number, reduced as Boolean) as Number {
        var periods = PULSE_PERIOD_MS as Array<Number>;
        var period = periods[AlertnessColors.clampAlertLevel(level) - 1];
        return reduced ? period * REDUCED_PULSE_FACTOR : period;
    }

    //! Pulso de brillo en 0..1 (onda triangular): 0 al empezar cada periodo, 1 a la
    //! mitad.
    function pulse(level as Number, reduced as Boolean, elapsedMs as Number) as Float {
        if (elapsedMs <= 0) {
            return 0.0f;
        }
        var period = pulsePeriodMs(level, reduced);
        var t = elapsedMs % period;
        var half = period / 2;
        if (t <= half) {
            return t / half.toFloat();
        }
        return (period - t) / (period - half).toFloat();
    }

    //! Amplitud de la sacudida del nivel (px).
    function shakeAmplitude(level as Number) as Number {
        var amplitudes = SHAKE_PX as Array<Number>;
        return amplitudes[AlertnessColors.clampAlertLevel(level) - 1];
    }

    //! Desplazamiento horizontal del contenido (px): ±amplitud mientras el motor está
    //! encendido; 0 en las pausas, con la vibración apagada (sin motor no hay nada que
    //! acompañar) y con animaciones reducidas.
    function shakeOffset(level as Number, vibration as VibrationLevel.Id, reduced as Boolean,
            elapsedMs as Number) as Number {
        if (reduced || vibration == VibrationLevel.OFF
                || !VibePatterns.isOnAt(level, vibration, elapsedMs)) {
            return 0;
        }
        var amplitude = shakeAmplitude(level);
        return (elapsedMs / SHAKE_STEP_MS) % 2 == 0 ? amplitude : -amplitude;
    }
}
