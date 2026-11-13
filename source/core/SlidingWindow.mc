import Toybox.Lang;
import Toybox.Math;

//! Ventana deslizante de 2 s sobre las muestras del acelerómetro.
//!
//! Calcula de forma incremental, con cada muestra:
//!
//! - **Media y varianza de la magnitud** (mg y mg²). Se mantienen la suma y la suma de
//!   cuadrados en `Long` sobre magnitudes enteras, así que sumar la muestra nueva y restar
//!   la que sale es exacto y no acumula deriva aunque la guardia dure horas.
//! - **Sacudida** (*jerk*): mayor |Δ| vectorial, en mg, entre muestras consecutivas dentro
//!   de las últimas JERK_SAMPLES muestras.
//! - **Quietud**: segundos seguidos con la ventana llena y varianza < STILL_VARIANCE_MAX.
//!   Empieza a contar cuando la ventana completa ya está quieta, así que va unos
//!   WINDOW_SECONDS por detrás del momento real en que cesa el movimiento.
//! - **Gravedad**: media de cada eje (mg). En 2 s el movimiento de la muñeca se promedia
//!   y queda sobre todo la gravedad, así que su dirección da la inclinación del reloj
//!   (ver Tilt). Sumas enteras exactas, igual que la magnitud.
//!
//! El tiempo entra como parámetro (ms) para poder probarlo sin reloj.
//! Lógica pura: no depende de Sensor, WatchUi ni Graphics.
class SlidingWindow {

    //! Frecuencia de trabajo del acelerómetro (Hz).
    static const SAMPLE_RATE_HZ = 25;

    //! Duración de la ventana (s).
    static const WINDOW_SECONDS = 2;

    //! Muestras en la ventana: 2 s × 25 Hz.
    static const WINDOW_SAMPLES = SAMPLE_RATE_HZ * WINDOW_SECONDS;

    //! Muestras recientes sobre las que se busca la sacudida máxima.
    static const JERK_SAMPLES = 10;

    //! Varianza máxima de la magnitud (mg²) para considerar la muñeca quieta.
    //! 100 mg² = desviación típica de 10 mg: el ruido de un brazo inerte (±4 mg) queda
    //! muy por debajo y el movimiento normal (±70 mg) muy por encima.
    static const STILL_VARIANCE_MAX = 100.0f;

    private var _buffer as RingBuffer;

    //! Suma y suma de cuadrados de las magnitudes de la ventana.
    private var _sum as Long = 0l;
    private var _sumSq as Long = 0l;

    //! Sumas de cada eje en la ventana (gravedad media). Caben en Number: 50 muestras de
    //! como mucho ±8000 mg.
    private var _sumX as Number = 0;
    private var _sumY as Number = 0;
    private var _sumZ as Number = 0;

    //! |Δ| vectorial de las últimas JERK_SAMPLES transiciones (circular).
    private var _deltas as Array<Number>;
    private var _deltaHead as Number = 0;
    private var _deltaCount as Number = 0;
    private var _lastDelta as Number = 0;

    //! Marca de tiempo (ms) de la última muestra.
    private var _lastTimeMs as Number = 0;

    //! Marca de tiempo (ms) en que empezó la quietud actual, o null si hay movimiento.
    private var _stillSinceMs as Number? = null;

    function initialize() {
        _buffer = new RingBuffer(WINDOW_SAMPLES);
        _deltas = new Array<Number>[JERK_SAMPLES - 1];
        for (var i = 0; i < _deltas.size(); i++) {
            _deltas[i] = 0;
        }
    }

    //! Agrega una muestra (mg) tomada en el instante timeMs.
    function push(x as Number, y as Number, z as Number, timeMs as Number) as Void {
        var magnitude = RingBuffer.magnitudeOf(x, y, z);

        // Sacudida respecto a la muestra anterior.
        if (!_buffer.isEmpty()) {
            var last = _buffer.newestIndex();
            var dx = x - _buffer.x(last);
            var dy = y - _buffer.y(last);
            var dz = z - _buffer.z(last);
            _lastDelta = RingBuffer.magnitudeOf(dx, dy, dz);
            _deltas[_deltaHead] = _lastDelta;
            _deltaHead = (_deltaHead + 1) % _deltas.size();
            if (_deltaCount < _deltas.size()) {
                _deltaCount += 1;
            }
        }

        // Media y varianza: sale la más antigua si la ventana está llena.
        if (_buffer.isFull()) {
            var old = _buffer.magnitude(0).toLong();
            _sum -= old;
            _sumSq -= old * old;
            _sumX -= _buffer.x(0);
            _sumY -= _buffer.y(0);
            _sumZ -= _buffer.z(0);
        }
        _buffer.push(x, y, z);
        _sumX += x;
        _sumY += y;
        _sumZ += z;
        var m = magnitude.toLong();
        _sum += m;
        _sumSq += m * m;
        _lastTimeMs = timeMs;

        // Quietud.
        if (isStill()) {
            if (_stillSinceMs == null) {
                _stillSinceMs = timeMs;
            }
        } else {
            _stillSinceMs = null;
        }
    }

    //! Vacía la ventana (p. ej. al iniciar una guardia nueva o cambiar de fuente).
    function reset() as Void {
        _buffer.clear();
        _sum = 0l;
        _sumSq = 0l;
        _sumX = 0;
        _sumY = 0;
        _sumZ = 0;
        _deltaHead = 0;
        _deltaCount = 0;
        _lastDelta = 0;
        _lastTimeMs = 0;
        _stillSinceMs = null;
    }

    //! Muestras en la ventana (como máximo WINDOW_SAMPLES).
    function count() as Number {
        return _buffer.size();
    }

    //! true cuando la ventana tiene WINDOW_SAMPLES muestras.
    function isFull() as Boolean {
        return _buffer.isFull();
    }

    //! Media de la magnitud (mg). 0 si está vacía.
    function mean() as Float {
        var n = _buffer.size();
        if (n == 0) {
            return 0.0f;
        }
        return (_sum.toDouble() / n).toFloat();
    }

    //! Varianza poblacional de la magnitud (mg²). 0 con menos de 2 muestras.
    function variance() as Float {
        var n = _buffer.size().toLong();
        if (n < 2) {
            return 0.0f;
        }
        // (n·Σm² − (Σm)²) / n², exacto en Long hasta la división.
        var numerator = n * _sumSq - _sum * _sum;
        return (numerator.toDouble() / (n * n).toDouble()).toFloat();
    }

    //! Media del eje x en la ventana (mg): componente x de la gravedad. 0 si está vacía.
    function meanX() as Float {
        return axisMean(_sumX);
    }

    //! Media del eje y en la ventana (mg).
    function meanY() as Float {
        return axisMean(_sumY);
    }

    //! Media del eje z en la ventana (mg).
    function meanZ() as Float {
        return axisMean(_sumZ);
    }

    private function axisMean(sum as Number) as Float {
        var n = _buffer.size();
        return n == 0 ? 0.0f : sum.toFloat() / n;
    }

    //! Desviación típica de la magnitud (mg).
    function stdDev() as Float {
        return Math.sqrt(variance()).toFloat();
    }

    //! Mayor |Δ| vectorial (mg) entre muestras consecutivas de las últimas JERK_SAMPLES.
    function jerk() as Number {
        var max = 0;
        for (var i = 0; i < _deltaCount; i++) {
            if (_deltas[i] > max) {
                max = _deltas[i];
            }
        }
        return max;
    }

    //! |Δ| vectorial (mg) entre las dos últimas muestras.
    function lastDelta() as Number {
        return _lastDelta;
    }

    //! true si la ventana está llena y su varianza es menor que STILL_VARIANCE_MAX.
    function isStill() as Boolean {
        return _buffer.isFull() && variance() < STILL_VARIANCE_MAX;
    }

    //! Segundos de quietud continua hasta la última muestra (0 si hay movimiento).
    function stillSeconds() as Float {
        var since = _stillSinceMs;
        if (since == null) {
            return 0.0f;
        }
        return (_lastTimeMs - since) / 1000.0f;
    }

    //! Ejes de la muestra más reciente (0 si la ventana está vacía).
    function lastX() as Number {
        return _buffer.isEmpty() ? 0 : _buffer.x(_buffer.newestIndex());
    }

    function lastY() as Number {
        return _buffer.isEmpty() ? 0 : _buffer.y(_buffer.newestIndex());
    }

    function lastZ() as Number {
        return _buffer.isEmpty() ? 0 : _buffer.z(_buffer.newestIndex());
    }
}
