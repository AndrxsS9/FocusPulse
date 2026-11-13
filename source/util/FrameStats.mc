import Toybox.Lang;

//! Medición de la animación: cuadros por segundo reales y tiempo de dibujo por cuadro.
//!
//! La vista llama a frame(inicio, fin) con System.getTimer() antes y después de dibujar.
//! Cada WINDOW_MS se cierra una ventana con los cuadros dibujados, la media y el máximo
//! del tiempo de dibujo; frame() devuelve true justo al cerrarla. Sin dependencias de
//! Graphics: se prueba con tiempos inventados.
class FrameStats {

    //! Duración de cada ventana de medición (ms).
    static const WINDOW_MS = 5000;

    private var _windowStart as Number? = null;
    private var _frames as Number = 0;
    private var _drawTotal as Number = 0;
    private var _drawMax as Number = 0;

    //! Resultado de la última ventana cerrada.
    var fps as Float = 0.0f;
    var drawAvgMs as Float = 0.0f;
    var drawMaxMs as Number = 0;
    var frames as Number = 0;

    function initialize() {
    }

    //! Registra un cuadro dibujado entre startMs y endMs. Devuelve true si con él se
    //! cerró una ventana (los campos públicos tienen entonces su resultado).
    function frame(startMs as Number, endMs as Number) as Boolean {
        var windowStart = _windowStart;
        if (windowStart == null) {
            _windowStart = startMs;
            windowStart = startMs;
        }
        var draw = endMs - startMs;
        _frames += 1;
        _drawTotal += draw;
        if (draw > _drawMax) {
            _drawMax = draw;
        }

        var elapsed = endMs - windowStart;
        if (elapsed < WINDOW_MS) {
            return false;
        }
        frames = _frames;
        fps = _frames * 1000.0f / elapsed;
        drawAvgMs = _drawTotal.toFloat() / _frames;
        drawMaxMs = _drawMax;
        reset();
        return true;
    }

    //! Empieza una ventana nueva (p. ej. al cambiar la tasa de refresco).
    function reset() as Void {
        _windowStart = null;
        _frames = 0;
        _drawTotal = 0;
        _drawMax = 0;
    }
}
