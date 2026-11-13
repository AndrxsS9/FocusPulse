import Toybox.Lang;

//! Estado del orbe, derivado de la guardia, la telemetría y el puntaje.
module OrbState {

    enum Id {
        //! Guardia en pausa: orbe tenue y quieto.
        PAUSED = 0,
        //! Movimiento normal: giro tranquilo.
        NORMAL = 1,
        //! Actividad alta (tecleo): el doble de rápido y las partículas titilan más.
        ACTIVE = 2,
        //! Cabeceo, inerte o puntaje < 60: cámara lenta, "se está durmiendo".
        DROWSY = 3
    }
}

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
//! El tiempo de animación avanza dt × multiplicador del estado (pausa 0, normal 1,
//! activo 2, somnoliento 0,35), así que todo el orbe acelera o frena a la vez.
//!
//! Partículas: PARTICLES puntos en posiciones fijas sobre un anillo entre el orbe y el
//! borde (radio que elige quien dibuja), con un pequeño desplazamiento radial propio. Su
//! brillo (0–1) es una onda en el tiempo de animación con un desfase por partícula.
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

    //! Multiplicadores de velocidad por estado.
    static const SPEED_PAUSED = 0.0f;
    static const SPEED_NORMAL = 1.0f;
    static const SPEED_ACTIVE = 2.0f;
    static const SPEED_DROWSY = 0.35f;

    //! Puntaje por debajo del cual el orbe pasa a somnoliento (= banda ámbar).
    static const DROWSY_SCORE = AlertnessColors.HIGH_THRESHOLD;

    //! Número de partículas y su desfase angular: las 16 se reparten cada 22,5°,
    //! empezando a 11,25° para no caer justo arriba ni abajo (batería y botón).
    static const PARTICLES = 16;
    static const PARTICLE_START = 11.25f;

    //! Desplazamiento radial de cada partícula, en milésimas del radio del anillo de
    //! partículas (±1,4 %): rompe la simetría para que parezcan estrellas, no las marcas
    //! de un reloj, sin salirse del hueco estrecho donde se dibujan.
    static const PARTICLE_JITTER = [8, -12, 4, -4, 14, -10, 0, 10, -14, 6, -2, 12, -8, 2, -6, 10];

    //! Velocidad de la onda de brillo (grados por segundo de animación): un ciclo cada
    //! 2,4 s a velocidad normal.
    static const TWINKLE_SPEED = 150;

    //! Desfase de brillo entre partículas consecutivas (ángulo áureo, ≈137,5°): ninguna
    //! titila al mismo tiempo que su vecina.
    static const TWINKLE_OFFSET = 137.5f;

    private var _state as OrbState.Id = OrbState.PAUSED;

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

    //! Estado del orbe a partir de la guardia, la clase ganadora del clasificador
    //! (StateClassifier.topClass) y el puntaje:
    //! - en pausa → PAUSED;
    //! - Activo → ACTIVE (tiene prioridad sobre un puntaje bajo: el usuario se está
    //!   moviendo y el puntaje subiendo);
    //! - Cabeceo o Inerte → DROWSY (aunque el puntaje aún sea alto);
    //! - puntaje < DROWSY_SCORE → DROWSY;
    //! - si no → NORMAL.
    static function stateFor(guardActive as Boolean, topClass as DrowsinessClass.Id,
            score as Number) as OrbState.Id {
        if (!guardActive) {
            return OrbState.PAUSED;
        }
        if (topClass == DrowsinessClass.ACTIVE) {
            return OrbState.ACTIVE;
        }
        if (topClass == DrowsinessClass.NOD || topClass == DrowsinessClass.INERT) {
            return OrbState.DROWSY;
        }
        if (score < DROWSY_SCORE) {
            return OrbState.DROWSY;
        }
        return OrbState.NORMAL;
    }

    //! Multiplicador de velocidad de un estado.
    static function speedFor(state as OrbState.Id) as Float {
        switch (state) {
            case OrbState.NORMAL:
                return SPEED_NORMAL;
            case OrbState.ACTIVE:
                return SPEED_ACTIVE;
            case OrbState.DROWSY:
                return SPEED_DROWSY;
            default:
                return SPEED_PAUSED;
        }
    }

    //! Colores de los 3 anillos (exterior → interior) según el puntaje: los de
    //! AlertnessColors.orbPalette (cian / ámbar / rojo con sus acompañantes).
    static function paletteFor(score as Number) as Array<Number> {
        return AlertnessColors.orbPalette(score);
    }

    function setState(state as OrbState.Id) as Void {
        _state = state;
    }

    function state() as OrbState.Id {
        return _state;
    }

    //! Avanza la animación dt segundos reales, escalados por el estado. En pausa no
    //! avanza: el orbe queda quieto donde estaba.
    function advance(dt as Float) as Void {
        if (dt > 0.0f) {
            _time += dt * speedFor(_state);
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

    //! Escribe en xs, ys (tamaño PARTICLES) las posiciones fijas de las partículas sobre
    //! un anillo de radio radius centrado en (cx, cy).
    function particlePoints(cx as Number, cy as Number, radius as Number,
            xs as Array<Number>, ys as Array<Number>) as Void {
        var step = 360.0f / PARTICLES;
        var jitter = PARTICLE_JITTER as Array<Number>;
        for (var i = 0; i < PARTICLES; i++) {
            var angle = PARTICLE_START + i * step;
            var r = radius * (1000 + jitter[i]) / 1000.0f;
            xs[i] = cx + round(r * _trig.cosDeg(angle));
            ys[i] = cy - round(r * _trig.sinDeg(angle));
        }
    }

    //! Brillo de la partícula i, de 0 (apagada) a 1 (máximo).
    function particleBrightness(i as Number) as Float {
        var angle = TWINKLE_SPEED * _time + TWINKLE_OFFSET * i;
        return 0.5f + 0.5f * _trig.sinDeg(angle);
    }
}
