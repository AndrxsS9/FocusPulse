import Toybox.Lang;
import Toybox.Math;

//! Clases del estado del usuario.
module DrowsinessClass {

    enum Id {
        //! Actividad alta: tecleo, gestos.
        ACTIVE = 0,
        //! Movimiento normal de alguien despierto.
        NORMAL = 1,
        //! Cabeceo: caída brusca del brazo y quietud.
        NOD = 2,
        //! Inerte: brazo inmóvil un buen rato.
        INERT = 3
    }

    const COUNT = 4;
}

//! Clasificador de estado v1: regresión logística multiclase (softmax) sobre cinco
//! características de cada lote, con los pesos de ClassifierWeights.
//!
//! | # | Característica | Fuente |
//! |---|---|---|
//! | 0 | ln(varianza + 1) de la ventana de 2 s | TelemetrySnapshot.variance |
//! | 1 | Sacudida máxima del lote (mg) | TelemetrySnapshot.batchPeakJerk |
//! | 2 | Segundos de quietud, con tope de STILL_CAP_S | DrowsinessDetector.stillSeconds |
//! | 3 | Cambio de inclinación (grados), con tope de TILT_CAP_DEG | DrowsinessDetector.tiltDegrees |
//! | 4 | Caída pendiente (0 o 1) | DrowsinessDetector.isFallPending |
//!
//! Las probabilidades crudas se suavizan con una EMA de peso SMOOTHING por lote, para
//! que una ventana suelta no haga saltar el orbe ni el puntaje. Al empezar se supone
//! Normal con probabilidad 1.
//!
//! Lógica pura: no depende de Sensor, WatchUi ni Graphics.
class StateClassifier {

    //! Índices de las características (columnas de ClassifierWeights).
    static const FEATURE_LOG_VARIANCE = 0;
    static const FEATURE_PEAK_JERK = 1;
    static const FEATURE_STILL = 2;
    static const FEATURE_TILT = 3;
    static const FEATURE_FALL_PENDING = 4;
    static const FEATURE_COUNT = 5;

    //! Topes de la quietud (s) y de la inclinación (grados).
    static const STILL_CAP_S = 30.0f;
    static const TILT_CAP_DEG = 90.0f;

    //! Peso de la probabilidad nueva en la EMA (0–1): con 0,6 la clase nueva domina al
    //! segundo lote.
    static const SMOOTHING = 0.6f;

    private var _probabilities as Array<Float>;
    private var _raw as Array<Float>;
    private var _features as Array<Float>;
    private var _ready as Boolean = false;

    function initialize() {
        _probabilities = new Array<Float>[DrowsinessClass.COUNT];
        _raw = new Array<Float>[DrowsinessClass.COUNT];
        _features = new Array<Float>[FEATURE_COUNT];
        reset();
    }

    //! Vuelve a la suposición inicial (Normal) al iniciar o pausar la guardia.
    function reset() as Void {
        for (var k = 0; k < DrowsinessClass.COUNT; k++) {
            _probabilities[k] = k == DrowsinessClass.NORMAL ? 1.0f : 0.0f;
            _raw[k] = _probabilities[k];
        }
        for (var j = 0; j < FEATURE_COUNT; j++) {
            _features[j] = 0.0f;
        }
        _ready = false;
    }

    //! Clasifica el lote. Sin la ventana llena no cambia nada.
    function update(snapshot as TelemetrySnapshot, detector as DrowsinessDetector) as DrowsinessClass.Id {
        if (!snapshot.windowFull) {
            return topClass();
        }
        featuresInto(_features, snapshot.variance, snapshot.batchPeakJerk, detector.stillSeconds(),
            detector.tiltDegrees(), detector.isFallPending());
        probabilitiesInto(_raw, _features);
        for (var k = 0; k < DrowsinessClass.COUNT; k++) {
            _probabilities[k] = SMOOTHING * _raw[k] + (1.0f - SMOOTHING) * _probabilities[k];
        }
        _ready = true;
        return topClass();
    }

    //! Escribe en out las características sin normalizar.
    static function featuresInto(out as Array<Float>, variance as Float, peakJerk as Number,
            stillSeconds as Float, tiltDegrees as Float, fallPending as Boolean) as Void {
        out[FEATURE_LOG_VARIANCE] = Baseline.logVariance(variance < 0.0f ? 0.0f : variance);
        out[FEATURE_PEAK_JERK] = peakJerk.toFloat();
        out[FEATURE_STILL] = stillSeconds > STILL_CAP_S ? STILL_CAP_S : stillSeconds;
        out[FEATURE_TILT] = tiltDegrees > TILT_CAP_DEG ? TILT_CAP_DEG : tiltDegrees;
        out[FEATURE_FALL_PENDING] = fallPending ? 1.0f : 0.0f;
    }

    //! Escribe en out la softmax de las características (sin suavizar).
    static function probabilitiesInto(out as Array<Float>, features as Array<Float>) as Void {
        var mean = ClassifierWeights.FEATURE_MEAN as Array<Float>;
        var scale = ClassifierWeights.FEATURE_SCALE as Array<Float>;
        var coef = ClassifierWeights.COEF as Array<Array<Float>>;
        var intercept = ClassifierWeights.INTERCEPT as Array<Float>;

        var max = 0.0f;
        for (var k = 0; k < DrowsinessClass.COUNT; k++) {
            var z = intercept[k];
            var row = coef[k];
            for (var j = 0; j < FEATURE_COUNT; j++) {
                z += row[j] * (features[j] - mean[j]) / scale[j];
            }
            out[k] = z;
            if (k == 0 || z > max) {
                max = z;
            }
        }
        // Se resta el máximo para que e^z no se desborde.
        var sum = 0.0f;
        for (var k = 0; k < DrowsinessClass.COUNT; k++) {
            out[k] = Math.pow(Math.E, out[k] - max).toFloat();
            sum += out[k];
        }
        for (var k = 0; k < DrowsinessClass.COUNT; k++) {
            out[k] = out[k] / sum;
        }
    }

    //! Clase con mayor probabilidad suavizada.
    function topClass() as DrowsinessClass.Id {
        var best = 0;
        for (var k = 1; k < DrowsinessClass.COUNT; k++) {
            if (_probabilities[k] > _probabilities[best]) {
                best = k;
            }
        }
        return best as DrowsinessClass.Id;
    }

    //! Probabilidad suavizada de la clase k (0–1).
    function probability(k as DrowsinessClass.Id) as Float {
        return _probabilities[k as Number];
    }

    //! Probabilidades suavizadas, en el orden de DrowsinessClass (no modificar).
    function probabilities() as Array<Float> {
        return _probabilities;
    }

    //! Probabilidades sin suavizar del último lote.
    function rawProbabilities() as Array<Float> {
        return _raw;
    }

    //! Características del último lote (sin normalizar).
    function features() as Array<Float> {
        return _features;
    }

    //! true desde el primer lote con la ventana llena.
    function isReady() as Boolean {
        return _ready;
    }
}
