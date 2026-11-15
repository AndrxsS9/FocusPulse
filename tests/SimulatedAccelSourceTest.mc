import Toybox.Lang;
import Toybox.Test;

//! Pruebas de SimulatedAccelSource (source/platform): cada escenario produce su firma
//! al pasar por TelemetryEngine. Usan nextBatch(), sin temporizador.

//! Semilla fija para que el ruido sea reproducible.
(:debug)
const SIM_TEST_SEED = 20261113;

//! Pasa seconds lotes de 1 s del escenario por un motor nuevo y lo devuelve.
(:debug)
function runScenario(source as SimulatedAccelSource, seconds as Number) as TelemetryEngine {
    var engine = new TelemetryEngine();
    feedSeconds(source, engine, seconds, 1000);
    return engine;
}

//! Entrega seconds lotes de 1 s al motor empezando en startMs; devuelve el instante
//! del siguiente lote.
(:debug)
function feedSeconds(source as SimulatedAccelSource, engine as TelemetryEngine, seconds as Number,
        startMs as Number) as Number {
    var t = startMs;
    for (var i = 0; i < seconds; i++) {
        var batch = source.nextBatch(SlidingWindow.SAMPLE_RATE_HZ);
        engine.addBatch(batch[0], batch[1], batch[2], t);
        t += 1000;
    }
    return t;
}

//! true si |value - expected| <= tolerance.
(:debug)
function within(value as Number, expected as Number, tolerance as Number) as Boolean {
    var d = value - expected;
    return d <= tolerance && d >= -tolerance;
}

(:test)
function simulatedBatchesHaveRealFormat(logger as Logger) as Boolean {
    var source = new SimulatedAccelSource(AccelScenario.NORMAL, SIM_TEST_SEED);
    Test.assert(source.isSimulated());
    Test.assert(!source.isRunning());

    var batch = source.nextBatch(SlidingWindow.SAMPLE_RATE_HZ);
    Test.assertEqual(batch.size(), 3);
    for (var axis = 0; axis < 3; axis++) {
        Test.assertEqual(batch[axis].size(), SlidingWindow.SAMPLE_RATE_HZ);
    }
    return true;
}

(:test)
function simulatedNoiseIsReproducible(logger as Logger) as Boolean {
    var a = new SimulatedAccelSource(AccelScenario.TYPING, SIM_TEST_SEED).nextBatch(25);
    var b = new SimulatedAccelSource(AccelScenario.TYPING, SIM_TEST_SEED).nextBatch(25);
    for (var i = 0; i < 25; i++) {
        Test.assertEqual(a[0][i], b[0][i]);
        Test.assertEqual(a[2][i], b[2][i]);
    }
    return true;
}

(:test)
function simulatedNormalStaysInsideItsSignature(logger as Logger) as Boolean {
    var source = new SimulatedAccelSource(AccelScenario.NORMAL, SIM_TEST_SEED);
    var batch = source.nextBatch(250);
    for (var i = 0; i < 250; i++) {
        Test.assert(within(batch[0][i], SimulatedAccelSource.NORMAL_X, SimulatedAccelSource.NORMAL_NOISE));
        Test.assert(within(batch[2][i], 975, SimulatedAccelSource.NORMAL_NOISE));
    }

    var s = runScenario(new SimulatedAccelSource(AccelScenario.NORMAL, SIM_TEST_SEED), 5).snapshot();
    logger.debug("normal: varianza=" + s.variance + " sacudida=" + s.jerk);
    Test.assert(s.variance > SlidingWindow.STILL_VARIANCE_MAX);
    // Ni quieto ni actividad alta (lejos del tecleo, ≈ 18 000 mg²).
    Test.assert(s.variance < 1500.0f);
    Test.assert(!s.isStill);
    Test.assert(s.batchPeakJerk < 400);
    return true;
}

(:test)
function simulatedTypingHasHighVariance(logger as Logger) as Boolean {
    var typing = runScenario(new SimulatedAccelSource(AccelScenario.TYPING, SIM_TEST_SEED), 5).snapshot();
    var normal = runScenario(new SimulatedAccelSource(AccelScenario.NORMAL, SIM_TEST_SEED), 5).snapshot();
    logger.debug("tecleo: varianza=" + typing.variance + " normal: " + normal.variance);

    // Z 960 ± 220 uniforme ⇒ varianza ≈ 220²/3 ≈ 16 000 mg².
    Test.assert(typing.variance > 8000.0f);
    Test.assert(typing.variance > 4 * normal.variance);
    Test.assert(!typing.isStill);
    Test.assert(nearlyEqual(typing.stillSeconds, 0.0f, 0.001f));
    return true;
}

(:test)
function simulatedInactivityHasLowVariance(logger as Logger) as Boolean {
    var engine = runScenario(new SimulatedAccelSource(AccelScenario.INACTIVITY, SIM_TEST_SEED), 6);
    var s = engine.snapshot();
    logger.debug("inerte: varianza=" + s.variance + " quietud=" + s.stillSeconds);

    Test.assert(s.variance < SlidingWindow.STILL_VARIANCE_MAX);
    Test.assert(s.isStill);
    // La ventana se llena a los 2 s: quedan ≈ 4 s de quietud de los 6.
    Test.assert(s.stillSeconds >= 3.5f);
    Test.assert(s.jerk < 20);
    Test.assert(within(s.x, SimulatedAccelSource.INERT_X, SimulatedAccelSource.INERT_NOISE));
    Test.assert(within(s.y, SimulatedAccelSource.INERT_Y, SimulatedAccelSource.INERT_NOISE));
    Test.assert(within(s.z, SimulatedAccelSource.INERT_Z, SimulatedAccelSource.INERT_NOISE));
    return true;
}

(:test)
function simulatedNodHasJerkThenStillness(logger as Logger) as Boolean {
    var source = new SimulatedAccelSource(AccelScenario.NOD, SIM_TEST_SEED);
    var engine = new TelemetryEngine();
    var t = 1000;

    // Los 3 primeros segundos son movimiento normal: sin sacudida fuerte ni quietud.
    var maxLeadJerk = 0;
    for (var i = 0; i < 3; i++) {
        t = feedSeconds(source, engine, 1, t);
        var lead = engine.snapshot();
        Test.assert(!lead.isStill);
        if (lead.batchPeakJerk > maxLeadJerk) {
            maxLeadJerk = lead.batchPeakJerk;
        }
    }
    Test.assert(maxLeadJerk < 400);

    // El cuarto lote trae la caída: sacudida > 400 mg.
    t = feedSeconds(source, engine, 1, t);
    var drop = engine.snapshot();
    logger.debug("cabeceo: sacudida pico=" + drop.batchPeakJerk + " previa=" + maxLeadJerk);
    Test.assert(drop.batchPeakJerk > 400);

    // Después, quietud con el brazo colgando.
    t = feedSeconds(source, engine, 5, t);
    var after = engine.snapshot();
    logger.debug("cabeceo: quietud=" + after.stillSeconds + " varianza=" + after.variance);
    Test.assert(after.isStill);
    Test.assert(after.stillSeconds >= 1.0f);
    Test.assert(after.batchPeakJerk < 20);
    Test.assert(within(after.x, SimulatedAccelSource.NOD_TO_X, SimulatedAccelSource.INERT_NOISE));
    Test.assert(within(after.y, SimulatedAccelSource.NOD_TO_Y, SimulatedAccelSource.INERT_NOISE));
    Test.assert(within(after.z, SimulatedAccelSource.NOD_TO_Z, SimulatedAccelSource.INERT_NOISE));

    // Elegirlo otra vez repite el cabeceo desde la postura despierta, tras la transición
    // desde el brazo colgando.
    source.setScenario(AccelScenario.NOD);
    var again = source.nextBatch(SimulatedAccelSource.TRANSITION_SAMPLES + 1);
    Test.assert(within(again[2][0], SimulatedAccelSource.NOD_TO_Z, 2 * SimulatedAccelSource.NORMAL_NOISE));
    Test.assert(within(again[2][SimulatedAccelSource.TRANSITION_SAMPLES],
        SimulatedAccelSource.NOD_FROM_Z, SimulatedAccelSource.NORMAL_NOISE));
    return true;
}

(:test)
function simulatedManualUsesFixedAxes(logger as Logger) as Boolean {
    var source = new SimulatedAccelSource(AccelScenario.MANUAL, SIM_TEST_SEED);
    var first = source.nextBatch(1);
    Test.assert(within(first[2][0], SimulatedAccelSource.MANUAL_DEFAULT_Z, SimulatedAccelSource.INERT_NOISE));

    source.setManual(-500, 850, 120);
    var batch = source.nextBatch(50);
    for (var i = 0; i < 50; i++) {
        Test.assert(within(batch[0][i], -500, SimulatedAccelSource.INERT_NOISE));
        Test.assert(within(batch[1][i], 850, SimulatedAccelSource.INERT_NOISE));
        Test.assert(within(batch[2][i], 120, SimulatedAccelSource.INERT_NOISE));
    }
    return true;
}

(:test)
function simulatedGlanceTurnsTheWristAndHoldsIt(logger as Logger) as Boolean {
    var source = new SimulatedAccelSource(AccelScenario.GLANCE, SIM_TEST_SEED);
    var engine = runScenario(source, 4);
    var before = engine.snapshot();
    // Giro a los 4 s y lectura hasta los 10,3 s: a los 9 s la ventana es toda lectura.
    feedSeconds(source, engine, 5, 5000);
    var reading = engine.snapshot();
    var tilt = Tilt.between(before, reading);
    logger.debug("mirar la hora: varianza antes=" + before.variance + " leyendo=" + reading.variance
        + " inclinación=" + tilt + " sacudida máx. del giro=" + reading.batchPeakJerk);
    Test.assert(!before.isStill);
    // El brazo sostenido tiembla: más que un brazo inerte (≈ 6 mg²), menos que el umbral
    // de quietud. Es justo lo que lo hace parecido a un cabeceo.
    Test.assert(reading.variance > 10.0f && reading.variance < SlidingWindow.STILL_VARIANCE_MAX);
    Test.assert(tilt > DrowsinessDetector.NOD_TILT_MIN);

    // Después baja el brazo y vuelve a la postura normal (el ciclo dura 12 s).
    feedSeconds(source, engine, 4, 10000);
    var after = engine.snapshot();
    Test.assert(!after.isStill);
    Test.assert(Tilt.between(before, after) < 10.0f);
    return true;
}
