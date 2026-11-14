import Toybox.Lang;

//! Cuenta regresiva del descanso guiado: 15 min con el sensor real y 30 s en modo demo.
//!
//!     inactivo ──start──► en marcha ──(duración)──► terminado
//!        ▲                    │                         │
//!        └────── cancel ──────┴─────────────────────────┘
//!
//! - remainingMs y progress (fracción que queda, de 1 a 0) alimentan el anillo que se
//!   vacía y el reloj "14:59" de la vista.
//! - update(ahora) devuelve true **una sola vez**, en el instante en que termina: ahí la
//!   app vibra suave y el predictor de fatiga empieza a contar de nuevo.
//!
//! El tiempo entra como parámetro (ms). Lógica pura: sin WatchUi, Graphics ni Timer.
class BreakTimer {

    //! Duración del descanso (ms).
    static const DURATION_MS = 900000;
    static const DURATION_DEMO_MS = 30000;

    private var _running as Boolean = false;
    private var _finished as Boolean = false;
    private var _startMs as Number = 0;
    private var _durationMs as Number = DURATION_MS;

    function initialize() {
    }

    //! Duración del modo: 15 min, o 30 s en modo demo.
    static function durationMsFor(demo as Boolean) as Number {
        return demo ? DURATION_DEMO_MS : DURATION_MS;
    }

    //! Empieza (o reinicia) un descanso de durationMs desde nowMs.
    function start(nowMs as Number, durationMs as Number) as Void {
        _running = true;
        _finished = false;
        _startMs = nowMs;
        _durationMs = durationMs > 0 ? durationMs : DURATION_MS;
    }

    //! Detiene el descanso (BACK, o "Reanudar guardia" al terminar).
    function cancel() as Void {
        _running = false;
        _finished = false;
    }

    //! Avanza hasta nowMs. Devuelve true solo en la llamada en que el descanso termina.
    function update(nowMs as Number) as Boolean {
        if (!_running || _finished) {
            return false;
        }
        if (nowMs - _startMs >= _durationMs) {
            _finished = true;
            return true;
        }
        return false;
    }

    //! true desde start() hasta cancel(), también ya terminado.
    function isRunning() as Boolean {
        return _running;
    }

    //! true si llegó a cero (y no se canceló después).
    function isFinished() as Boolean {
        return _running && _finished;
    }

    function durationMs() as Number {
        return _durationMs;
    }

    //! Milisegundos que faltan (0 al terminar o sin descanso).
    function remainingMs(nowMs as Number) as Number {
        if (!_running || _finished) {
            return 0;
        }
        var left = _durationMs - (nowMs - _startMs);
        if (left < 0) {
            return 0;
        }
        return left > _durationMs ? _durationMs : left;
    }

    //! Fracción que queda, de 1.0 (recién empezado) a 0.0 (terminado).
    function progress(nowMs as Number) as Float {
        if (!_running) {
            return 0.0f;
        }
        return remainingMs(nowMs).toFloat() / _durationMs;
    }

    //! Segundos que faltan, redondeados hacia arriba: el reloj marca 15:00 al empezar y
    //! 0:01 durante el último segundo, nunca 0:00 antes de terminar.
    function remainingSeconds(nowMs as Number) as Number {
        return (remainingMs(nowMs) + 999) / 1000;
    }
}
