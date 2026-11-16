import Toybox.Lang;

//! Configuración del modo demo: si está activo y qué escenario simula.
//!
//! | | Modo demo | Sin modo demo |
//! |---|---|---|
//! | Fuente | simulada (SimulatedAccelSource) | acelerómetro real |
//! | Calibración de la línea base | 5 s | 30 s |
//! | Inactividad prolongada | 8 s de quietud | 60 s de quietud |
//! | Escalamiento de una alerta sin respuesta | cada 6 s | cada 10 s |
//! | Ventana del predictor de fatiga | 5 min | 30 min |
//! | Descanso guiado | 30 s | 15 min |
//!
//! Los tiempos son los mismos que usan Baseline, DrowsinessDetector y AlertController
//! en cada modo; esta clase es el único sitio donde se decide en qué modo está la
//! guardia.
//!
//! El escenario se recuerda aunque el modo demo esté apagado, para volver a él al
//! encenderlo. Los cinco escenarios de la demo se recorren en orden con
//! nextScenario() (DOWN, deslizar a la izquierda) y hacia atrás con previousScenario()
//! (deslizar a la derecha); MANUAL solo existe en el menú de depuración y no forma parte
//! del ciclo.
//!
//! Persistencia: toStorage() da un diccionario de tipos simples para
//! Application.Storage y fromStorage() lo valida al leerlo (datos ausentes, de otra
//! versión o corruptos dan la configuración por defecto). Lógica pura: no depende de
//! Application, WatchUi ni Graphics.
class DemoConfig {

    //! Escenarios del modo demo, en el orden del menú y del botón DOWN.
    static const SCENARIOS = [
        AccelScenario.NORMAL,
        AccelScenario.TYPING,
        AccelScenario.NOD,
        AccelScenario.INACTIVITY,
        AccelScenario.GLANCE
    ];

    //! Claves del diccionario guardado.
    static const KEY_ENABLED = "enabled";
    static const KEY_SCENARIO = "scenario";

    private var _enabled as Boolean = false;
    private var _scenario as AccelScenario.Id = AccelScenario.NORMAL;

    function initialize() {
    }

    // --- Modo -------------------------------------------------------------------

    function isEnabled() as Boolean {
        return _enabled;
    }

    function setEnabled(enabled as Boolean) as Void {
        _enabled = enabled;
    }

    //! true si la guardia debe leer la fuente simulada en lugar del acelerómetro.
    function usesSimulatedSource() as Boolean {
        return _enabled;
    }

    //! Duración de la calibración de la línea base (ms).
    function calibrationMs() as Number {
        return _enabled ? Baseline.CALIBRATION_DEMO_MS : Baseline.CALIBRATION_MS;
    }

    //! Quietud continua que dispara la inactividad prolongada (ms).
    function inactivityMs() as Number {
        return _enabled ? DrowsinessDetector.INACTIVITY_DEMO_MS : DrowsinessDetector.INACTIVITY_MS;
    }

    //! Tiempo sin respuesta antes de que la alerta suba de nivel (ms).
    function alertEscalationMs() as Number {
        return AlertController.escalationMsFor(_enabled);
    }

    //! Ventana de episodios recientes del predictor de fatiga (ms).
    function fatigueWindowMs() as Number {
        return FatiguePredictor.windowMsFor(_enabled);
    }

    //! Duración del descanso guiado (ms).
    function breakMs() as Number {
        return BreakTimer.durationMsFor(_enabled);
    }

    // --- Escenario --------------------------------------------------------------

    function scenario() as AccelScenario.Id {
        return _scenario;
    }

    //! Fija el escenario. Un valor fuera de rango deja el que había.
    function setScenario(scenario as AccelScenario.Id) as Void {
        if (AccelScenario.isValid(scenario)) {
            _scenario = scenario;
        }
    }

    //! Escenario que sigue a scenario en el ciclo de la demo (el último vuelve al
    //! primero). Desde uno que no está en el ciclo (MANUAL) se va al primero.
    static function scenarioAfter(scenario as AccelScenario.Id) as AccelScenario.Id {
        var list = SCENARIOS as Array<AccelScenario.Id>;
        var index = list.indexOf(scenario);
        return list[(index + 1) % list.size()];
    }

    //! Escenario anterior a scenario en el ciclo de la demo (el primero vuelve al
    //! último). Desde uno que no está en el ciclo (MANUAL) se va al último.
    static function scenarioBefore(scenario as AccelScenario.Id) as AccelScenario.Id {
        var list = SCENARIOS as Array<AccelScenario.Id>;
        var index = list.indexOf(scenario);
        if (index <= 0) {
            return list[list.size() - 1];
        }
        return list[index - 1];
    }

    //! true si DOWN en la esfera debe pasar al siguiente escenario: solo con el modo
    //! demo activo y la guardia en marcha. En otro caso DOWN conserva su función normal.
    function handlesDownButton(guardActive as Boolean) as Boolean {
        return _enabled && guardActive;
    }

    //! true si deslizar a la izquierda o a la derecha en la esfera debe cambiar de
    //! escenario: siempre que el modo demo esté activo, con la guardia en marcha o en
    //! pausa (en pausa elige con qué escenario empezará). Es el control táctil para el
    //! simulador, donde los botones dibujados pueden no responder.
    function handlesSwipe() as Boolean {
        return _enabled;
    }

    //! Pasa al siguiente escenario del ciclo y lo devuelve.
    function nextScenario() as AccelScenario.Id {
        _scenario = scenarioAfter(_scenario);
        return _scenario;
    }

    //! Vuelve al escenario anterior del ciclo y lo devuelve.
    function previousScenario() as AccelScenario.Id {
        _scenario = scenarioBefore(_scenario);
        return _scenario;
    }

    // --- Persistencia -----------------------------------------------------------

    //! Diccionario para guardar en Application.Storage.
    function toStorage() as Dictionary<String, Boolean or Number> {
        return {
            KEY_ENABLED => _enabled,
            KEY_SCENARIO => _scenario as Number
        };
    }

    //! Configuración a partir de lo leído de Storage. Cada campo inválido o ausente toma
    //! su valor por defecto (modo demo apagado, movimiento normal).
    static function fromStorage(data as Object?) as DemoConfig {
        var config = new DemoConfig();
        if (data instanceof Dictionary) {
            var dict = data as Dictionary<String, Object?>;
            var enabled = dict.get(KEY_ENABLED);
            if (enabled instanceof Boolean) {
                config.setEnabled(enabled);
            }
            var scenario = dict.get(KEY_SCENARIO);
            if (AccelScenario.isValid(scenario)) {
                config.setScenario(scenario as AccelScenario.Id);
            }
        }
        return config;
    }
}
