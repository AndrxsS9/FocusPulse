import Toybox.Lang;

//! Motor de telemetría: recibe lotes del acelerómetro, alimenta la ventana deslizante
//! y expone un TelemetrySnapshot.
//!
//! Lo usan igual la fuente real y la simulada: ambas entregan lotes con el mismo
//! formato (arreglos x, y, z en mg y la marca de tiempo del lote en ms).
//!
//! **Tiempo.** `timestampMs` es el instante de la última muestra del lote (p. ej.
//! `System.getTimer()` al recibirlo); entra como parámetro para poder probarlo sin
//! reloj. El instante de cada muestra se reparte hacia atrás con el periodo medido
//! entre lotes; en el primer lote se usa el nominal (1000 / SAMPLE_RATE_HZ ms).
//!
//! **Frecuencia efectiva.** Muestras recibidas después del primer lote divididas
//! por el tiempo transcurrido desde él. Detecta, por ejemplo, la bajada a 10 Hz
//! cuando la app pasa a segundo plano sin grabar actividad.
//!
//! Lógica pura: no depende de Sensor, WatchUi ni Graphics.
class TelemetryEngine {

    private var _window as SlidingWindow;

    private var _samplesReceived as Number = 0;
    private var _batchesReceived as Number = 0;
    private var _batchPeakJerk as Number = 0;

    //! Marca de tiempo y tamaño del primer lote, y marca del último.
    private var _firstBatchMs as Number = 0;
    private var _firstBatchSamples as Number = 0;
    private var _lastBatchMs as Number = 0;

    function initialize() {
        _window = new SlidingWindow();
    }

    //! Procesa un lote de muestras. Si los arreglos tienen distinto tamaño se usa
    //! el menor; un lote vacío se ignora.
    function addBatch(xs as Array<Number>, ys as Array<Number>, zs as Array<Number>,
            timestampMs as Number) as Void {
        var n = xs.size();
        if (ys.size() < n) {
            n = ys.size();
        }
        if (zs.size() < n) {
            n = zs.size();
        }
        if (n == 0) {
            return;
        }

        var periodMs = 1000.0f / SlidingWindow.SAMPLE_RATE_HZ;
        if (_batchesReceived > 0 && timestampMs > _lastBatchMs) {
            periodMs = (timestampMs - _lastBatchMs).toFloat() / n;
        }

        var peak = 0;
        for (var i = 0; i < n; i++) {
            var hadSamples = _window.count() > 0;
            var t = timestampMs - ((n - 1 - i) * periodMs + 0.5f).toNumber();
            _window.push(xs[i], ys[i], zs[i], t);
            if (hadSamples && _window.lastDelta() > peak) {
                peak = _window.lastDelta();
            }
        }
        _batchPeakJerk = peak;

        if (_batchesReceived == 0) {
            _firstBatchMs = timestampMs;
            _firstBatchSamples = n;
        }
        _batchesReceived += 1;
        _samplesReceived += n;
        _lastBatchMs = timestampMs;
    }

    //! Frecuencia efectiva (Hz). 0 con menos de dos lotes.
    function effectiveHz() as Float {
        var elapsed = _lastBatchMs - _firstBatchMs;
        if (_batchesReceived < 2 || elapsed <= 0) {
            return 0.0f;
        }
        return (_samplesReceived - _firstBatchSamples) * 1000.0f / elapsed;
    }

    function samplesReceived() as Number {
        return _samplesReceived;
    }

    function batchesReceived() as Number {
        return _batchesReceived;
    }

    //! Ventana con las características (solo lectura para el detector de fases futuras).
    function window() as SlidingWindow {
        return _window;
    }

    //! Olvida todas las muestras: al iniciar una guardia o cambiar de fuente.
    function reset() as Void {
        _window.reset();
        _samplesReceived = 0;
        _batchesReceived = 0;
        _batchPeakJerk = 0;
        _firstBatchMs = 0;
        _firstBatchSamples = 0;
        _lastBatchMs = 0;
    }

    //! Características actuales en un objeto nuevo.
    function snapshot() as TelemetrySnapshot {
        var s = new TelemetrySnapshot();
        s.x = _window.lastX();
        s.y = _window.lastY();
        s.z = _window.lastZ();
        s.meanMagnitude = _window.mean();
        s.variance = _window.variance();
        s.jerk = _window.jerk();
        s.batchPeakJerk = _batchPeakJerk;
        s.stillSeconds = _window.stillSeconds();
        s.isStill = _window.isStill();
        s.windowFull = _window.isFull();
        s.samplesReceived = _samplesReceived;
        s.batchesReceived = _batchesReceived;
        s.effectiveHz = effectiveHz();
        return s;
    }
}
