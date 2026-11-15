import Toybox.Lang;
import Toybox.Test;

//! Pruebas de SensorWatchdog (aviso "Sin datos del sensor") y del detector tras un corte
//! de datos: un corte no debe tomarse por inactividad prolongada.

(:test)
function watchdogWarnsAfterFiveSecondsWithoutData(logger as Logger) as Boolean {
    var watchdog = new SensorWatchdog();
    Test.assertMessage(!watchdog.check(100000), "sin vigilar no avisa");

    // La fuente nunca entrega datos: cuenta desde start().
    watchdog.start(10000);
    Test.assertMessage(!watchdog.check(10000 + SensorWatchdog.TIMEOUT_MS), "a los 5 s justos todavía no");
    Test.assertMessage(!watchdog.isStale(), "sin aviso");
    Test.assertMessage(watchdog.check(10000 + SensorWatchdog.TIMEOUT_MS + 1), "pasados los 5 s, avisa");
    Test.assertMessage(watchdog.isStale(), "aviso visible");
    Test.assertMessage(!watchdog.check(30000), "solo avisa una vez (un registro en la consola)");
    Test.assertMessage(watchdog.isStale(), "el aviso sigue mientras no haya datos");
    Test.assertEqual(watchdog.staleCount(), 1);
    Test.assertEqual(watchdog.silenceMs(30000), 20000);
    Test.assertEqual(SensorWatchdog.TIMEOUT_MS, 5000);
    return true;
}

(:test)
function watchdogClearsWhenDataReturns(logger as Logger) as Boolean {
    var watchdog = new SensorWatchdog();
    watchdog.start(0);
    // Un lote por segundo: nunca avisa.
    for (var t = 1000; t <= 20000; t += 1000) {
        Test.assertMessage(!watchdog.onData(t), "lotes seguidos: no hubo corte");
        Test.assertMessage(!watchdog.check(t + 500), "ni aviso");
    }
    Test.assertMessage(watchdog.check(26000), "6 s sin lotes: avisa");
    Test.assertMessage(watchdog.onData(27000), "el lote siguiente avisa de que volvieron");
    Test.assertMessage(!watchdog.isStale(), "y se quita solo");
    Test.assertMessage(!watchdog.onData(28000), "el siguiente ya es normal");
    Test.assertMessage(watchdog.check(33001), "un segundo corte vuelve a avisar");
    Test.assertEqual(watchdog.staleCount(), 2);
    return true;
}

//! Si nadie llamó a check() durante el corte (la esfera estaba tapada por un menú), el
//! lote que vuelve igual se reconoce como el fin de un corte.
(:test)
function watchdogDetectsGapWithoutCheck(logger as Logger) as Boolean {
    var watchdog = new SensorWatchdog();
    watchdog.start(0);
    Test.assertMessage(!watchdog.onData(1000), "lote normal");
    Test.assertMessage(!watchdog.onData(6000), "5 s exactos no es un corte");
    Test.assertMessage(watchdog.onData(12000), "6 s entre lotes sí");
    Test.assertMessage(!watchdog.isStale(), "sin aviso al volver los datos");
    return true;
}

(:test)
function watchdogStopClearsNotice(logger as Logger) as Boolean {
    var watchdog = new SensorWatchdog();
    watchdog.start(0);
    Test.assert(watchdog.check(6000));
    watchdog.stop();
    Test.assertMessage(!watchdog.isStale(), "pausar quita el aviso");
    Test.assertMessage(!watchdog.isRunning(), "y deja de vigilar");
    Test.assertMessage(!watchdog.check(60000), "en pausa nunca avisa");
    Test.assertMessage(!watchdog.onData(60000), "ni cuenta lotes");
    Test.assertEqual(watchdog.silenceMs(60000), 0);

    watchdog.start(60000);
    Test.assertEqual(watchdog.staleCount(), 0);
    Test.assertMessage(!watchdog.check(65000), "una guardia nueva cuenta desde su inicio");
    return true;
}

//! Brazo inmóvil 50 s, corte de 20 s y otra vez inmóvil: sin tratar el corte, el primer
//! lote de vuelta suma 70 s de "quietud" y salta una inactividad falsa. Tratándolo
//! (como GuardController), la quietud cuenta desde cero: nada hasta 60 s después.
(:test)
function dataGapDoesNotTriggerInactivity(logger as Logger) as Boolean {
    var naive = new DetectorRig(AccelScenario.INACTIVITY, SIM_TEST_SEED, false);
    naive.run(50);
    Test.assertEqual(naive.events(), 0);
    naive.gap(20, false);
    Test.assertEqual(naive.step(), DrowsinessEvent.INACTIVITY);

    var rig = new DetectorRig(AccelScenario.INACTIVITY, SIM_TEST_SEED, false);
    rig.run(50);
    rig.gap(20, true);
    Test.assertEqual(rig.detector.stillSeconds(), 0.0f);
    // 2 s para volver a llenar la ventana; la quietud cuenta esos 2 s, así que la
    // inactividad llega a los 60 s de datos nuevos, no antes.
    rig.run(59);
    logger.debug("tras el corte: eventos=" + rig.events() + ", quietud " + rig.detector.stillSeconds() + " s");
    Test.assertEqual(rig.events(), 0);
    Test.assertEqual(rig.step(), DrowsinessEvent.INACTIVITY);
    return true;
}

//! Lo mismo en modo demo (8 s): un corte en mitad de la quietud no adelanta la alerta.
(:test)
function dataGapRestartsDemoInactivity(logger as Logger) as Boolean {
    var rig = new DetectorRig(AccelScenario.INACTIVITY, SIM_TEST_SEED, true);
    rig.run(6);
    rig.gap(10, true);
    rig.run(7);
    Test.assertEqual(rig.events(), 0);
    Test.assertEqual(rig.step(), DrowsinessEvent.INACTIVITY);
    Test.assertEqual(rig.detector.lastEvent(), DrowsinessEvent.INACTIVITY);
    Test.assertEqual(rig.nods, 0);
    return true;
}
