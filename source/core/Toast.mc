import Toybox.Lang;

//! Tipo de aviso breve en la esfera. La vista decide el texto según el tipo.
module ToastKind {

    enum Id {
        //! Sin aviso.
        NONE = 0,
        //! Cambio de escenario con DOWN; el valor es el AccelScenario.Id nuevo.
        SCENARIO = 1,
        //! Guardia iniciada con la alerta solo visual (sin vibración ni sonido).
        VISUAL_ONLY = 2
    }
}

//! Aviso breve que se ve DURATION_MS sobre la esfera ("Escenario: Tecleo activo"), o
//! WARNING_DURATION_MS si es un aviso de seguridad ("Alerta solo visual").
//!
//! Guarda solo el tipo, un valor y el instante en que se mostró; la vista pone el texto
//! localizado. Un aviso nuevo reemplaza al anterior y vuelve a contar desde cero. El
//! tiempo entra como parámetro (ms, System.getTimer() en la app). Lógica pura: no
//! depende de WatchUi ni Graphics.
class Toast {

    //! Tiempo visible (ms).
    static const DURATION_MS = 1500;

    //! Los avisos de seguridad se quedan más, para que dé tiempo a leerlos.
    static const WARNING_DURATION_MS = 3000;

    //! Tiempo visible (ms) de un aviso de ese tipo.
    static function durationMs(kind as ToastKind.Id) as Number {
        return kind == ToastKind.VISUAL_ONLY ? WARNING_DURATION_MS : DURATION_MS;
    }

    private var _kind as ToastKind.Id = ToastKind.NONE;
    private var _value as Number = 0;
    private var _shownAtMs as Number = 0;

    function initialize() {
    }

    //! Muestra un aviso desde nowMs.
    function show(kind as ToastKind.Id, value as Number, nowMs as Number) as Void {
        _kind = kind;
        _value = value;
        _shownAtMs = nowMs;
    }

    //! Quita el aviso antes de tiempo.
    function hide() as Void {
        _kind = ToastKind.NONE;
    }

    //! true durante durationMs(tipo) desde show(), y nunca antes de ese instante.
    function isVisible(nowMs as Number) as Boolean {
        if (_kind == ToastKind.NONE) {
            return false;
        }
        var elapsed = nowMs - _shownAtMs;
        return elapsed >= 0 && elapsed < durationMs(_kind);
    }

    function kind() as ToastKind.Id {
        return _kind;
    }

    function value() as Number {
        return _value;
    }
}
