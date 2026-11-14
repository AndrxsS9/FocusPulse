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
//!        ▲                              │
//!        └──── dismiss (respuesta) ─────┤  → AlertOutcome.DISMISSED, tiempo de respuesta
//!        └──── cancel (pausa) ──────────┘  → AlertOutcome.CANCELLED, sin respuesta
//!
//! - Un evento del detector (CABECEO o INACTIVIDAD) abre la alerta en el nivel
//!   EVENT_LEVEL (1). El escalamiento entre niveles es de la fase siguiente; los
//!   niveles 2 y 3 solo se abren con trigger (menú de depuración).
//! - Mientras hay una alerta activa se ignoran los eventos nuevos (y los trigger): la
//!   alerta en curso no cambia de motivo ni de hora de inicio.
//! - dismiss(tiempo) devuelve el tiempo de respuesta y deja la alerta inactiva.
//! - cancel() la cierra sin respuesta (pausar la guardia con la alerta abierta).
//!
//! El tiempo entra como parámetro (ms, System.getTimer() en la app). Lógica pura: no
//! depende de WatchUi, Graphics ni Attention.
class AlertController {

    //! Nivel con el que abre la alerta un evento del detector.
    static const EVENT_LEVEL = 1;

    private var _active as Boolean = false;
    private var _level as Number = EVENT_LEVEL;
    private var _reason as DrowsinessEvent.Id = DrowsinessEvent.NONE;
    private var _startMs as Number = 0;

    private var _outcome as AlertOutcome.Id = AlertOutcome.NONE;
    private var _lastResponseMs as Number? = null;

    function initialize() {
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
        _reason = reason;
        _startMs = nowMs;
        return true;
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

    //! Nivel de la alerta activa (o de la última, si no hay ninguna activa).
    function level() as Number {
        return _level;
    }

    //! Motivo de la alerta activa (o de la última).
    function reason() as DrowsinessEvent.Id {
        return _reason;
    }

    //! Inicio de la alerta activa (o de la última), en ms.
    function startMs() as Number {
        return _startMs;
    }

    //! Tiempo que lleva abierta la alerta activa (0 si no hay ninguna).
    function elapsedMs(nowMs as Number) as Number {
        if (!_active || nowMs < _startMs) {
            return 0;
        }
        return nowMs - _startMs;
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
