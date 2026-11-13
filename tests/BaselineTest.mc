import Toybox.Lang;
import Toybox.Test;

//! Pruebas de Baseline: calibración (duración, media y desviación aprendidas), umbral
//! de quietud adaptativo y adaptación lenta; y de su uso dentro del detector.

//! Línea base calibrada con n ventanas de la misma varianza.
function calibratedBaseline(variance as Float, n as Number) as Baseline {
    var baseline = new Baseline();
    baseline.start(0, Baseline.CALIBRATION_DEMO_MS);
    for (var i = 1; i <= n; i++) {
        baseline.observe(variance, i * Baseline.CALIBRATION_DEMO_MS / n);
    }
    return baseline;
}

(:test)
function baselineCalibrationEndsAt30sAnd5s(logger as Logger) as Boolean {
    // Modo demo: 5 s.
    var demo = new DetectorRig(AccelScenario.NORMAL, SIM_TEST_SEED, true);
    demo.run(4);
    Test.assert(demo.detector.isCalibrating());
    Test.assertEqual(demo.detector.state(), DetectorState.CALIBRATING);
    Test.assert(nearlyEqual(demo.detector.stillThreshold(), Baseline.STILL_MAX, 0.001f));
    demo.step();
    Test.assertEqual(demo.timeMs, 5000);
    Test.assert(!demo.detector.isCalibrating());
    Test.assert(demo.detector.baseline().isReady());
    Test.assertEqual(demo.detector.state(), DetectorState.WATCHING);

    // Modo normal: 30 s.
    var normal = new DetectorRig(AccelScenario.NORMAL, SIM_TEST_SEED, false);
    normal.run(29);
    Test.assert(normal.detector.isCalibrating());
    normal.step();
    Test.assertEqual(normal.timeMs, 30000);
    Test.assert(!normal.detector.isCalibrating());
    // Ventanas llenas de los segundos 2 a 30.
    Test.assertEqual(normal.detector.baseline().calibrationCount(), 29);
    return true;
}

(:test)
function baselineLearnsNormalMovement(logger as Logger) as Boolean {
    var rig = new DetectorRig(AccelScenario.NORMAL, SIM_TEST_SEED, false);
    rig.run(30);
    var baseline = rig.detector.baseline();
    logger.debug("normal: media=" + baseline.mean() + " desviación=" + baseline.stdDev()
        + " típica=" + baseline.typicalVariance() + " mg² umbral=" + baseline.stillThreshold());
    // Movimiento normal simulado: ≈ 500–900 mg², ln ≈ 6,2–6,8.
    Test.assert(baseline.mean() > 6.0f && baseline.mean() < 7.0f);
    Test.assert(baseline.stdDev() < 0.5f);
    // 0,25 × ≈ 650 > 100: el umbral queda en la constante.
    Test.assert(nearlyEqual(baseline.stillThreshold(), Baseline.STILL_MAX, 0.001f));
    return true;
}

(:test)
function baselineAdaptsThresholdForStillUsers(logger as Logger) as Boolean {
    // Durante la calibración el umbral es el de siempre.
    var calibrating = new Baseline();
    calibrating.start(0, Baseline.CALIBRATION_DEMO_MS);
    calibrating.observe(200.0f, 1000);
    Test.assert(nearlyEqual(calibrating.stillThreshold(), 100.0f, 0.001f));

    // Usuario que se mueve poco: varianza típica 200 mg² → umbral 0,25 × 200 = 50.
    var low = calibratedBaseline(200.0f, 5);
    Test.assert(low.isReady());
    Test.assert(nearlyEqual(low.typicalVariance(), 200.0f, 0.5f));
    Test.assert(nearlyEqual(low.stillThreshold(), 50.0f, 0.2f));
    Test.assert(nearlyEqual(low.stdDev(), Baseline.MIN_STD, 0.001f));

    // Muy poco movimiento: no baja del piso.
    Test.assert(nearlyEqual(calibratedBaseline(40.0f, 5).stillThreshold(), Baseline.STILL_FLOOR, 0.001f));
    // Mucho movimiento: no sube de 100.
    Test.assert(nearlyEqual(calibratedBaseline(18000.0f, 5).stillThreshold(), 100.0f, 0.001f));

    // Sin ventanas válidas quedan los valores por defecto.
    var none = new Baseline();
    none.start(0, Baseline.CALIBRATION_DEMO_MS);
    Test.assert(!none.observe(null, 4000));
    Test.assert(none.observe(null, 5000));
    Test.assert(nearlyEqual(none.mean(), Baseline.DEFAULT_MEAN, 0.001f));
    Test.assert(nearlyEqual(none.stillThreshold(), 100.0f, 0.001f));
    return true;
}

(:test)
function baselineAdaptsSlowlyAfterCalibration(logger as Logger) as Boolean {
    var baseline = calibratedBaseline(200.0f, 5);
    var start = baseline.mean();
    var target = Baseline.logVariance(2000.0f);

    // Una ventana solo mueve la media un EMA_ALPHA del camino.
    baseline.observe(2000.0f, 6000);
    Test.assert(nearlyEqual(baseline.mean(), start + Baseline.EMA_ALPHA * (target - start), 0.0001f));

    // Tras 100 ventanas ha recorrido 1 − 0,99^100 ≈ 63 % del camino.
    for (var i = 1; i < 100; i++) {
        baseline.observe(2000.0f, 6000 + i * 1000);
    }
    var fraction = (baseline.mean() - start) / (target - start);
    logger.debug("EMA: fracción recorrida en 100 ventanas=" + fraction);
    Test.assert(nearlyEqual(fraction, 0.634f, 0.01f));
    Test.assertEqual(baseline.adaptCount(), 100);
    // Las ventanas inválidas no cuentan.
    baseline.observe(null, 200000);
    Test.assertEqual(baseline.adaptCount(), 100);
    return true;
}

(:test)
function baselineIgnoresStillAndEventWindows(logger as Logger) as Boolean {
    // Cabeceo durante la calibración (modo normal, 30 s): se detecta igual, y ni la
    // caída ni la quietud posterior entran en la línea base: solo los 2 lotes llenos de
    // antes de la caída.
    var rig = new DetectorRig(AccelScenario.NOD, SIM_TEST_SEED, false);
    rig.run(30);
    var baseline = rig.detector.baseline();
    logger.debug("cabeceo calibrando: cabeceos=" + rig.nods + " ventanas de calibración="
        + baseline.calibrationCount() + " media=" + baseline.mean());
    Test.assertEqual(rig.nods, 1);
    Test.assert((rig.firstNodMs as Number) < Baseline.CALIBRATION_MS);
    Test.assertEqual(baseline.calibrationCount(), 2);
    Test.assert(baseline.mean() > 6.0f);

    // Inactividad después de calibrar: la línea base no se mueve.
    var still = new DetectorRig(AccelScenario.NORMAL, SIM_TEST_SEED, true);
    still.run(10);
    var adapted = still.detector.baseline().adaptCount();
    var mean = still.detector.baseline().mean();
    still.source.setScenario(AccelScenario.INACTIVITY);
    still.run(20);
    // Como mucho la ventana de transición, que aún no está quieta.
    Test.assert(still.detector.baseline().adaptCount() <= adapted + 2);
    Test.assert(nearlyEqual(still.detector.baseline().mean(), mean, 0.05f));
    return true;
}
