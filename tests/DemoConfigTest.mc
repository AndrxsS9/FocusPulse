import Toybox.Lang;
import Toybox.Test;

//! Pruebas de DemoConfig: umbrales de cada modo, ciclo de escenarios y persistencia.

(:test)
function demoConfigDefaultsToRealSensor(logger as Logger) as Boolean {
    var config = new DemoConfig();
    Test.assertMessage(!config.isEnabled(), "por defecto, sin modo demo");
    Test.assertMessage(!config.usesSimulatedSource(), "sin modo demo: acelerómetro real");
    Test.assertEqual(config.scenario(), AccelScenario.NORMAL);
    return true;
}

(:test)
function demoConfigThresholdsPerMode(logger as Logger) as Boolean {
    var config = new DemoConfig();
    Test.assertEqualMessage(config.calibrationMs(), 30000, "calibración real: 30 s");
    Test.assertEqualMessage(config.inactivityMs(), 60000, "inactividad real: 60 s");

    config.setEnabled(true);
    Test.assertMessage(config.usesSimulatedSource(), "modo demo: fuente simulada");
    Test.assertEqualMessage(config.calibrationMs(), 5000, "calibración demo: 5 s");
    Test.assertEqualMessage(config.inactivityMs(), 8000, "inactividad demo: 8 s");

    config.setEnabled(false);
    Test.assertEqual(config.calibrationMs(), 30000);
    Test.assertEqual(config.inactivityMs(), 60000);
    return true;
}

//! Los tiempos de DemoConfig son los que aplica el detector al arrancar en ese modo.
(:test)
function demoConfigMatchesDetectorTimes(logger as Logger) as Boolean {
    var modes = [false, true] as Array<Boolean>;
    for (var i = 0; i < modes.size(); i++) {
        var config = new DemoConfig();
        config.setEnabled(modes[i]);
        var detector = new DrowsinessDetector();
        detector.start(0, config.isEnabled());
        Test.assertEqual(detector.inactivityMs(), config.inactivityMs());
        Test.assertEqual(detector.isDemo(), config.isEnabled());

        // La línea base que arrancó el detector termina de calibrar justo a
        // calibrationMs(), ni antes ni después.
        var baseline = detector.baseline();
        baseline.observe(500.0f, config.calibrationMs() - 1);
        Test.assertMessage(baseline.isCalibrating(), "aún calibrando 1 ms antes");
        baseline.observe(500.0f, config.calibrationMs());
        Test.assertMessage(!baseline.isCalibrating(), "calibración terminada a tiempo");
    }
    return true;
}

(:test)
function demoConfigCyclesFiveScenariosInOrder(logger as Logger) as Boolean {
    var config = new DemoConfig();
    Test.assertEqual(config.nextScenario(), AccelScenario.TYPING);
    Test.assertEqual(config.nextScenario(), AccelScenario.NOD);
    Test.assertEqual(config.nextScenario(), AccelScenario.INACTIVITY);
    Test.assertEqual(config.nextScenario(), AccelScenario.GLANCE);
    Test.assertEqualMessage(config.nextScenario(), AccelScenario.NORMAL, "vuelve al primero");
    Test.assertEqual(config.scenario(), AccelScenario.NORMAL);

    // MANUAL (solo depuración) no está en el ciclo: el siguiente es el primero.
    config.setScenario(AccelScenario.MANUAL);
    Test.assertEqual(config.nextScenario(), AccelScenario.NORMAL);
    return true;
}

(:test)
function demoConfigIgnoresInvalidScenario(logger as Logger) as Boolean {
    var config = new DemoConfig();
    config.setScenario(AccelScenario.NOD);
    config.setScenario(99 as AccelScenario.Id);
    Test.assertEqual(config.scenario(), AccelScenario.NOD);
    config.setScenario(-1 as AccelScenario.Id);
    Test.assertEqual(config.scenario(), AccelScenario.NOD);
    return true;
}

(:test)
function demoConfigRoundTripsThroughStorage(logger as Logger) as Boolean {
    var config = new DemoConfig();
    config.setEnabled(true);
    config.setScenario(AccelScenario.INACTIVITY);

    var restored = DemoConfig.fromStorage(config.toStorage());
    Test.assertMessage(restored.isEnabled(), "modo demo recuperado");
    Test.assertEqual(restored.scenario(), AccelScenario.INACTIVITY);
    Test.assertEqual(restored.inactivityMs(), 8000);

    config.setEnabled(false);
    config.setScenario(AccelScenario.TYPING);
    restored = DemoConfig.fromStorage(config.toStorage());
    Test.assertMessage(!restored.isEnabled(), "modo demo apagado recuperado");
    Test.assertEqualMessage(restored.scenario(), AccelScenario.TYPING,
        "el escenario se recuerda aunque el modo demo esté apagado");
    return true;
}

(:test)
function demoConfigFromInvalidStorageUsesDefaults(logger as Logger) as Boolean {
    var inputs = [
        null,
        "demo",
        42,
        {},
        { DemoConfig.KEY_ENABLED => "yes", DemoConfig.KEY_SCENARIO => 7 },
        { DemoConfig.KEY_ENABLED => 1, DemoConfig.KEY_SCENARIO => "2" }
    ] as Array<Object?>;
    for (var i = 0; i < inputs.size(); i++) {
        var config = DemoConfig.fromStorage(inputs[i]);
        Test.assertMessage(!config.isEnabled(), "entrada " + i + ": sin modo demo");
        Test.assertEqualMessage(config.scenario(), AccelScenario.NORMAL,
            "entrada " + i + ": movimiento normal");
    }

    // Un campo válido se conserva aunque el otro no lo sea.
    var partial = DemoConfig.fromStorage({ DemoConfig.KEY_ENABLED => true,
        DemoConfig.KEY_SCENARIO => 99 });
    Test.assertMessage(partial.isEnabled(), "el campo válido se conserva");
    Test.assertEqual(partial.scenario(), AccelScenario.NORMAL);
    return true;
}
