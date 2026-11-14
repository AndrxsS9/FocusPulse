import Toybox.Lang;

//! Cómo terminó la última alerta.
module AlertOutcome {

    enum Id {
        //! Aún no terminó ninguna alerta.
        NONE = 0,
        //! El usuario confirmó que está despierto (con tiempo de respuesta).
        DISMISSED = 1,
        //! Se cerró sin respuesta: la guardia se pausó o la app se cerró.
        CANCELLED = 2
    }
}

//! Máquina de estados de la alerta a pantalla completa:
//!
//!     inactiva ──evento / trigger──► activa (nivel 1–3, motivo, inicio)
//!        ▲                              │  update: sin respuesta, sube un nivel
//!        │                              │  cada escalationMs (1 → 2 → 3; el 3 se queda)
//!        └──── dismiss (respuesta) ─────┤  → AlertOutcome.DISMISSED, tiempo de respuesta
//!        └──── cancel (pausa) ──────────┘  → AlertOutcome.CANCELLED, sin respuesta
//!
//! - Un evento del detector (CABECEO o INACTIVIDAD) abre la alerta en el nivel
//!   EVENT_LEVEL (1); trigger ("Probar alerta") puede abrirla en cualquier nivel.
//! - **Escalamiento**: si nadie responde, update(ahora) sube un nivel cada
//!   escalationMs desde que empezó el nivel actual: ESCALATION_MS (10 s) con el sensor
//!   real y ESCALATION_DEMO_MS (6 s) en modo demo, para que se vea en la sustentación.
//!   Una alerta de nivel 1 llega al 2 a los 10 s y al 3 a los 20 s. El nivel 3 se
//!   mantiene hasta la respuesta. Si update llega tarde (p. ej. 25 s después), sube
//!   todos los niveles pendientes de una vez y cada nivel conserva su hora teórica.
//! - Los niveles solo suben, así que level() es también el nivel máximo alcanzado: el
//!   que se guarda junto al tiempo de respuesta.
//! - Mientras hay una alerta activa se ignoran los eventos nuevos (y los trigger): la
//!   alerta en curso no cambia de motivo ni de hora de inicio.
//! - dismiss(tiempo) devuelve el tiempo de respuesta (desde que se abrió la alerta, no
//!   desde el nivel actual) y deja la alerta inactiva: el escalamiento se detiene.
//! - cancel() la cierra sin respuesta (pausar la guardia con la alerta abierta).
//!
//! El tiempo entra como parámetro (ms, System.getTimer() en la app). Lógica pura: no
//! depende de WatchUi, Graphics ni Attention.
class AlertController {

    //! Nivel con el que abre la alerta un evento del detector.
    static const EVENT_LEVEL = 1;

    //! Tiempo sin respuesta en un nivel antes de subir al siguiente (ms).
    static const ESCALATION_MS = 10000;
    static const ESCALATION_DEMO_MS = 6000;

    private var _active as Boolean = false;
    private var _level as Number = EVENT_LEVEL;
    private var _startLevel as Number = EVENT_LEVEL;
    private var _reason as DrowsinessEvent.Id = DrowsinessEvent.NONE;
    private var _startMs as Number = 0;
    private var _levelStartMs as Number = 0;
    private var _escalationMs as Number = ESCALATION_MS;

    private var _outcome as AlertOutcome.Id = AlertOutcome.NONE;
    private var _lastResponseMs as Number? = null;

    function initialize() {
    }

    //! Tiempo de escalamiento del modo: 10 s con el sensor real, 6 s en modo demo.
    static function escalationMsFor(demo as Boolean) as Number {
        return demo ? ESCALATION_DEMO_MS : ESCALATION_MS;
    }

    //! Cambia el tiempo de escalamiento (ms; se ignora si no es positivo). Vale también
    //! para la alerta en curso, contando desde el inicio de su nivel actual.
    function setEscalationMs(ms as Number) as Void {
        if (ms > 0) {
            _escalationMs = ms;
        }
    }

    function escalationMs() as Number {
        return _escalationMs;
    }

    //! Recibe el evento del detector en nowMs. Abre la alerta (nivel EVENT_LEVEL) y
    //! devuelve true si el evento es CABECEO o INACTIVIDAD y no había otra activa.
    function onEvent(event as DrowsinessEvent.Id, nowMs as Number) as Boolean {
        if (event == DrowsinessEvent.NONE) {
            return false;
        }
        return trigger(EVENT_LEVEL, event, nowMs);
    }

    //! Abre una alerta con un nivel concreto (se recorta a 1–3). Devuelve false, sin
    //! cambiar nada, si ya hay una alerta activa.
    function trigger(level as Number, reason as DrowsinessEvent.Id, nowMs as Number) as Boolean {
        if (_active) {
            return false;
        }
        _active = true;
        _level = AlertnessColors.clampAlertLevel(level);
        _startLevel = _level;
        _reason = reason;
        _startMs = nowMs;
        _levelStartMs = nowMs;
        return true;
    }

    //! Avanza el reloj de la alerta hasta nowMs: sube un nivel por cada escalationMs
    //! sin respuesta en el nivel actual, hasta el 3. Devuelve true si el nivel cambió
    //! (hay que cambiar la vibración y lo que muestra la vista).
    function update(nowMs as Number) as Boolean {
        if (!_active) {
            return false;
        }
        var rose = false;
        while (_level < AlertnessColors.MAX_ALERT_LEVEL && nowMs - _levelStartMs >= _escalationMs) {
            _level += 1;
            _levelStartMs += _escalationMs;
            rose = true;
        }
        return rose;
    }

    //! "Estoy despierto": cierra la alerta y devuelve el tiempo de respuesta (ms, nunca
    //! negativo), o null si no había ninguna alerta activa.
    function dismiss(nowMs as Number) as Number? {
        if (!_active) {
            return null;
        }
        var response = nowMs - _startMs;
        if (response < 0) {
            response = 0;
        }
        _active = false;
        _outcome = AlertOutcome.DISMISSED;
        _lastResponseMs = response;
        return response;
    }

    //! Cierra la alerta sin tiempo de respuesta (guardia en pausa). Devuelve true si
    //! había una alerta activa.
    function cancel() as Boolean {
        if (!_active) {
            return false;
        }
        _active = false;
        _outcome = AlertOutcome.CANCELLED;
        _lastResponseMs = null;
        return true;
    }

    function isActive() as Boolean {
        return _active;
    }

    //! Nivel de la alerta activa (o de la última, si no hay ninguna activa). Como los
    //! niveles solo suben, es también el máximo que alcanzó.
    function level() as Number {
        return _level;
    }

    //! Nivel con el que se abrió la alerta activa (o la última).
    function startLevel() as Number {
        return _startLevel;
    }

    //! Motivo de la alerta activa (o de la última).
    function reason() as DrowsinessEvent.Id {
        return _reason;
    }

    //! Inicio de la alerta activa (o de la última), en ms.
    function startMs() as Number {
        return _startMs;
    }

    //! Inicio del nivel actual de la alerta activa (o de la última), en ms.
    function levelStartMs() as Number {
        return _levelStartMs;
    }

    //! Tiempo que lleva abierta la alerta activa (0 si no hay ninguna).
    function elapsedMs(nowMs as Number) as Number {
        if (!_active || nowMs < _startMs) {
            return 0;
        }
        return nowMs - _startMs;
    }

    //! Tiempo en el nivel actual (0 si no hay alerta activa). La vibración vuelve a
    //! empezar con cada nivel, así que la sacudida de la vista se cuenta desde aquí.
    function levelElapsedMs(nowMs as Number) as Number {
        if (!_active || nowMs < _levelStartMs) {
            return 0;
        }
        return nowMs - _levelStartMs;
    }

    //! Milisegundos hasta el siguiente nivel, o -1 si ya está en el 3 o no hay alerta.
    function msToNextLevel(nowMs as Number) as Number {
        if (!_active || _level >= AlertnessColors.MAX_ALERT_LEVEL) {
            return -1;
        }
        var left = _levelStartMs + _escalationMs - nowMs;
        return left > 0 ? left : 0;
    }

    //! Cómo terminó la última alerta.
    function lastOutcome() as AlertOutcome.Id {
        return _outcome;
    }

    //! Tiempo de respuesta de la última alerta descartada (null si se canceló o aún no
    //! hubo ninguna).
    function lastResponseMs() as Number? {
        return _lastResponseMs;
    }
}
