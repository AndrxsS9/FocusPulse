import Toybox.Lang;

//! Foto de las características de telemetría en un instante.
//!
//! La crea TelemetryEngine.snapshot(); es un objeto de solo datos que las vistas y,
//! más adelante, el detector leen sin tocar la ventana. Unidades: mg, mg², s, Hz.
class TelemetrySnapshot {

    //! Última muestra recibida (mg).
    var x as Number = 0;
    var y as Number = 0;
    var z as Number = 0;

    //! Media de la magnitud en la ventana (mg).
    var meanMagnitude as Float = 0.0f;

    //! Gravedad estimada: media de cada eje en la ventana de 2 s (mg). Su dirección da
    //! la inclinación del reloj; la compara el detector antes y después de una caída.
    var gravityX as Float = 0.0f;
    var gravityY as Float = 0.0f;
    var gravityZ as Float = 0.0f;

    //! Varianza de la magnitud en la ventana (mg²).
    var variance as Float = 0.0f;

    //! Sacudida máxima en las últimas SlidingWindow.JERK_SAMPLES muestras (mg).
    var jerk as Number = 0;

    //! Sacudida máxima dentro del último lote (mg). Un lote de 1 s trae 25 muestras y
    //! `jerk` solo mira las 10 últimas, así que este valor evita perder un pico que
    //! ocurrió al principio del lote.
    var batchPeakJerk as Number = 0;

    //! Segundos de quietud continua (0 si hay movimiento).
    var stillSeconds as Float = 0.0f;

    //! true si la ventana está llena y quieta.
    var isStill as Boolean = false;

    //! true cuando la ventana ya tiene SlidingWindow.WINDOW_SAMPLES muestras.
    var windowFull as Boolean = false;

    //! Muestras recibidas desde el último reset.
    var samplesReceived as Number = 0;

    //! Lotes recibidos desde el último reset.
    var batchesReceived as Number = 0;

    //! Frecuencia efectiva medida (Hz). 0 hasta tener al menos dos lotes.
    var effectiveHz as Float = 0.0f;

    function initialize() {
    }
}
