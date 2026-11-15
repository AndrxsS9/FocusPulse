import Toybox.Lang;

//! Vigila que lleguen lotes del acelerómetro mientras la guardia está activa.
//!
//! - start(nowMs) al iniciar la guardia (o al reanudarla): cuenta desde ese instante,
//!   así que si la fuente nunca entrega datos el aviso sale igual a los TIMEOUT_MS.
//! - onData(nowMs) con cada lote: si estaba sin datos, devuelve true (los datos
//!   volvieron) y quien llama descarta la ventana y la quietud de antes del corte.
//! - check(nowMs) periódicamente (timer de la esfera, de la alerta): devuelve true solo
//!   en el instante en que pasa a "sin datos" (para registrarlo una vez).
//! - stop() al pausar: deja de vigilar y quita el aviso.
//!
//! Más de TIMEOUT_MS sin lotes es "sin datos": la fuente real entrega uno por segundo,
//! así que 5 s son 5 lotes perdidos seguidos. Mientras dura, el detector no recibe nada
//! (no puede emitir eventos) y, al volver los datos, la quietud vuelve a contar desde
//! cero: un corte no se toma por inactividad prolongada.
//!
//! El tiempo entra como parámetro (ms, System.getTimer() en la app). Lógica pura: no
//! depende de Sensor, WatchUi ni Graphics.
class SensorWatchdog {

    //! Tiempo máximo (ms) sin lotes antes de avisar.
    static const TIMEOUT_MS = 5000;

    private var _running as Boolean = false;
    private var _lastDataMs as Number = 0;
    private var _stale as Boolean = false;

    //! Veces que pasó a "sin datos" desde start().
    private var _staleCount as Number = 0;

    function initialize() {
    }

    //! Empieza a vigilar desde nowMs, sin aviso.
    function start(nowMs as Number) as Void {
        _running = true;
        _lastDataMs = nowMs;
        _stale = false;
        _staleCount = 0;
    }

    //! Deja de vigilar (guardia en pausa o en descanso) y quita el aviso.
    function stop() as Void {
        _running = false;
        _stale = false;
    }

    //! Llegó un lote en nowMs. Devuelve true si estaba sin datos: los datos volvieron
    //! y el aviso se quita.
    function onData(nowMs as Number) as Boolean {
        if (!_running) {
            return false;
        }
        var recovered = _stale || nowMs - _lastDataMs > TIMEOUT_MS;
        _lastDataMs = nowMs;
        _stale = false;
        return recovered;
    }

    //! Revisa el tiempo sin lotes. Devuelve true solo cuando pasa a "sin datos".
    function check(nowMs as Number) as Boolean {
        if (!_running || _stale) {
            return false;
        }
        if (nowMs - _lastDataMs > TIMEOUT_MS) {
            _stale = true;
            _staleCount += 1;
            return true;
        }
        return false;
    }

    //! true mientras no llegan lotes (después del último check()).
    function isStale() as Boolean {
        return _stale;
    }

    function isRunning() as Boolean {
        return _running;
    }

    //! Tiempo (ms) desde el último lote o desde start(); 0 si no vigila.
    function silenceMs(nowMs as Number) as Number {
        return _running ? nowMs - _lastDataMs : 0;
    }

    function staleCount() as Number {
        return _staleCount;
    }
}
