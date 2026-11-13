import Toybox.Lang;

//! Modelo del orbe IA que se dibuja detrás de la hora: 3 anillos delgados de forma
//! orgánica que giran a velocidades distintas (uno en sentido contrario) y se deforman
//! suavemente.
//!
//! Cada anillo es una curva cerrada en coordenadas polares:
//!
//!     r(θ) = R · (1 + a1·sin(2θ + φ1) + a2·sin(3θ + φ2))
//!
//! muestreada en POINTS ángulos θ, girada `rotación` grados. R, a1 y a2 son propios de
//! cada anillo (deformación a1 + a2 entre el 5 y el 8 %) y R·(1 + a1 + a2) ≤ 1, así que
//! ningún punto sale del radio del orbe. La rotación y las fases φ1, φ2 avanzan con el
//! tiempo de animación, que entra como parámetro (dt): el modelo no lee el reloj.
//!
//! Usa TrigTable: ni una llamada a Math.sin por cuadro.
//! Lógica pura: no depende de WatchUi ni Graphics.
class OrbModel {

    //! Puntos por anillo.
    static const POINTS = 36;

    //! Número de anillos (exterior → interior).
    static const RINGS = 3;

    //! Radio base R de cada anillo, en milésimas del radio del orbe.
    static const RING_RADIUS = [920, 770, 620];

    //! Amplitudes de las deformaciones de orden 2 y 3, en milésimas.
    static const RING_A1 = [50, 30, 30];
    static const RING_A2 = [30, 30, 20];

    //! Velocidad de giro (grados por segundo de animación). El anillo medio gira al revés.
    static const RING_SPIN = [24, -36, 16];

    //! Velocidades de las fases φ1 y φ2 (grados por segundo): la deformación "respira".
    static const RING_PHASE1_SPEED = [40, 55, 30];
    static const RING_PHASE2_SPEED = [-30, 25, -45];

    //! Ángulo inicial de cada anillo, para que no empiecen alineados.
    static const RING_OFFSET = [0, 120, 240];

    private var _trig as TrigTable;

    //! Segundos de animación transcurridos.
    protected var _time as Float = 0.0f;

    function initialize() {
        _trig = new TrigTable();
    }

    //! Tabla de senos compartida (para quien dibuja partículas o arcos).
    function trig() as TrigTable {
        return _trig;
    }

    //! Avanza la animación dt segundos.
    function advance(dt as Float) as Void {
        if (dt > 0.0f) {
            _time += dt;
        }
    }

    //! Segundos de animación transcurridos.
    function time() as Float {
        return _time;
    }

    //! Rotación actual del anillo (grados).
    function ringRotation(ring as Number) as Float {
        return (RING_OFFSET as Array<Number>)[ring] + (RING_SPIN as Array<Number>)[ring] * _time;
    }

    //! Escribe en xs, ys (tamaño POINTS) los puntos del anillo en coordenadas de pantalla,
    //! para un orbe de radio orbRadius centrado en (cx, cy).
    function ringPoints(ring as Number, cx as Number, cy as Number, orbRadius as Number,
            xs as Array<Number>, ys as Array<Number>) as Void {
        var base = orbRadius * (RING_RADIUS as Array<Number>)[ring] / 1000.0f;
        var a1 = (RING_A1 as Array<Number>)[ring] / 1000.0f;
        var a2 = (RING_A2 as Array<Number>)[ring] / 1000.0f;
        var phase1 = (RING_PHASE1_SPEED as Array<Number>)[ring] * _time;
        var phase2 = (RING_PHASE2_SPEED as Array<Number>)[ring] * _time;
        var rotation = ringRotation(ring);
        var step = 360.0f / POINTS;

        for (var k = 0; k < POINTS; k++) {
            var theta = k * step;
            var r = base * (1.0f + a1 * _trig.sinDeg(2.0f * theta + phase1)
                + a2 * _trig.sinDeg(3.0f * theta + phase2));
            var angle = theta + rotation;
            // Pantalla: y crece hacia abajo.
            xs[k] = cx + round(r * _trig.cosDeg(angle));
            ys[k] = cy - round(r * _trig.sinDeg(angle));
        }
    }

    //! Redondeo al entero más cercano, simétrico para valores negativos.
    static function round(value as Float) as Number {
        return value >= 0.0f ? (value + 0.5f).toNumber() : (value - 0.5f).toNumber();
    }
}
