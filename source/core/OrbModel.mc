import Toybox.Lang;
import Toybox.Math;

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

//! Modelo del orbe IA que se dibuja detrás del contenido de la esfera: 3 contornos
//! orgánicos cerrados que giran y se deforman, copiados del diseño web.
//!
//! **Forma.** Cada contorno es un trazado SVG de 4 curvas de Bézier cúbicas en
//! coordenadas locales (centro del orbe en 0,0; y hacia abajo), en píxeles de una pantalla
//! de DESIGN_SIZE (390) px:
//!
//!     A: M 0,-150 C 80,-152 140,-90 145,-10 C 150,80 85,140 5,138
//!                 C -85,136 -150,75 -146,-5 C -142,-90 -80,-148 0,-150 Z
//!     B: M 10,-140 C 95,-135 155,-60 140,20 C 125,100 60,150 -20,145
//!                  C -100,140 -150,60 -140,-20 C -130,-100 -70,-145 10,-140 Z
//!     C: M -5,-155 C 70,-160 130,-110 150,-30 C 165,50 120,125 30,140
//!                  C -60,155 -135,100 -150,20 C -160,-60 -80,-150 -5,-155 Z
//!
//! Se muestrean una sola vez, al crear el modelo, en SEGMENT_POINTS puntos por curva
//! (POINTS por contorno) y se dibujan como polilínea cerrada.
//!
//! **Movimiento.** Cada contorno tiene su propia fase de ciclo (0–1). Rotación y escala
//! no uniforme siguen 3 fotogramas clave con interpolación lineal, como la animación CSS:
//!
//!     A:   0° escala (1, 1)       → 180° (1,07, 0,93) →  360° (1, 1)
//!     B:   0° escala (0,95, 1,04) → -180° (1,05, 0,95) → -360° (0,95, 1,04)
//!     C:  40° escala (1, 1)       → 220° (0,92, 1,06) →  400° (1, 1)
//!
//! La rotación avanza a ritmo constante y la escala va al valor del medio y vuelve. Un
//! punto local p se lleva a pantalla como centro + k · R(θ) · S · p (primero la escala,
//! después la rotación, como "rotate(θ) scale(sx, sy)" en CSS; θ > 0 gira en sentido
//! horario porque y crece hacia abajo), con k = lado de la pantalla / DESIGN_SIZE.
//!
//! **Estados.** La duración del ciclo de cada contorno (A / B / C) y la opacidad general
//! del orbe dependen del estado:
//!
//!     pausa         congelado               opacidad 0,3
//!     activo        4,5 /  6   /  7,5 s     opacidad 1
//!     normal        9   / 12   / 15   s     opacidad 0,9
//!     somnoliento  22   / 28   / 34   s     opacidad 0,75
//!
//! Cada contorno avanza su fase dt / duración, así que un cambio de estado cambia la
//! velocidad sin saltos. La opacidad de cada contorno (0,6 / 0,45 / 0,35) se multiplica
//! por la del estado (ringAlpha).
//!
//! El tiempo entra como parámetro (advance(dt)): el modelo no lee el reloj.
//!
//! Partículas: PARTICLES puntos en posiciones fijas sobre un anillo (radio que elige
//! quien dibuja), con un pequeño desplazamiento radial propio. Su brillo (0–1) es una
//! onda en el tiempo de animación con un desfase por partícula.
//!
//! Lógica pura: no depende de WatchUi ni Graphics.
class OrbModel {

    //! Lado de la pantalla del diseño web: las coordenadas de los contornos son píxeles
    //! de una pantalla de este tamaño (la del fr165).
    static const DESIGN_SIZE = 390;

    //! Número de contornos (A, B, C).
    static const RINGS = 3;

    //! Curvas de Bézier por contorno y puntos muestreados por curva.
    static const SEGMENTS = 4;
    static const SEGMENT_POINTS = 12;

    //! Puntos por contorno (SEGMENTS × SEGMENT_POINTS).
    static const POINTS = 48;

    //! Trazados de los contornos: punto inicial (M) y, por cada curva (C), sus dos
    //! puntos de control y su punto final: 2 + 4 × 6 = 26 números. El último punto
    //! coincide con el primero (Z).
    static const CONTOUR_A = [0, -150,
        80, -152, 140, -90, 145, -10,
        150, 80, 85, 140, 5, 138,
        -85, 136, -150, 75, -146, -5,
        -142, -90, -80, -148, 0, -150];
    static const CONTOUR_B = [10, -140,
        95, -135, 155, -60, 140, 20,
        125, 100, 60, 150, -20, 145,
        -100, 140, -150, 60, -140, -20,
        -130, -100, -70, -145, 10, -140];
    static const CONTOUR_C = [-5, -155,
        70, -160, 130, -110, 150, -30,
        165, 50, 120, 125, 30, 140,
        -60, 155, -135, 100, -150, 20,
        -160, -60, -80, -150, -5, -155];

    //! Rotación al empezar el ciclo y giro total por ciclo (grados; B gira al revés).
    static const ROTATION_FROM = [0, 0, 40];
    static const ROTATION_SWEEP = [360, -360, 360];

    //! Escala (milésimas) al empezar/terminar el ciclo y a la mitad, por eje.
    static const SCALE_FROM_X = [1000, 950, 1000];
    static const SCALE_FROM_Y = [1000, 1040, 1000];
    static const SCALE_MID_X = [1070, 1050, 920];
    static const SCALE_MID_Y = [930, 950, 1060];

    //! Duración de un ciclo de cada contorno (A, B, C) por estado (ms).
    static const CYCLE_ACTIVE_MS = [4500, 6000, 7500];
    static const CYCLE_NORMAL_MS = [9000, 12000, 15000];
    static const CYCLE_DROWSY_MS = [22000, 28000, 34000];

    //! Opacidad propia de cada contorno (milésimas).
    static const RING_ALPHA = [600, 450, 350];

    //! Opacidad general del orbe por estado (milésimas).
    static const OPACITY_PAUSED = 300;
    static const OPACITY_ACTIVE = 1000;
    static const OPACITY_NORMAL = 900;
    static const OPACITY_DROWSY = 750;

    //! Multiplicadores de velocidad por estado (tiempo de animación de las partículas).
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
    //! de un reloj.
    static const PARTICLE_JITTER = [8, -12, 4, -4, 14, -10, 0, 10, -14, 6, -2, 12, -8, 2, -6, 10];

    //! Velocidad de la onda de brillo (grados por segundo de animación): un ciclo cada
    //! 2,4 s a velocidad normal.
    static const TWINKLE_SPEED = 150;

    //! Desfase de brillo entre partículas consecutivas (ángulo áureo, ≈137,5°): ninguna
    //! titila al mismo tiempo que su vecina.
    static const TWINKLE_OFFSET = 137.5f;

    private var _state as OrbState.Id = OrbState.PAUSED;

    private var _trig as TrigTable;

    //! Puntos de cada contorno en coordenadas locales (precalculados).
    private var _localXs as Array<Array<Float> >;
    private var _localYs as Array<Array<Float> >;

    //! Fase del ciclo de cada contorno, en 0..1.
    private var _phases as Array<Float>;

    //! Segundos de animación transcurridos (brillo de las partículas).
    protected var _time as Float = 0.0f;

    function initialize() {
        _trig = new TrigTable();
        _localXs = new Array<Array<Float> >[RINGS];
        _localYs = new Array<Array<Float> >[RINGS];
        var contours = [CONTOUR_A, CONTOUR_B, CONTOUR_C] as Array<Array<Number> >;
        for (var ring = 0; ring < RINGS; ring++) {
            var xs = new Array<Float>[POINTS];
            var ys = new Array<Float>[POINTS];
            sampleContour(contours[ring], xs, ys);
            _localXs[ring] = xs;
            _localYs[ring] = ys;
        }
        _phases = [0.0f, 0.0f, 0.0f] as Array<Float>;
    }

    //! Muestrea un trazado de SEGMENTS curvas cúbicas en xs, ys (POINTS puntos): de cada
    //! curva, SEGMENT_POINTS puntos con t = 0, 1/n, …, (n−1)/n. El final de cada curva es
    //! el primer punto de la siguiente, así que ninguno se repite.
    static function sampleContour(path as Array<Number>, xs as Array<Float>, ys as Array<Float>) as Void {
        var k = 0;
        for (var s = 0; s < SEGMENTS; s++) {
            var base = 6 * s;
            for (var i = 0; i < SEGMENT_POINTS; i++) {
                var t = i / SEGMENT_POINTS.toFloat();
                xs[k] = bezier(path[base], path[base + 2], path[base + 4], path[base + 6], t);
                ys[k] = bezier(path[base + 1], path[base + 3], path[base + 5], path[base + 7], t);
                k++;
            }
        }
    }

    //! Coordenada de una curva de Bézier cúbica en t (0–1).
    static function bezier(p0 as Number, p1 as Number, p2 as Number, p3 as Number, t as Float) as Float {
        var u = 1.0f - t;
        return u * u * u * p0 + 3.0f * u * u * t * p1 + 3.0f * u * t * t * p2 + t * t * t * p3;
    }

    //! Tabla de senos compartida (para quien dibuja partículas).
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

    //! Duración del ciclo del contorno en un estado (ms); 0 en pausa (congelado).
    static function cycleMs(state as OrbState.Id, ring as Number) as Number {
        switch (state) {
            case OrbState.ACTIVE:
                return (CYCLE_ACTIVE_MS as Array<Number>)[ring];
            case OrbState.NORMAL:
                return (CYCLE_NORMAL_MS as Array<Number>)[ring];
            case OrbState.DROWSY:
                return (CYCLE_DROWSY_MS as Array<Number>)[ring];
            default:
                return 0;
        }
    }

    //! Opacidad general del orbe en un estado (milésimas).
    static function opacityFor(state as OrbState.Id) as Number {
        switch (state) {
            case OrbState.ACTIVE:
                return OPACITY_ACTIVE;
            case OrbState.NORMAL:
                return OPACITY_NORMAL;
            case OrbState.DROWSY:
                return OPACITY_DROWSY;
            default:
                return OPACITY_PAUSED;
        }
    }

    //! Opacidad con la que se dibuja el contorno en un estado (milésimas): la suya por la
    //! general del estado.
    static function ringAlpha(state as OrbState.Id, ring as Number) as Number {
        return (RING_ALPHA as Array<Number>)[ring] * opacityFor(state) / 1000;
    }

    //! Colores de los 3 contornos (A, B, C) según el puntaje: los de
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

    //! Avanza la animación dt segundos reales: cada contorno, dt / duración de su ciclo
    //! en el estado actual. En pausa no avanza: el orbe queda quieto donde estaba.
    function advance(dt as Float) as Void {
        if (dt <= 0.0f || _state == OrbState.PAUSED) {
            return;
        }
        _time += dt * speedFor(_state);
        for (var ring = 0; ring < RINGS; ring++) {
            _phases[ring] = wrap(_phases[ring] + dt * 1000.0f / cycleMs(_state, ring));
        }
    }

    //! Parte decimal de x (fase en 0..1).
    private static function wrap(x as Float) as Float {
        var f = x - x.toNumber();
        return f < 0.0f ? f + 1.0f : f;
    }

    //! Segundos de animación transcurridos.
    function time() as Float {
        return _time;
    }

    //! Fase del ciclo del contorno, en 0..1.
    function phase(ring as Number) as Float {
        return _phases[ring];
    }

    //! Rotación del contorno en una fase (grados): lineal de ROTATION_FROM a
    //! ROTATION_FROM + ROTATION_SWEEP.
    static function rotationAt(ring as Number, phase as Float) as Float {
        return (ROTATION_FROM as Array<Number>)[ring] + (ROTATION_SWEEP as Array<Number>)[ring] * phase;
    }

    //! Escala horizontal y vertical del contorno en una fase: lineal hasta el valor
    //! del medio (fase 0,5) y de vuelta.
    static function scaleXAt(ring as Number, phase as Float) as Float {
        return keyframe((SCALE_FROM_X as Array<Number>)[ring], (SCALE_MID_X as Array<Number>)[ring], phase);
    }

    static function scaleYAt(ring as Number, phase as Float) as Float {
        return keyframe((SCALE_FROM_Y as Array<Number>)[ring], (SCALE_MID_Y as Array<Number>)[ring], phase);
    }

    //! Valor (en milésimas → unidades) que va de from a mid en la primera mitad del
    //! ciclo y vuelve a from en la segunda.
    private static function keyframe(from as Number, mid as Number, phase as Float) as Float {
        var tri = phase < 0.5f ? 2.0f * phase : 2.0f * (1.0f - phase);
        return (from + (mid - from) * tri) / 1000.0f;
    }

    //! Rotación actual del contorno (grados).
    function ringRotation(ring as Number) as Float {
        return rotationAt(ring, _phases[ring]);
    }

    //! Punto k del contorno en coordenadas locales, sin girar ni escalar.
    function localX(ring as Number, k as Number) as Float {
        return _localXs[ring][k];
    }

    function localY(ring as Number, k as Number) as Float {
        return _localYs[ring][k];
    }

    //! Escribe en xs, ys (tamaño POINTS) los puntos del contorno en coordenadas de
    //! pantalla, girado y escalado según su fase, para un orbe centrado en (cx, cy) con
    //! k píxeles por unidad del diseño (lado de la pantalla / DESIGN_SIZE). Son Float:
    //! con el suavizado activo las líneas se colocan con precisión de subpíxel.
    function ringPoints(ring as Number, cx as Number, cy as Number, k as Float,
            xs as Array<Float>, ys as Array<Float>) as Void {
        var p = _phases[ring];
        var radians = Math.toRadians(rotationAt(ring, p));
        var c = Math.cos(radians).toFloat();
        var s = Math.sin(radians).toFloat();
        var sx = scaleXAt(ring, p) * k;
        var sy = scaleYAt(ring, p) * k;
        // R(θ) · S: [c·sx  −s·sy; s·sx  c·sy].
        var m00 = c * sx;
        var m01 = -s * sy;
        var m10 = s * sx;
        var m11 = c * sy;
        var lx = _localXs[ring];
        var ly = _localYs[ring];
        for (var i = 0; i < POINTS; i++) {
            var x = lx[i];
            var y = ly[i];
            xs[i] = cx + m00 * x + m01 * y;
            ys[i] = cy + m10 * x + m11 * y;
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
