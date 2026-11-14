import Toybox.Lang;

//! Estado del guion automático.
module DemoScriptState {

    enum Id {
        //! Sin guion (nunca empezó o se canceló).
        IDLE = 0,
        //! Recorriendo los pasos.
        RUNNING = 1,
        //! Terminó el último paso.
        FINISHED = 2
    }
}

//! Guion automático del modo demo: una secuencia temporizada para presentar la app sin
//! tocar nada.
//!
//!     paso 1  Movimiento normal       10 s
//!     paso 2  Tecleo activo           10 s
//!     paso 3  Simular cabeceo         espera la alerta y "Estoy despierto"
//!     paso 4  Movimiento normal        8 s
//!     paso 5  Inactividad prolongada  espera la alerta y "Estoy despierto"
//!     fin
//!
//! - Los pasos con duración avanzan con update(): cuentan solo el tiempo sin alerta
//!   abierta (con una alerta abierta el guion se congela).
//! - Los pasos de espera avanzan cuando se responde una alerta que se abrió durante ese
//!   paso (onAlertOpened y luego onAlertDismissed). Si nadie responde, el guion espera:
//!   no avanza solo.
//! - cancel() lo detiene en cualquier punto (menú, pausa de la guardia, DOWN, apagar el
//!   modo demo).
//!
//! Quien lo usa aplica scenario() a la fuente simulada cada vez que un método devuelve
//! true (cambió el paso). El tiempo entra como parámetro (ms). Lógica pura: no depende
//! de WatchUi, Graphics ni Timer.
class DemoScript {

    //! Duración que marca un paso de espera (no termina por tiempo).
    static const WAIT_FOR_ALERT = -1;

    //! Pasos: escenario y duración (ms) o WAIT_FOR_ALERT.
    static const STEP_SCENARIOS = [
        AccelScenario.NORMAL,
        AccelScenario.TYPING,
        AccelScenario.NOD,
        AccelScenario.NORMAL,
        AccelScenario.INACTIVITY
    ];
    static const STEP_DURATIONS_MS = [10000, 10000, WAIT_FOR_ALERT, 8000, WAIT_FOR_ALERT];

    //! Número de pasos.
    static const STEP_COUNT = 5;

    private var _state as DemoScriptState.Id = DemoScriptState.IDLE;

    //! Paso actual (0..STEP_COUNT-1) mientras corre.
    private var _step as Number = 0;

    //! Tiempo contado en el paso actual (ms, sin las alertas) y último instante visto.
    private var _elapsedMs as Number = 0;
    private var _lastMs as Number = 0;

    //! true si en el paso de espera actual ya se abrió una alerta.
    private var _alertSeen as Boolean = false;

    function initialize() {
    }

    //! Empieza (o vuelve a empezar) desde el paso 1 en nowMs.
    function start(nowMs as Number) as Void {
        _state = DemoScriptState.RUNNING;
        enterStep(0, nowMs);
    }

    //! Detiene el guion. Devuelve true si estaba corriendo.
    function cancel() as Boolean {
        var wasRunning = isRunning();
        _state = DemoScriptState.IDLE;
        _step = 0;
        _alertSeen = false;
        return wasRunning;
    }

    //! Avanza el reloj hasta nowMs. alertActive: hay una alerta abierta (el tiempo no
    //! cuenta). Devuelve true si cambió de paso o terminó.
    function update(nowMs as Number, alertActive as Boolean) as Boolean {
        if (!isRunning()) {
            return false;
        }
        var dt = nowMs - _lastMs;
        _lastMs = nowMs;
        var duration = durationMs(_step);
        if (alertActive || dt <= 0 || duration == WAIT_FOR_ALERT) {
            return false;
        }
        _elapsedMs += dt;
        if (_elapsedMs < duration) {
            return false;
        }
        advance(nowMs);
        return true;
    }

    //! Se abrió una alerta. En un paso de espera la anota para avanzar al responderla.
    function onAlertOpened() as Void {
        if (isRunning() && isWaitingForAlert()) {
            _alertSeen = true;
        }
    }

    //! Se respondió "Estoy despierto" en nowMs. Devuelve true si eso termina el paso de
    //! espera actual (y el guion pasa al siguiente o termina).
    function onAlertDismissed(nowMs as Number) as Boolean {
        if (!isRunning() || !isWaitingForAlert() || !_alertSeen) {
            return false;
        }
        advance(nowMs);
        return true;
    }

    // --- Lectura ----------------------------------------------------------------

    function state() as DemoScriptState.Id {
        return _state;
    }

    function isRunning() as Boolean {
        return _state == DemoScriptState.RUNNING;
    }

    function isFinished() as Boolean {
        return _state == DemoScriptState.FINISHED;
    }

    //! Paso actual, desde 1 (0 si no corre).
    function stepNumber() as Number {
        return isRunning() ? _step + 1 : 0;
    }

    function stepCount() as Number {
        return STEP_COUNT;
    }

    //! Escenario del paso actual; movimiento normal si no corre (también al terminar).
    function scenario() as AccelScenario.Id {
        if (!isRunning()) {
            return AccelScenario.NORMAL;
        }
        return (STEP_SCENARIOS as Array<AccelScenario.Id>)[_step];
    }

    //! true si el paso actual espera una alerta y su respuesta.
    function isWaitingForAlert() as Boolean {
        return isRunning() && durationMs(_step) == WAIT_FOR_ALERT;
    }

    //! true si el paso de espera actual ya abrió su alerta y falta la respuesta.
    function isAlertPending() as Boolean {
        return isWaitingForAlert() && _alertSeen;
    }

    //! Milisegundos que faltan del paso con duración (0 en los de espera o sin guion).
    function remainingMs() as Number {
        if (!isRunning()) {
            return 0;
        }
        var duration = durationMs(_step);
        if (duration == WAIT_FOR_ALERT) {
            return 0;
        }
        var left = duration - _elapsedMs;
        return left > 0 ? left : 0;
    }

    //! Duración del paso index (ms) o WAIT_FOR_ALERT.
    static function durationMs(index as Number) as Number {
        return (STEP_DURATIONS_MS as Array<Number>)[index];
    }

    // --- Pasos ------------------------------------------------------------------

    private function advance(nowMs as Number) as Void {
        if (_step + 1 >= STEP_COUNT) {
            _state = DemoScriptState.FINISHED;
            _step = 0;
            _alertSeen = false;
            return;
        }
        enterStep(_step + 1, nowMs);
    }

    private function enterStep(index as Number, nowMs as Number) as Void {
        _step = index;
        _elapsedMs = 0;
        _lastMs = nowMs;
        _alertSeen = false;
    }
}
