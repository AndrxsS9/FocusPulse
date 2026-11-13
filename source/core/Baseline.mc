import Toybox.Lang;
import Toybox.Math;

//! Línea base adaptativa del movimiento del usuario.
//!
//! Aprende la varianza típica de la magnitud mientras el usuario está despierto, en
//! escala logarítmica: x = ln(varianza + 1). El logaritmo hace comparables a quien
//! apenas se mueve (≈ 200 mg², x ≈ 5,3) y a quien teclea (≈ 18 000 mg², x ≈ 9,8), y
//! el + 1 evita ln(0) con el reloj inmóvil.
//!
//! 1. **Calibración** (start): durante CALIBRATION_MS (30 s; 5 s en modo demo) acumula
//!    la media y la desviación de x de las ventanas que recibe.
//! 2. **Adaptación**: después, cada ventana mueve la media y la varianza de x con una
//!    media móvil exponencial (EMA) de peso EMA_ALPHA: con un lote por segundo, la
//!    constante de tiempo es de unos 100 s.
//!
//! Quien la alimenta (DrowsinessDetector) solo le pasa ventanas ordinarias: ni quietas,
//! ni con una caída pendiente, ni de un evento o su periodo refractario. Así un cabeceo
//! o un rato inmóvil no arrastran la línea base hacia abajo.
//!
//! **Umbral de quietud adaptativo.** El mínimo entre la constante de la fase 3
//! (SlidingWindow.STILL_VARIANCE_MAX, 100 mg²) y STILL_FRACTION de la varianza típica
//! (e^media − 1), sin bajar de STILL_FLOOR. A quien se mueve poco (varianza típica de
//! 200 mg²) le basta una varianza menor de 50 mg² para contar como quieto; con el
//! movimiento normal (≈ 700 mg²) el umbral sigue en 100. Mientras calibra usa 100.
//!
//! Si la calibración termina sin ventanas válidas (el usuario no se movió) quedan los
//! valores por defecto, los del movimiento normal simulado.
//!
//! El tiempo entra como parámetro. Lógica pura: no depende de Sensor, WatchUi ni
//! Graphics.
class Baseline {

    //! Duración de la calibración (ms) en modo normal y en modo demo.
    static const CALIBRATION_MS = 30000;
    static const CALIBRATION_DEMO_MS = 5000;

    //! Valores por defecto de la media y la desviación de ln(varianza + 1):
    //! ln(700 + 1) ≈ 6,55, el movimiento normal simulado.
    static const DEFAULT_MEAN = 6.55f;
    static const DEFAULT_STD = 0.5f;

    //! Desviación mínima: con pocas ventanas casi iguales no queda en 0.
    static const MIN_STD = 0.05f;

    //! Peso de cada ventana nueva en la adaptación lenta.
    static const EMA_ALPHA = 0.01f;

    //! Fracción de la varianza típica que marca la quietud, y límites del umbral (mg²).
    static const STILL_FRACTION = 0.25f;
    static const STILL_FLOOR = 25.0f;
    static const STILL_MAX = SlidingWindow.STILL_VARIANCE_MAX;

    private var _calibrating as Boolean = false;
    private var _ready as Boolean = false;
    private var _startMs as Number = 0;
    private var _durationMs as Number = CALIBRATION_MS;

    //! Acumuladores de la calibración.
    private var _count as Number = 0;
    private var _sum as Float = 0.0f;
    private var _sumSq as Float = 0.0f;

    //! Media y varianza de ln(varianza + 1).
    private var _mean as Float = DEFAULT_MEAN;
    private var _var as Float = DEFAULT_STD * DEFAULT_STD;

    //! Ventanas aplicadas con la EMA desde que terminó la calibración.
    private var _adaptCount as Number = 0;

    function initialize() {
    }

    //! ln(varianza + 1), la escala en que trabaja la línea base.
    static function logVariance(variance as Float) as Float {
        return Math.ln(variance + 1.0f).toFloat();
    }

    //! Empieza a calibrar en nowMs durante durationMs.
    function start(nowMs as Number, durationMs as Number) as Void {
        reset();
        _calibrating = true;
        _startMs = nowMs;
        _durationMs = durationMs;
    }

    //! Vuelve a los valores por defecto, sin calibrar (guardia en pausa).
    function reset() as Void {
        _calibrating = false;
        _ready = false;
        _count = 0;
        _sum = 0.0f;
        _sumSq = 0.0f;
        _mean = DEFAULT_MEAN;
        _var = DEFAULT_STD * DEFAULT_STD;
        _adaptCount = 0;
    }

    //! Recibe la varianza de una ventana ordinaria (null si la ventana no sirve) en
    //! timeMs. Calibrando, la acumula y cierra la calibración a su hora; después, la
    //! aplica con la EMA. Devuelve true en la llamada que termina la calibración.
    function observe(variance as Float?, timeMs as Number) as Boolean {
        if (_calibrating) {
            if (variance != null) {
                var x = logVariance(variance);
                _count += 1;
                _sum += x;
                _sumSq += x * x;
            }
            if (timeMs - _startMs >= _durationMs) {
                finishCalibration();
                return true;
            }
            return false;
        }
        if (_ready && variance != null) {
            var x = logVariance(variance);
            var d = x - _mean;
            _mean += EMA_ALPHA * d;
            _var = (1.0f - EMA_ALPHA) * (_var + EMA_ALPHA * d * d);
            _adaptCount += 1;
        }
        return false;
    }

    private function finishCalibration() as Void {
        _calibrating = false;
        _ready = true;
        if (_count == 0) {
            return;
        }
        _mean = _sum / _count;
        if (_count >= 2) {
            var v = _sumSq / _count - _mean * _mean;
            _var = v > 0.0f ? v : 0.0f;
        }
        if (_var < MIN_STD * MIN_STD) {
            _var = MIN_STD * MIN_STD;
        }
    }

    function isCalibrating() as Boolean {
        return _calibrating;
    }

    //! true cuando la calibración terminó.
    function isReady() as Boolean {
        return _ready;
    }

    //! Ventanas que entraron en la calibración.
    function calibrationCount() as Number {
        return _count;
    }

    //! Ventanas aplicadas con la EMA.
    function adaptCount() as Number {
        return _adaptCount;
    }

    //! Media de ln(varianza + 1).
    function mean() as Float {
        return _mean;
    }

    //! Desviación típica de ln(varianza + 1).
    function stdDev() as Float {
        return Math.sqrt(_var).toFloat();
    }

    //! Varianza típica del usuario (mg²): e^media − 1.
    function typicalVariance() as Float {
        return (Math.pow(Math.E, _mean) - 1.0f).toFloat();
    }

    //! Umbral de quietud efectivo (mg²).
    function stillThreshold() as Float {
        if (!_ready) {
            return STILL_MAX;
        }
        var threshold = STILL_FRACTION * typicalVariance();
        if (threshold > STILL_MAX) {
            return STILL_MAX;
        }
        return threshold < STILL_FLOOR ? STILL_FLOOR : threshold;
    }
}
