import Toybox.Lang;
import Toybox.Math;

//! Inclinación del reloj a partir de la gravedad.
//!
//! El fr165 no tiene giroscopio: la postura de la muñeca sale de la dirección de la
//! gravedad, que se estima con la media de cada eje en la ventana de 2 s
//! (SlidingWindow.meanX/Y/Z, TelemetrySnapshot.gravityX/Y/Z). El ángulo entre dos de
//! esas medias dice cuánto giró el reloj entre dos momentos; es independiente de la
//! orientación de los ejes, así que vale igual en la muñeca izquierda y en la derecha.
//!
//! Lógica pura: no depende de Sensor, WatchUi ni Graphics.
module Tilt {

    //! Módulo mínimo (mg) de un vector para que su dirección tenga sentido. Con la
    //! ventana vacía la media es (0, 0, 0) y el ángulo no está definido.
    const MIN_NORM = 100.0f;

    //! Ángulo entre los vectores a y b, en grados (0–180). 0 si alguno mide menos de
    //! MIN_NORM.
    function angleDegrees(ax as Float, ay as Float, az as Float,
            bx as Float, by as Float, bz as Float) as Float {
        var normA = Math.sqrt(ax * ax + ay * ay + az * az);
        var normB = Math.sqrt(bx * bx + by * by + bz * bz);
        if (normA < MIN_NORM || normB < MIN_NORM) {
            return 0.0f;
        }
        var cos = (ax * bx + ay * by + az * bz) / (normA * normB);
        // El redondeo puede dejar el coseno un poco fuera de [-1, 1].
        if (cos > 1.0f) {
            cos = 1.0f;
        } else if (cos < -1.0f) {
            cos = -1.0f;
        }
        return (Math.toDegrees(Math.acos(cos))).toFloat();
    }

    //! Ángulo entre la gravedad de dos snapshots (grados).
    function between(a as TelemetrySnapshot, b as TelemetrySnapshot) as Float {
        return angleDegrees(a.gravityX, a.gravityY, a.gravityZ, b.gravityX, b.gravityY, b.gravityZ);
    }
}
