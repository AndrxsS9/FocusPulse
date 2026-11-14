import Toybox.Lang;
import Toybox.Test;

//! Pruebas de DetectorThresholds y del ajuste "Sensibilidad" en el detector.

(:test)
function sensitivityMediumKeepsPreviousThresholds(logger as Logger) as Boolean {
    var medium = new DetectorThresholds(SensitivityLevel.MEDIUM);
    Test.assertEqual(medium.nodJerkMin, DrowsinessDetector.NOD_JERK_MIN);
    Test.assertEqual(medium.nodTiltMin, DrowsinessDetector.NOD_TILT_MIN);
    Test.assertEqual(medium.inactivityMs, DrowsinessDetector.INACTIVITY_MS);
    Test.assertEqual(medium.inactivityDemoMs, DrowsinessDetector.INACTIVITY_DEMO_MS);
    // Un nivel fuera de rango vale como Media.
    Test.assertEqual(new DetectorThresholds(7 as SensitivityLevel.Id).nodJerkMin, 400);
    // El detector empieza con la sensibilidad media.
    Test.assertEqual(new DrowsinessDetector().thresholds().nodJerkMin, 400);
    return true;
}

(:test)
function sensitivityPresetsAreOrdered(logger as Logger) as Boolean {
    var low = new DetectorThresholds(SensitivityLevel.LOW);
    var medium = new DetectorThresholds(SensitivityLevel.MEDIUM);
    var high = new DetectorThresholds(SensitivityLevel.HIGH);
    // Más sensibilidad: menos sacudida, menos inclinación y menos tiempo inmóvil.
    Test.assertMessage(low.nodJerkMin > medium.nodJerkMin && medium.nodJerkMin > high.nodJerkMin,
        "sacudida: baja > media > alta");
    Test.assertMessage(low.nodTiltMin > medium.nodTiltMin && medium.nodTiltMin > high.nodTiltMin,
        "inclinación: baja > media > alta");
    Test.assertMessage(low.inactivityMs > medium.inactivityMs && medium.inactivityMs > high.inactivityMs,
        "inactividad: baja > media > alta");
    Test.assertMessage(low.inactivityDemoMs > medium.inactivityDemoMs
        && medium.inactivityDemoMs > high.inactivityDemoMs, "inactividad demo: baja > media > alta");
    Test.assertEqual(low.inactivityMs, 90000);
    Test.assertEqual(high.inactivityMs, 45000);
    Test.assertEqual(low.inactivityDemoMs, 12000);
    Test.assertEqual(high.inactivityDemoMs, 6000);
    return true;
}

(:test)
function sensitivityChangesInactivityTime(logger as Logger) as Boolean {
    var levels = [SensitivityLevel.LOW, SensitivityLevel.MEDIUM, SensitivityLevel.HIGH] as Array<SensitivityLevel.Id>;
    var expected = [12000, 8000, 6000] as Array<Number>;
    for (var i = 0; i < levels.size(); i++) {
        var rig = new DetectorRig(AccelScenario.INACTIVITY, 11, true);
        rig.detector.setSensitivity(levels[i]);
        rig.run(20);
        Test.assertEqualMessage(rig.firstInactivityMs as Number, expected[i],
            "sensibilidad " + (levels[i] as Number) + ": inactividad a los " + expected[i] + " ms");
        Test.assertEqual(rig.nods, 0);
    }
    return true;
}

(:test)
function sensitivityKeepsSimulatedNodAtEveryLevel(logger as Logger) as Boolean {
    // La demo tiene que dar el cabeceo con cualquier sensibilidad (pico ≈ 464 mg, 76°).
    var levels = [SensitivityLevel.LOW, SensitivityLevel.MEDIUM, SensitivityLevel.HIGH] as Array<SensitivityLevel.Id>;
    for (var i = 0; i < levels.size(); i++) {
        for (var seed = 1; seed <= 5; seed++) {
            var rig = new DetectorRig(AccelScenario.NOD, seed, true);
            rig.detector.setSensitivity(levels[i]);
            rig.run(8);
            Test.assertEqualMessage(rig.nods, 1,
                "sensibilidad " + (levels[i] as Number) + ", semilla " + seed + ": un cabeceo");
            Test.assertEqual(rig.firstNodMs as Number, 6000);
        }
    }
    return true;
}

(:test)
function sensitivityLowIgnoresWeakerFall(logger as Logger) as Boolean {
    // Una sacudida de 420 mg seguida de quietud con 40° de giro: cabeceo con la
    // sensibilidad media y alta, no con la baja (440 mg y 45°).
    var levels = [SensitivityLevel.LOW, SensitivityLevel.MEDIUM, SensitivityLevel.HIGH] as Array<SensitivityLevel.Id>;
    var expectedNods = [0, 1, 1] as Array<Number>;
    for (var i = 0; i < levels.size(); i++) {
        var detector = new DrowsinessDetector();
        detector.start(0, true);
        detector.setSensitivity(levels[i]);
        var nods = 0;
        // Lote 1–3: brazo quieto pero con movimiento normal (varianza 600 mg²).
        for (var t = 1; t <= 3; t++) {
            detector.update(DetectorRig.snapshot(600.0f, 30, 30, 0.0f, 0.0f, 1000.0f), t * 1000);
        }
        // Lote 4: sacudida de 420 mg.
        detector.update(DetectorRig.snapshot(600.0f, 420, 20, 0.0f, 0.0f, 1000.0f), 4000);
        // Lotes 5–8: quietud con la gravedad girada 40°.
        for (var t = 5; t <= 8; t++) {
            var event = detector.update(DetectorRig.snapshot(6.0f, 10, 10, 0.0f, 643.0f, 766.0f),
                t * 1000);
            if (event == DrowsinessEvent.NOD) {
                nods += 1;
            }
        }
        Test.assertEqualMessage(nods, expectedNods[i],
            "sensibilidad " + (levels[i] as Number) + ": " + expectedNods[i] + " cabeceos");
    }
    return true;
}
