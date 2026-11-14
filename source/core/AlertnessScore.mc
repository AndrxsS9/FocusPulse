import Toybox.Lang;

//! Puntaje de alerta, de 0 (dormido) a 100 (bien despierto), a partir del clasificador
//! de estado (StateClassifier).
//!
//! Con cada lote, el puntaje se acerca a un objetivo: la media de los niveles de cada
//! clase pesada por sus probabilidades suavizadas,
//!
//!     objetivo = Σ p(clase) × LEVELS[clase]     (Activo 100, Normal 85, Cabeceo 0, Inerte 10)
//!
//! sin moverse más de RISE_PER_S puntos por segundo hacia arriba ni DROP_PER_S hacia
//! abajo. Así una ventana dudosa no lo hace saltar, y el anillo baja de forma gradual
//! cuando el usuario se queda inmóvil (de 85 a la banda ámbar, < 60, en unos 13 s; a la
//! roja, < 35, en unos 25 s).
//!
//! Con un objetivo constante el resultado no depende de cómo se partan los lotes: dos
//! pasos de 1 s dan lo mismo que uno de 2 s. Mientras el clasificador no opina (los
//! primeros 2 s) no cambia.
//!
//! Empieza en INITIAL al iniciar la guardia (reset) y se congela en pausa
//! (setActive(false)).
//!
//! Lógica pura: no depende de Sensor, WatchUi ni Graphics.
class AlertnessScore {

    //! Puntaje al iniciar la guardia.
    static const INITIAL = 88.0f;

    //! Nivel de alerta de cada clase, en el orden de DrowsinessClass.
    static const LEVELS = [100.0f, 85.0f, 0.0f, 10.0f];

    //! Puntos por segundo que puede subir y bajar.
    static const RISE_PER_S = 3.0f;
    static const DROP_PER_S = 2.0f;

    static const MIN = 0.0f;
    static const MAX = 100.0f;

    private var _value as Float = INITIAL;
    private var _active as Boolean = false;

    function initialize() {
    }

    //! Vuelve al valor inicial y activa la actualización (al iniciar la guardia).
    function reset() as Void {
        _value = INITIAL;
        _active = true;
    }

    //! false congela el puntaje (guardia en pausa); true lo reanuda sin reiniciarlo.
    function setActive(active as Boolean) as Void {
        _active = active;
    }

    function isActive() as Boolean {
        return _active;
    }

    //! Objetivo (0–100) para unas probabilidades en el orden de DrowsinessClass.
    static function targetFor(probabilities as Array<Float>) as Float {
        var levels = LEVELS as Array<Float>;
        var target = 0.0f;
        for (var k = 0; k < DrowsinessClass.COUNT; k++) {
            target += probabilities[k] * levels[k];
        }
        return target;
    }

    //! Aplica dtSeconds con las probabilidades del clasificador (null si aún no opina)
    //! y devuelve el puntaje (0–100, entero).
    function update(probabilities as Array<Float>?, dtSeconds as Float) as Number {
        if (!_active || dtSeconds <= 0.0f || probabilities == null) {
            return value();
        }
        var distance = targetFor(probabilities) - _value;
        var up = RISE_PER_S * dtSeconds;
        var down = DROP_PER_S * dtSeconds;
        if (distance > up) {
            _value += up;
        } else if (distance < -down) {
            _value -= down;
        } else {
            _value += distance;
        }

        if (_value < MIN) {
            _value = MIN;
        } else if (_value > MAX) {
            _value = MAX;
        }
        return value();
    }

    //! Sube el puntaje hasta minimum si está por debajo (nunca lo baja). Se usa al
    //! descartar una alerta: quien acaba de confirmar que está despierto vuelve, como
    //! mínimo, a la banda alta. Funciona también en pausa.
    function raiseTo(minimum as Float) as Number {
        var floor = minimum > MAX ? MAX : minimum;
        if (_value < floor) {
            _value = floor;
        }
        return value();
    }

    //! Puntaje actual redondeado (0–100).
    function value() as Number {
        return (_value + 0.5f).toNumber();
    }

    //! Puntaje actual sin redondear (para las pruebas).
    function exactValue() as Float {
        return _value;
    }
}
