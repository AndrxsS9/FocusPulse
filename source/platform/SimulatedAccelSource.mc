import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;

//! Escenarios de la fuente simulada.
module AccelScenario {

    enum Id {
        //! Movimiento normal: ruido ±70 mg (triangular) con Z ≈ 975 mg.
        NORMAL = 0,
        //! Tecleo activo: ±250 mg en X/Y y Z 960 ± 220 mg.
        TYPING = 1,
        //! Cabeceo: 3 s de movimiento normal, caída brusca de ~0,5 s hacia el brazo
        //! colgando y después quietud total.
        NOD = 2,
        //! Inactividad prolongada: brazo inerte, ±4 mg alrededor de (22, -18, 996).
        INACTIVITY = 3,
        //! Manual: X/Y/Z fijos (SimulatedAccelSource.setManual) con ruido de ±4 mg.
        MANUAL = 4
    }

    //! Número de escenarios (para recorrerlos en el selector de depuración).
    const COUNT = 5;
}

//! Fuente simulada: genera lotes con el mismo formato que RealAccelSource (25 muestras
//! por segundo en mg) para el modo demo y para la sustentación en el simulador.
//!
//! - nextBatch() genera las muestras sin temporizador: lo usan las pruebas.
//! - start() arranca un Timer que entrega un lote cada PERIOD_MS con System.getTimer()
//!   como marca de tiempo, igual que la fuente real.
//!
//! El ruido es uniforme y sale de un generador congruencial propio con semilla, no de
//! Math.rand(), para que las pruebas sean reproducibles.
class SimulatedAccelSource extends AccelSource {

    //! Periodo de entrega de lotes (ms), igual que RealAccelSource.PERIOD_SECONDS.
    static const PERIOD_MS = 1000;

    //! Postura base del movimiento normal (mg) y amplitud del ruido. El ruido es
    //! triangular (suma de dos uniformes de ±35): sigue dentro de ±70 mg, pero los valores
    //! extremos son raros, como en un brazo que se mueve sin brusquedad. Su varianza
    //! (≈ 800 mg²) queda entre la quietud (< 100) y la actividad alta de AlertnessScore
    //! (> 1500); con ruido uniforme de ±70 sería ≈ 1 630 mg² y contaría como tecleo.
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
    //! volver a elegirlo).
    function setScenario(scenario as AccelScenario.Id) as Void {
        _scenario = scenario;
        _sampleIndex = 0;
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
            _sampleIndex += 1;
        }
        return [xs, ys, zs] as Array<Array<Number>>;
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
