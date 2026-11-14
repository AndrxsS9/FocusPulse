import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;

//! Fuente simulada: genera lotes con el mismo formato que RealAccelSource (25 muestras
//! por segundo en mg) para el modo demo y para la sustentación en el simulador.
//!
//! - nextBatch() genera las muestras sin temporizador: lo usan las pruebas.
//! - start() arranca un Timer que entrega un lote cada PERIOD_MS con System.getTimer()
//!   como marca de tiempo, igual que la fuente real.
//!
//! El ruido es uniforme y sale de un generador congruencial propio con semilla, no de
//! Math.rand(), para que las pruebas sean reproducibles.
//!
//! **Transición entre escenarios (fase 11).** Al cambiar de escenario con la fuente ya
//! en marcha (DOWN, el menú o el guion), las primeras TRANSITION_SAMPLES muestras (1,5 s)
//! llevan la postura del brazo (la gravedad) desde donde estaba hasta la postura base del
//! escenario nuevo, con un desfase que baja en línea recta. El ruido y el movimiento son
//! los del escenario nuevo desde la primera muestra: solo se desplaza la gravedad, así
//! la transición no inventa una quietud. Antes la postura saltaba en una sola
//! muestra: de cabeceo (brazo colgando) a inactividad eran ≈ 1 200 mg y 75°, una
//! sacudida seguida de quietud con giro, y el detector daba un cabeceo de más ≈ 4 s
//! después. Ahora cada muestra se mueve unos 30 mg, lejos de cualquier sacudida de caída
//! (340 mg con la sensibilidad alta). La postura de partida es una media móvil de las
//! últimas muestras (sin el ruido).
class SimulatedAccelSource extends AccelSource {

    //! Periodo de entrega de lotes (ms), igual que RealAccelSource.PERIOD_SECONDS.
    static const PERIOD_MS = 1000;

    //! Postura base del movimiento normal (mg) y amplitud del ruido. El ruido es
    //! triangular (suma de dos uniformes de ±35): sigue dentro de ±70 mg, pero los valores
    //! extremos son raros, como en un brazo que se mueve sin brusquedad. Su varianza
    //! (≈ 600–800 mg²) queda lejos de la quietud (< 100) y de la actividad alta (el
    //! tecleo, ≈ 18 000); con ruido uniforme de ±70 sería ≈ 1 630 mg².
    static const NORMAL_X = 40;
    static const NORMAL_Y = -180;
    static const NORMAL_Z = 975;
    static const NORMAL_NOISE = 70;

    //! Tecleo: muñeca sobre el teclado, mucho movimiento en todos los ejes.
    static const TYPING_Z = 960;
    static const TYPING_NOISE_XY = 250;
    static const TYPING_NOISE_Z = 220;

    //! Brazo inerte (inactividad prolongada).
    static const INERT_X = 22;
    static const INERT_Y = -18;
    static const INERT_Z = 996;
    static const INERT_NOISE = 4;

    //! Cabeceo: postura despierta y brazo colgando.
    static const NOD_FROM_X = 0;
    static const NOD_FROM_Y = 0;
    static const NOD_FROM_Z = 980;
    static const NOD_TO_X = -240;
    static const NOD_TO_Y = -940;
    static const NOD_TO_Z = 240;

    //! Muestras de movimiento normal antes de la caída (3 s a 25 Hz).
    static const NOD_LEAD_SAMPLES = 75;

    //! Avance de la caída por muestra, en milésimas del recorrido (12 muestras ≈ 0,5 s):
    //! un inicio lento, el tramo brusco de 5 muestras (80 → 1000), un pequeño rebote al
    //! quedar colgando y el reposo. El mayor salto (300 → 680) es el 38 % de los
    //! ~1220 mg del recorrido, ≈ 464 mg: por encima de los 400 mg de una sacudida.
    static const NOD_PROFILE = [10, 25, 45, 80, 300, 680, 950, 1000, 1040, 1010, 985, 1000];

    //! Mirar la hora y quedarse leyendo: el negativo difícil (a) de ml/generate_dataset.py
    //! con los valores del usuario de referencia. Ciclo de GLANCE_CYCLE_SAMPLES (12 s):
    //! movimiento normal hasta GLANCE_RAISE_START (4 s), giro rápido de 8 muestras
    //! (0,32 s: la gravedad gira 80° con módulo constante y se suma la aceleración de
    //! subir el brazo, ±300 mg), GLANCE_HOLD_SAMPLES (6 s) leyendo con el brazo sostenido
    //! (temblor triangular de ±16 mg), bajada de 15 muestras y movimiento normal.
    //! Las tablas son la trayectoria de generate_dataset.turn_path redondeada a mg.
    static const GLANCE_CYCLE_SAMPLES = 300;
    static const GLANCE_RAISE_START = 100;
    static const GLANCE_HOLD_SAMPLES = 150;
    static const GLANCE_HOLD_X = 14;
    static const GLANCE_HOLD_Y = 930;
    static const GLANCE_HOLD_Z = 346;
    static const GLANCE_HOLD_NOISE = 16;
    static const GLANCE_RAISE_X = [45, 52, 50, 39, 26, 16, 12, 13];
    static const GLANCE_RAISE_Y = [-135, 45, 326, 546, 612, 600, 654, 822];
    static const GLANCE_RAISE_Z = [1098, 1268, 1226, 962, 628, 389, 289, 306];
    static const GLANCE_LOWER_X = [15, 18, 22, 26, 31, 34, 36, 37, 36, 36, 35, 35, 35, 37, 39];
    static const GLANCE_LOWER_Y = [952, 984, 984, 941, 854, 730, 582, 428, 283, 157, 53, -31, -99, -148, -174];
    static const GLANCE_LOWER_Z = [374, 445, 540, 646, 747, 827, 877, 894, 886, 866, 847, 842, 856, 891, 944];

    //! Muestras de la transición al cambiar de escenario (≈ 1,5 s a 25 Hz).
    static const TRANSITION_SAMPLES = 38;

    //! Peso de cada muestra nueva en la media móvil de la postura (1/POSTURE_EMA_DIV).
    static const POSTURE_EMA_DIV = 8;

    //! Valores iniciales del escenario manual.
    static const MANUAL_DEFAULT_X = 0;
    static const MANUAL_DEFAULT_Y = 0;
    static const MANUAL_DEFAULT_Z = 1000;

    private var _scenario as AccelScenario.Id = AccelScenario.NORMAL;

    //! Muestras generadas desde que empezó el escenario.
    private var _sampleIndex as Number = 0;

    private var _seed as Long;
    private var _timer as Timer.Timer? = null;

    private var _manualX as Number = MANUAL_DEFAULT_X;
    private var _manualY as Number = MANUAL_DEFAULT_Y;
    private var _manualZ as Number = MANUAL_DEFAULT_Z;

    //! Postura actual: media móvil de las muestras entregadas (válida si _hasPosture).
    private var _hasPosture as Boolean = false;
    private var _postureX as Number = 0;
    private var _postureY as Number = 0;
    private var _postureZ as Number = 0;

    //! Transición en curso: postura de partida y muestras que faltan (0: sin transición).
    private var _fromX as Number = 0;
    private var _fromY as Number = 0;
    private var _fromZ as Number = 0;
    private var _transitionLeft as Number = 0;

    //! seed: semilla del ruido. La app usa System.getTimer(); las pruebas, un valor fijo.
    function initialize(scenario as AccelScenario.Id, seed as Number) {
        AccelSource.initialize();
        _scenario = scenario;
        _seed = seed.toLong() & 0x7FFFFFFFl;
    }

    function start() as Boolean {
        if (_running) {
            return true;
        }
        // Guardia nueva: empieza en la postura del escenario, sin transición.
        _hasPosture = false;
        _transitionLeft = 0;
        var timer = new Timer.Timer();
        timer.start(method(:onTimer), PERIOD_MS, true);
        _timer = timer;
        _running = true;
        return true;
    }

    function stop() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
        }
        _timer = null;
        _running = false;
    }

    function isSimulated() as Boolean {
        return true;
    }

    function scenario() as AccelScenario.Id {
        return _scenario;
    }

    //! Cambia de escenario y lo empieza desde el principio (el cabeceo se repite al
    //! volver a elegirlo). Si ya se generaron muestras, el brazo pasa de su postura a la
    //! del escenario nuevo en TRANSITION_SAMPLES muestras.
    function setScenario(scenario as AccelScenario.Id) as Void {
        _scenario = scenario;
        _sampleIndex = 0;
        if (_hasPosture) {
            _fromX = _postureX;
            _fromY = _postureY;
            _fromZ = _postureZ;
            _transitionLeft = TRANSITION_SAMPLES;
        }
    }

    //! true mientras dura la transición a un escenario nuevo.
    function isInTransition() as Boolean {
        return _transitionLeft > 0;
    }

    //! Fija los ejes del escenario manual (mg).
    function setManual(x as Number, y as Number, z as Number) as Void {
        _manualX = x;
        _manualY = y;
        _manualZ = z;
    }

    //! Callback del temporizador: entrega un lote de un periodo.
    function onTimer() as Void {
        var batch = nextBatch(sampleRateHz() * PERIOD_MS / 1000);
        deliver(batch[0], batch[1], batch[2], System.getTimer());
    }

    //! Genera las siguientes count muestras del escenario: [xs, ys, zs] en mg.
    function nextBatch(count as Number) as Array<Array<Number>> {
        var xs = new Array<Number>[count];
        var ys = new Array<Number>[count];
        var zs = new Array<Number>[count];
        for (var i = 0; i < count; i++) {
            nextSample(xs, ys, zs, i);
            blendTransition(xs, ys, zs, i);
            followPosture(xs[i], ys[i], zs[i]);
            _sampleIndex += 1;
        }
        return [xs, ys, zs] as Array<Array<Number>>;
    }

    //! Durante la transición suma a la muestra del escenario nuevo el desfase entre la
    //! postura de partida y la base del escenario, con un peso (milésimas) que baja de
    //! TRANSITION_SAMPLES / (N + 1) a 1 / (N + 1).
    private function blendTransition(xs as Array<Number>, ys as Array<Number>, zs as Array<Number>,
            i as Number) as Void {
        if (_transitionLeft <= 0) {
            return;
        }
        var base = basePosture();
        var w = _transitionLeft * 1000 / (TRANSITION_SAMPLES + 1);
        xs[i] += (_fromX - base[0]) * w / 1000;
        ys[i] += (_fromY - base[1]) * w / 1000;
        zs[i] += (_fromZ - base[2]) * w / 1000;
        _transitionLeft -= 1;
    }

    //! Postura con que empieza el escenario actual (mg): la gravedad de sus primeras
    //! muestras, sin el ruido.
    private function basePosture() as Array<Number> {
        switch (_scenario) {
            case AccelScenario.TYPING:
                return [0, 0, TYPING_Z] as Array<Number>;
            case AccelScenario.NOD:
                return [NOD_FROM_X, NOD_FROM_Y, NOD_FROM_Z] as Array<Number>;
            case AccelScenario.INACTIVITY:
                return [INERT_X, INERT_Y, INERT_Z] as Array<Number>;
            case AccelScenario.MANUAL:
                return [_manualX, _manualY, _manualZ] as Array<Number>;
            default:
                // Normal, y mirar la hora, que empieza con 4 s de movimiento normal.
                return [NORMAL_X, NORMAL_Y, NORMAL_Z] as Array<Number>;
        }
    }

    //! Media móvil de la postura (la gravedad sin el ruido), para la próxima transición.
    private function followPosture(x as Number, y as Number, z as Number) as Void {
        if (!_hasPosture) {
            _postureX = x;
            _postureY = y;
            _postureZ = z;
            _hasPosture = true;
            return;
        }
        _postureX += (x - _postureX) / POSTURE_EMA_DIV;
        _postureY += (y - _postureY) / POSTURE_EMA_DIV;
        _postureZ += (z - _postureZ) / POSTURE_EMA_DIV;
    }

    //! Escribe en la posición i la muestra número _sampleIndex del escenario.
    private function nextSample(xs as Array<Number>, ys as Array<Number>, zs as Array<Number>,
            i as Number) as Void {
        switch (_scenario) {
            case AccelScenario.TYPING:
                xs[i] = noise(TYPING_NOISE_XY);
                ys[i] = noise(TYPING_NOISE_XY);
                zs[i] = TYPING_Z + noise(TYPING_NOISE_Z);
                break;
            case AccelScenario.NOD:
                nodSample(xs, ys, zs, i);
                break;
            case AccelScenario.INACTIVITY:
                xs[i] = INERT_X + noise(INERT_NOISE);
                ys[i] = INERT_Y + noise(INERT_NOISE);
                zs[i] = INERT_Z + noise(INERT_NOISE);
                break;
            case AccelScenario.GLANCE:
                glanceSample(xs, ys, zs, i);
                break;
            case AccelScenario.MANUAL:
                xs[i] = _manualX + noise(INERT_NOISE);
                ys[i] = _manualY + noise(INERT_NOISE);
                zs[i] = _manualZ + noise(INERT_NOISE);
                break;
            default:
                xs[i] = NORMAL_X + softNoise(NORMAL_NOISE);
                ys[i] = NORMAL_Y + softNoise(NORMAL_NOISE);
                zs[i] = NORMAL_Z + softNoise(NORMAL_NOISE);
                break;
        }
    }

    //! Cabeceo: movimiento normal alrededor de la postura despierta, caída según
    //! NOD_PROFILE y quietud con el brazo colgando.
    private function nodSample(xs as Array<Number>, ys as Array<Number>, zs as Array<Number>,
            i as Number) as Void {
        if (_sampleIndex < NOD_LEAD_SAMPLES) {
            xs[i] = NOD_FROM_X + softNoise(NORMAL_NOISE);
            ys[i] = NOD_FROM_Y + softNoise(NORMAL_NOISE);
            zs[i] = NOD_FROM_Z + softNoise(NORMAL_NOISE);
            return;
        }
        var step = _sampleIndex - NOD_LEAD_SAMPLES;
        var profile = NOD_PROFILE as Array<Number>;
        var permille = step < profile.size() ? profile[step] : 1000;
        xs[i] = lerp(NOD_FROM_X, NOD_TO_X, permille) + noise(INERT_NOISE);
        ys[i] = lerp(NOD_FROM_Y, NOD_TO_Y, permille) + noise(INERT_NOISE);
        zs[i] = lerp(NOD_FROM_Z, NOD_TO_Z, permille) + noise(INERT_NOISE);
    }

    //! Mirar la hora: normal, giro, lectura con el brazo sostenido, bajada y normal, en un
    //! ciclo de GLANCE_CYCLE_SAMPLES.
    private function glanceSample(xs as Array<Number>, ys as Array<Number>, zs as Array<Number>,
            i as Number) as Void {
        var raiseX = GLANCE_RAISE_X as Array<Number>;
        var lowerX = GLANCE_LOWER_X as Array<Number>;
        var k = _sampleIndex % GLANCE_CYCLE_SAMPLES;
        var holdStart = GLANCE_RAISE_START + raiseX.size();
        var lowerStart = holdStart + GLANCE_HOLD_SAMPLES;
        if (k < GLANCE_RAISE_START || k >= lowerStart + lowerX.size()) {
            xs[i] = NORMAL_X + softNoise(NORMAL_NOISE);
            ys[i] = NORMAL_Y + softNoise(NORMAL_NOISE);
            zs[i] = NORMAL_Z + softNoise(NORMAL_NOISE);
        } else if (k < holdStart) {
            var j = k - GLANCE_RAISE_START;
            xs[i] = raiseX[j] + softNoise(GLANCE_HOLD_NOISE);
            ys[i] = (GLANCE_RAISE_Y as Array<Number>)[j] + softNoise(GLANCE_HOLD_NOISE);
            zs[i] = (GLANCE_RAISE_Z as Array<Number>)[j] + softNoise(GLANCE_HOLD_NOISE);
        } else if (k < lowerStart) {
            xs[i] = GLANCE_HOLD_X + softNoise(GLANCE_HOLD_NOISE);
            ys[i] = GLANCE_HOLD_Y + softNoise(GLANCE_HOLD_NOISE);
            zs[i] = GLANCE_HOLD_Z + softNoise(GLANCE_HOLD_NOISE);
        } else {
            var j = k - lowerStart;
            xs[i] = lowerX[j] + softNoise(NORMAL_NOISE / 2);
            ys[i] = (GLANCE_LOWER_Y as Array<Number>)[j] + softNoise(NORMAL_NOISE / 2);
            zs[i] = (GLANCE_LOWER_Z as Array<Number>)[j] + softNoise(NORMAL_NOISE / 2);
        }
    }

    //! Punto entre from y to, con t en milésimas (puede pasar de 1000 en el rebote).
    private static function lerp(from as Number, to as Number, permille as Number) as Number {
        return from + (to - from) * permille / 1000;
    }

    //! Ruido triangular entero en [-amplitude, amplitude]: suma de dos uniformes de
    //! la mitad de amplitud cada uno.
    private function softNoise(amplitude as Number) as Number {
        var half = amplitude / 2;
        return noise(half) + noise(amplitude - half);
    }

    //! Ruido uniforme entero en [-amplitude, amplitude].
    private function noise(amplitude as Number) as Number {
        _seed = (_seed * 1103515245l + 12345l) & 0x7FFFFFFFl;
        var span = 2 * amplitude + 1;
        return ((_seed >> 8) % span).toNumber() - amplitude;
    }
}
