import Toybox.Lang;
import Toybox.Test;

//! Pruebas de DrowsinessDetector con secuencias completas de la fuente simulada y
//! tiempo controlado (DetectorRig): eventos esperados, falsos positivos, periodo
//! refractario y reinicio al pausar.

//! Instante (ms) de la primera muestra de la caída del escenario de cabeceo: la guardia
//! empieza en 0 y cada muestra dura 40 ms.
(:debug)
const NOD_DROP_MS = (SimulatedAccelSource.NOD_LEAD_SAMPLES + 1) * 1000 / SlidingWindow.SAMPLE_RATE_HZ;

(:test)
function detectorTypingTwoMinutesHasNoEvents(logger as Logger) as Boolean {
    // Modo demo: la inactividad salta a los 8 s, así que es el caso más exigente.
    var rig = new DetectorRig(AccelScenario.TYPING, SIM_TEST_SEED, true);
    rig.run(120);
    logger.debug("tecleo 2 min: eventos=" + rig.events() + " lotes con sacudida >= 400 mg="
        + rig.jerkBatches + " pico=" + rig.maxPeakJerk);
    Test.assertEqual(rig.events(), 0);
    return true;
}

(:test)
function detectorNormalTwoMinutesHasNoEvents(logger as Logger) as Boolean {
    var rig = new DetectorRig(AccelScenario.NORMAL, SIM_TEST_SEED, true);
    rig.run(120);
    logger.debug("normal 2 min: eventos=" + rig.events() + " pico=" + rig.maxPeakJerk);
    Test.assertEqual(rig.events(), 0);
    Test.assertEqual(rig.detector.state(), DetectorState.WATCHING);
    return true;
}

(:test)
function detectorTypingJerksNeverMakeANod(logger as Logger) as Boolean {
    // Las sacudidas del tecleo superan los 400 mg en casi todos los lotes...
    var rig = new DetectorRig(AccelScenario.TYPING, SIM_TEST_SEED + 1, true);
    var fallStates = 0;
    for (var i = 0; i < 60; i++) {
        rig.step();
        if (rig.detector.state() == DetectorState.FALL_DETECTED) {
            fallStates += 1;
        }
    }
    logger.debug("tecleo: lotes con sacudida >= 400 mg=" + rig.jerkBatches + " de 60, "
        + "lotes en caída detectada=" + fallStates);
    Test.assert(rig.jerkBatches >= 40);
    Test.assertEqual(rig.nods, 0);

    // ...y al dejar de teclear llega la quietud, pero sin cambio de postura: no es un
    // cabeceo. Sí es inactividad si la quietud dura.
    rig.source.setScenario(AccelScenario.INACTIVITY);
    rig.run(12);
    logger.debug("tecleo → reposo: cabeceos=" + rig.nods + " inactividad=" + rig.inactivities);
    Test.assertEqual(rig.nods, 0);
    Test.assertEqual(rig.inactivities, 1);
    return true;
}

(:test)
function detectorFallPendingNeedsNearStillness(logger as Logger) as Boolean {
    // Al pasar de teclear a moverse con normalidad queda una sacudida reciente, pero el
    // movimiento no se calma lo bastante: no hay caída pendiente ni cabeceo.
    var rig = new DetectorRig(AccelScenario.TYPING, SIM_TEST_SEED, true);
    rig.run(10);
    rig.source.setScenario(AccelScenario.NORMAL);
    for (var i = 0; i < 10; i++) {
        rig.step();
        Test.assert(!rig.detector.isFallPending());
        Test.assert(rig.detector.state() != DetectorState.FALL_DETECTED);
    }
    Test.assertEqual(rig.events(), 0);
    return true;
}

(:test)
function detectorNodEmitsExactlyOneNodWithin5s(logger as Logger) as Boolean {
    var rig = new DetectorRig(AccelScenario.NOD, SIM_TEST_SEED, true);
    var sawFall = false;
    for (var i = 0; i < 20; i++) {
        rig.step();
        if (rig.detector.state() == DetectorState.FALL_DETECTED) {
            sawFall = true;
        }
    }
    var nodMs = rig.firstNodMs;
    logger.debug("cabeceo: caída en " + NOD_DROP_MS + " ms, evento en " + nodMs + " ms, cabeceos="
        + rig.nods + ", inactividad después=" + rig.inactivities);
    Test.assertEqual(rig.nods, 1);
    Test.assert(sawFall);
    Test.assert(nodMs != null);
    var delay = (nodMs as Number) - NOD_DROP_MS;
    Test.assert(delay > 0 && delay < 5000);
    return true;
}

(:test)
function detectorInactivityFiresAt8sInDemo(logger as Logger) as Boolean {
    var rig = new DetectorRig(AccelScenario.INACTIVITY, SIM_TEST_SEED, true);
    Test.assertEqual(rig.detector.inactivityMs(), 8000);
    for (var i = 0; i < 7; i++) {
        Test.assertEqual(rig.step(), DrowsinessEvent.NONE);
    }
    // Lote que termina a los 8 s: 8 s de quietud desde que empezó la guardia.
    Test.assertEqual(rig.step(), DrowsinessEvent.INACTIVITY);
    Test.assertEqual(rig.timeMs, 8000);
    Test.assertEqual(rig.detector.state(), DetectorState.EVENT);
    Test.assertEqual(rig.nods, 0);
    return true;
}

(:test)
function detectorInactivityFiresAt60sInNormalMode(logger as Logger) as Boolean {
    var rig = new DetectorRig(AccelScenario.INACTIVITY, SIM_TEST_SEED, false);
    Test.assertEqual(rig.detector.inactivityMs(), 60000);
    rig.run(59);
    Test.assertEqual(rig.events(), 0);
    Test.assert(rig.detector.stillSeconds() >= 58.0f);
    Test.assertEqual(rig.step(), DrowsinessEvent.INACTIVITY);
    Test.assertEqual(rig.timeMs, 60000);
    return true;
}

(:test)
function detectorRefractoryPeriodBlocksRepeats(logger as Logger) as Boolean {
    // Inactividad continua: el siguiente evento llega como pronto 10 s después.
    var rig = new DetectorRig(AccelScenario.INACTIVITY, SIM_TEST_SEED, true);
    rig.run(30);
    logger.debug("inactividad 30 s: eventos en " + rig.eventTimes);
    Test.assertEqual(rig.eventTimes.size(), 3);
    for (var i = 1; i < rig.eventTimes.size(); i++) {
        Test.assert(rig.eventTimes[i] - rig.eventTimes[i - 1] >= DrowsinessDetector.REFRACTORY_MS);
    }

    // Dos cabeceos seguidos: el segundo no se emite antes de 10 s.
    var nod = new DetectorRig(AccelScenario.NOD, SIM_TEST_SEED, true);
    nod.run(7);
    Test.assertEqual(nod.nods, 1);
    var firstMs = nod.firstNodMs as Number;
    nod.source.setScenario(AccelScenario.NOD);
    nod.run(15);
    logger.debug("dos cabeceos: eventos en " + nod.eventTimes);
    for (var i = 1; i < nod.eventTimes.size(); i++) {
        Test.assert(nod.eventTimes[i] - firstMs >= DrowsinessDetector.REFRACTORY_MS);
    }
    return true;
}

(:test)
function detectorResetsWhenPaused(logger as Logger) as Boolean {
    var rig = new DetectorRig(AccelScenario.NOD, SIM_TEST_SEED, true);
    rig.run(5);
    Test.assert(rig.detector.fallMs() != null);

    rig.detector.reset();
    Test.assertEqual(rig.detector.state(), DetectorState.IDLE);
    Test.assert(rig.detector.fallMs() == null);
    Test.assert(nearlyEqual(rig.detector.stillSeconds(), 0.0f, 0.001f));
    // En pausa los lotes no hacen nada.
    rig.run(10);
    Test.assertEqual(rig.events(), 0);
    Test.assertEqual(rig.detector.eventCount(), 0);

    // Al reanudar vuelve a calibrar.
    rig.detector.start(rig.timeMs, true);
    Test.assertEqual(rig.detector.state(), DetectorState.CALIBRATING);
    return true;
}

(:test)
function detectorGlanceAtWatchTwoMinutesHasNoNod(logger as Logger) as Boolean {
    // Mirar la hora y quedarse leyendo cada 12 s (negativo difícil): el giro no llega a
    // la sacudida de una caída y la lectura es demasiado corta para la inactividad.
    var rig = new DetectorRig(AccelScenario.GLANCE, SIM_TEST_SEED, true);
    rig.run(120);
    logger.debug("mirar la hora 2 min: cabeceos=" + rig.nods + " inactividad=" + rig.inactivities
        + " lotes con sacudida >= 400 mg=" + rig.jerkBatches + " pico=" + rig.maxPeakJerk);
    Test.assertEqual(rig.nods, 0);
    Test.assertEqual(rig.inactivities, 0);
    return true;
}
