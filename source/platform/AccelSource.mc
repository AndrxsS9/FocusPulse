import Toybox.Lang;

//! Callback de lote del acelerómetro: ejes en mg y marca de tiempo (ms) de la última
//! muestra del lote. Es el mismo formato que recibe TelemetryEngine.addBatch().
typedef AccelBatchListener as Method(xs as Array<Number>, ys as Array<Number>, zs as Array<Number>,
    timestampMs as Number) as Void;

//! Interfaz común de las fuentes de muestras del acelerómetro.
//!
//! Monkey C no tiene interfaces, así que es una clase base: las fuentes concretas
//! (RealAccelSource, SimulatedAccelSource) sobrescriben start(), stop() e
//! isSimulated(), y entregan cada lote con deliver(). El resto de la app solo conoce
//! esta clase, así que cambiar de fuente no toca el motor ni las vistas.
class AccelSource {

    //! Quien recibe los lotes (normalmente el controlador de la guardia).
    protected var _listener as AccelBatchListener? = null;

    //! true entre un start() correcto y stop().
    protected var _running as Boolean = false;

    function initialize() {
    }

    //! Fija el callback de lote. null deja de entregar lotes sin parar la fuente.
    function setListener(listener as AccelBatchListener?) as Void {
        _listener = listener;
    }

    //! Empieza a entregar lotes. Devuelve false si la fuente no está disponible;
    //! nunca lanza excepciones. Llamarla con la fuente en marcha no hace nada.
    function start() as Boolean {
        return false;
    }

    //! Deja de entregar lotes y libera el sensor o el temporizador. Es seguro llamarla
    //! aunque la fuente no esté en marcha.
    function stop() as Void {
        _running = false;
    }

    function isRunning() as Boolean {
        return _running;
    }

    //! true si los datos son sintéticos (modo demo / depuración).
    function isSimulated() as Boolean {
        return false;
    }

    //! Frecuencia nominal pedida (Hz).
    function sampleRateHz() as Number {
        return SlidingWindow.SAMPLE_RATE_HZ;
    }

    //! Entrega un lote al callback, si hay uno.
    protected function deliver(xs as Array<Number>, ys as Array<Number>, zs as Array<Number>,
            timestampMs as Number) as Void {
        var listener = _listener;
        if (listener != null) {
            listener.invoke(xs, ys, zs, timestampMs);
        }
    }
}
