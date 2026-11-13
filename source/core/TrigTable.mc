import Toybox.Lang;
import Toybox.Math;

//! Tabla precalculada de senos con resolución de 1 grado.
//!
//! Math.sin y Math.cos son caros para llamarlos en cada punto de cada cuadro de la
//! animación (3 anillos × 36 puntos × 3 funciones, 12 veces por segundo). La tabla se
//! calcula una vez al crearla (360 llamadas a Math.sin) y después cada consulta es un
//! redondeo y un acceso a un arreglo. Con 1° de resolución, el error en un círculo de
//! 100 px de radio es menor de 1 px.
//!
//! Los ángulos van en grados, de cualquier signo y tamaño.
//! Lógica pura: no depende de WatchUi ni Graphics.
class TrigTable {

    //! Entradas por vuelta (1 por grado).
    static const STEPS = 360;

    private var _sin as Array<Float>;

    function initialize() {
        _sin = new Array<Float>[STEPS];
        for (var i = 0; i < STEPS; i++) {
            _sin[i] = Math.sin(Math.toRadians(i)).toFloat();
        }
    }

    //! Seno de un ángulo en grados, redondeado al grado más cercano.
    function sinDeg(degrees as Float) as Float {
        return _sin[index(degrees)];
    }

    //! Coseno de un ángulo en grados: sin(θ + 90°).
    function cosDeg(degrees as Float) as Float {
        return _sin[index(degrees + 90.0f)];
    }

    //! Grado más cercano normalizado a 0..359.
    private function index(degrees as Float) as Number {
        var rounded = degrees >= 0.0f ? (degrees + 0.5f).toNumber() : (degrees - 0.5f).toNumber();
        var i = rounded % STEPS;
        return i < 0 ? i + STEPS : i;
    }
}
