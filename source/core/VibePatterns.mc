import Toybox.Lang;

//! Patrones de vibración de la alerta por nivel.
//!
//! Los Forerunner ignoran la intensidad (dutyCycle) de Attention.VibeProfile: siempre
//! vibran con la misma fuerza. Por eso los niveles se distinguen solo por la duración y
//! la cantidad de pulsos y por cada cuánto se repiten:
//!
//! | Nivel | Pulsos | Encendido | Pausa | Se repite cada | Ráfaga |
//! |---|---|---|---|---|---|
//! | 1 suave | 2 | 150 ms | 150 ms | 3 s | 450 ms |
//! | 2 media | 3 | 300 ms | 200 ms | 2 s | 1 300 ms |
//! | 3 máxima | 4 | 800 ms | 200 ms | 4 s | 3 800 ms (+ 200 ms de pausa al repetir: casi continuo) |
//!
//! Un patrón es la lista de tramos de una ráfaga, en ms, alternando encendido y apagado
//! y empezando y terminando encendido: [150, 150, 150] = pulso, pausa, pulso. Cada tramo
//! se convierte en un VibeProfile (source/platform/Haptics.mc), así que la lista nunca
//! pasa de MAX_SEGMENTS (el máximo de Attention.vibrate por llamada). La ráfaga cabe
//! siempre dentro de su periodo: al repetirse no se solapa con la anterior.
//!
//! Lógica pura (sin Attention): se prueba con Toybox.Test y la vista de la alerta la usa
//! para sincronizar la "sacudida" con los pulsos (isOnAt).
module VibePatterns {

    //! Máximo de tramos (VibeProfile) por llamada a Attention.vibrate.
    const MAX_SEGMENTS = 8;

    //! Nivel 1 (suave): 2 pulsos cortos cada 3 s.
    const SOFT_PULSES = 2;
    const SOFT_PULSE_MS = 150;
    const SOFT_GAP_MS = 150;
    const SOFT_PERIOD_MS = 3000;

    //! Nivel 2 (media): 3 pulsos de 300 ms cada 2 s.
    const MEDIUM_PULSES = 3;
    const MEDIUM_PULSE_MS = 300;
    const MEDIUM_GAP_MS = 200;
    const MEDIUM_PERIOD_MS = 2000;

    //! Nivel 3 (máxima): tramos de 800 ms con pausas de 200 ms, casi continuo. La
    //! repetición deja la misma pausa de 200 ms entre ráfagas.
    const MAX_PULSES = 4;
    const MAX_PULSE_MS = 800;
    const MAX_GAP_MS = 200;
    const MAX_PERIOD_MS = 4000;

    //! Número de pulsos encendidos del nivel (se recorta a 1–3).
    function pulses(level as Number) as Number {
        var clamped = AlertnessColors.clampAlertLevel(level);
        if (clamped == 1) {
            return SOFT_PULSES;
        }
        if (clamped == 2) {
            return MEDIUM_PULSES;
        }
        return MAX_PULSES;
    }

    //! Duración de cada pulso encendido (ms).
    function pulseMs(level as Number) as Number {
        var clamped = AlertnessColors.clampAlertLevel(level);
        if (clamped == 1) {
            return SOFT_PULSE_MS;
        }
        if (clamped == 2) {
            return MEDIUM_PULSE_MS;
        }
        return MAX_PULSE_MS;
    }

    //! Pausa entre pulsos (ms).
    function gapMs(level as Number) as Number {
        var clamped = AlertnessColors.clampAlertLevel(level);
        if (clamped == 1) {
            return SOFT_GAP_MS;
        }
        if (clamped == 2) {
            return MEDIUM_GAP_MS;
        }
        return MAX_GAP_MS;
    }

    //! Cada cuánto se repite la ráfaga (ms).
    function periodMs(level as Number) as Number {
        var clamped = AlertnessColors.clampAlertLevel(level);
        if (clamped == 1) {
            return SOFT_PERIOD_MS;
        }
        if (clamped == 2) {
            return MEDIUM_PERIOD_MS;
        }
        return MAX_PERIOD_MS;
    }

    //! Tramos de una ráfaga en ms: encendido, apagado, encendido… (índices pares
    //! encendidos). Devuelve un arreglo nuevo.
    function segments(level as Number) as Array<Number> {
        var count = pulses(level);
        var on = pulseMs(level);
        var off = gapMs(level);
        var result = new Array<Number>[2 * count - 1];
        for (var i = 0; i < result.size(); i++) {
            result[i] = i % 2 == 0 ? on : off;
        }
        return result;
    }

    //! Duración de una ráfaga completa (ms).
    function burstMs(level as Number) as Number {
        var count = pulses(level);
        return count * pulseMs(level) + (count - 1) * gapMs(level);
    }

    //! true si el motor está encendido a cycleMs del inicio de la ráfaga. Se repite cada
    //! periodMs, así que cycleMs puede ser el tiempo desde que empezó la alerta.
    function isOnAt(level as Number, cycleMs as Number) as Boolean {
        if (cycleMs < 0) {
            return false;
        }
        var t = cycleMs % periodMs(level);
        var step = pulseMs(level) + gapMs(level);
        if (t >= burstMs(level)) {
            return false;
        }
        return t % step < pulseMs(level);
    }
}
