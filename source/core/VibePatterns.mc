import Toybox.Lang;

//! Patrones de vibración de la alerta por nivel (1–3) y por ajuste de vibración.
//!
//! Los Forerunner ignoran la intensidad (dutyCycle) de Attention.VibeProfile: siempre
//! vibran con la misma fuerza. Por eso tanto los niveles de la alerta como el ajuste
//! "Vibración" (Suave / Normal / Fuerte, fase 11) cambian solo la cantidad y la duración
//! de los pulsos y las pausas; el periodo de repetición depende solo del nivel.
//!
//! | Ajuste | Nivel 1 (cada 3 s) | Nivel 2 (cada 2 s) | Nivel 3 (cada 4 s) |
//! |---|---|---|---|
//! | Suave | 1 × 150 ms | 2 × 250 ms, pausa 200 | 3 × 600 ms, pausa 250 |
//! | **Normal** (fase 7) | 2 × 150 ms, pausa 150 | 3 × 300 ms, pausa 200 | 4 × 800 ms, pausa 200 |
//! | Fuerte | 3 × 200 ms, pausa 150 | 4 × 350 ms, pausa 150 | 4 × 900 ms, pausa 100 |
//!
//! Con Normal el nivel 3 queda casi continuo: entre ráfagas, la misma pausa de 200 ms que
//! entre pulsos. Tiempo encendido por ráfaga: Suave 150 / 500 / 1 800 ms, Normal 300 /
//! 900 / 3 200, Fuerte 600 / 1 400 / 3 600: crece con el nivel y con el ajuste.
//!
//! Con la vibración **Apagada** se usan los tiempos de Normal: la luz y los tonos siguen
//! ese ritmo, pero Haptics no enciende el motor y la alerta no se sacude.
//!
//! Un patrón es la lista de tramos de una ráfaga, en ms, alternando encendido y apagado
//! y empezando y terminando encendido: [150, 150, 150] = pulso, pausa, pulso. Cada tramo
//! se convierte en un VibeProfile (source/platform/Haptics.mc), así que la lista nunca
//! pasa de MAX_SEGMENTS (el máximo de Attention.vibrate por llamada): como mucho 4
//! pulsos, 7 tramos. La ráfaga cabe siempre dentro de su periodo: al repetirse no se
//! solapa con la anterior.
//!
//! Lógica pura (sin Attention): se prueba con Toybox.Test y la vista de la alerta la usa
//! para sincronizar la "sacudida" con los pulsos (isOnAt).
module VibePatterns {

    //! Máximo de tramos (VibeProfile) por llamada a Attention.vibrate.
    const MAX_SEGMENTS = 8;

    //! Tablas [ajuste][nivel]: filas Suave, Normal, Fuerte; columnas nivel 1, 2, 3.
    const PULSES = [[1, 2, 3], [2, 3, 4], [3, 4, 4]];
    const PULSE_MS = [[150, 250, 600], [150, 300, 800], [200, 350, 900]];
    const GAP_MS = [[150, 200, 250], [150, 200, 200], [150, 150, 100]];

    //! Cada cuánto se repite la ráfaga, por nivel (igual con cualquier ajuste).
    const PERIOD_MS = [3000, 2000, 4000];

    //! Fila de las tablas para el ajuste (Apagada usa la de Normal).
    function row(vibration as VibrationLevel.Id) as Number {
        if (vibration == VibrationLevel.SOFT) {
            return 0;
        }
        if (vibration == VibrationLevel.STRONG) {
            return 2;
        }
        return 1;
    }

    //! Columna de las tablas para el nivel (se recorta a 1–3).
    function column(level as Number) as Number {
        return AlertnessColors.clampAlertLevel(level) - 1;
    }

    //! Número de pulsos encendidos.
    function pulses(level as Number, vibration as VibrationLevel.Id) as Number {
        return ((PULSES as Array<Array<Number>>)[row(vibration)])[column(level)];
    }

    //! Duración de cada pulso encendido (ms).
    function pulseMs(level as Number, vibration as VibrationLevel.Id) as Number {
        return ((PULSE_MS as Array<Array<Number>>)[row(vibration)])[column(level)];
    }

    //! Pausa entre pulsos (ms).
    function gapMs(level as Number, vibration as VibrationLevel.Id) as Number {
        return ((GAP_MS as Array<Array<Number>>)[row(vibration)])[column(level)];
    }

    //! Cada cuánto se repite la ráfaga (ms).
    function periodMs(level as Number) as Number {
        return (PERIOD_MS as Array<Number>)[column(level)];
    }

    //! Tramos de una ráfaga en ms: encendido, apagado, encendido… (índices pares
    //! encendidos). Devuelve un arreglo nuevo.
    function segments(level as Number, vibration as VibrationLevel.Id) as Array<Number> {
        var count = pulses(level, vibration);
        var on = pulseMs(level, vibration);
        var off = gapMs(level, vibration);
        var result = new Array<Number>[2 * count - 1];
        for (var i = 0; i < result.size(); i++) {
            result[i] = i % 2 == 0 ? on : off;
        }
        return result;
    }

    //! Duración de una ráfaga completa (ms).
    function burstMs(level as Number, vibration as VibrationLevel.Id) as Number {
        var count = pulses(level, vibration);
        return count * pulseMs(level, vibration) + (count - 1) * gapMs(level, vibration);
    }

    //! true si el patrón está en un pulso a cycleMs del inicio de la ráfaga. Se repite
    //! cada periodMs, así que cycleMs puede ser el tiempo desde que empezó la alerta. Con
    //! la vibración apagada sigue el patrón de Normal (quien llama decide si hay motor).
    function isOnAt(level as Number, vibration as VibrationLevel.Id, cycleMs as Number) as Boolean {
        if (cycleMs < 0) {
            return false;
        }
        var t = cycleMs % periodMs(level);
        var step = pulseMs(level, vibration) + gapMs(level, vibration);
        if (t >= burstMs(level, vibration)) {
            return false;
        }
        return t % step < pulseMs(level, vibration);
    }
}
