import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

//! Cambiar de escenario en la demo (DOWN) no debe dar eventos de más: la fuente simulada
//! pasa de una postura a otra con una transición de 1,5 s, no de golpe (fase 11).

(:test)
function scenarioSwitchNodToInactivityHasNoExtraNod(logger as Logger) as Boolean {
    // Antes: salto de ≈ 1 200 mg y 75° en una muestra y un cabeceo de más ≈ 4 s después.
    for (var seed = 1; seed <= 5; seed++) {
        var rig = new DetectorRig(AccelScenario.NOD, seed, true);
        rig.run(12);
        Test.assertEqualMessage(rig.nods, 1, "semilla " + seed + ": el cabeceo del escenario");
        var peak = 0;
        rig.source.setScenario(AccelScenario.INACTIVITY);
        for (var i = 0; i < 25; i++) {
            rig.step();
            var jerk = rig.engine.snapshot().batchPeakJerk;
            peak = jerk > peak ? jerk : peak;
        }
        logger.debug("semilla " + seed + ": sacudida máxima al cambiar " + peak + " mg, eventos "
            + rig.eventTimes);
        Test.assertMessage(peak < 100, "semilla " + seed + ": sin sacudida al cambiar (" + peak + " mg)");
        Test.assertEqualMessage(rig.nods, 1, "semilla " + seed + ": ningún cabeceo al cambiar");
        Test.assertEqualMessage(rig.alertNods, 1, "semilla " + seed + ": ninguna alerta de cabeceo de más");
        Test.assertMessage(rig.inactivities >= 1, "semilla " + seed + ": sí llega la inactividad");
    }
    return true;
}

(:test)
function scenarioSwitchFullDownCycleOnlyNodsOnce(logger as Logger) as Boolean {
    // Un recorrido completo con DOWN (normal → tecleo → cabeceo → inactividad → mirar la
    // hora → normal), 15 s en cada uno: solo el escenario de cabeceo da un cabeceo, y al
    // pasar de leer la hora a normal el clasificador no ve ningún lote Cabeceo.
    for (var seed = 1; seed <= 3; seed++) {
        var rig = new DetectorRig(AccelScenario.NORMAL, seed, true);
        rig.run(15);
        var scenario = AccelScenario.NORMAL;
        for (var k = 0; k < 5; k++) {
            scenario = DemoConfig.scenarioAfter(scenario);
            var nodsBefore = rig.nods;
            var classNods = 0;
            rig.source.setScenario(scenario);
            for (var i = 0; i < 15; i++) {
                rig.step();
                if (scenario == AccelScenario.NORMAL && rig.classifier.topClass() == DrowsinessClass.NOD) {
                    classNods += 1;
                }
            }
            var expected = scenario == AccelScenario.NOD ? 1 : 0;
            Test.assertEqualMessage(rig.nods - nodsBefore, expected, "semilla " + seed + ", escenario "
                + (scenario as Number) + ": " + expected + " cabeceos");
            Test.assertEqualMessage(classNods, 0, "semilla " + seed + ": mirar la hora → normal sin Cabeceo");
        }
        Test.assertEqual(rig.alertNods, 1);
    }
    return true;
}

(:test)
function scenarioSwitchSlidesThePosture(logger as Logger) as Boolean {
    var source = new SimulatedAccelSource(AccelScenario.INACTIVITY, 7);
    // Sin muestras previas no hay transición: empieza en la postura del escenario.
    source.setScenario(AccelScenario.NOD);
    Test.assertMessage(!source.isInTransition(), "fuente nueva: sin transición");
    // 10 s de cabeceo: la caída y varios segundos con el brazo colgando.
    source.nextBatch(250);
    // Brazo colgando → inactividad: la gravedad se desliza muestra a muestra.
    source.setScenario(AccelScenario.INACTIVITY);
    Test.assertMessage(source.isInTransition(), "transición en curso");
    var batch = source.nextBatch(SimulatedAccelSource.TRANSITION_SAMPLES + 5);
    var maxStep = 0;
    for (var i = 1; i < batch[0].size(); i++) {
        var dx = batch[0][i] - batch[0][i - 1];
        var dy = batch[1][i] - batch[1][i - 1];
        var dz = batch[2][i] - batch[2][i - 1];
        var step = Math.sqrt(dx * dx + dy * dy + dz * dz).toNumber();
        maxStep = step > maxStep ? step : maxStep;
    }
    logger.debug("paso máximo entre muestras en la transición: " + maxStep + " mg");
    Test.assertMessage(maxStep < 60, "paso máximo " + maxStep + " mg (antes ≈ 1 200 mg)");
    // Al empezar sigue cerca del brazo colgando; al terminar, en la postura inerte.
    Test.assert((batch[1][0] - SimulatedAccelSource.NOD_TO_Y).abs() < 60);
    var last = batch[1].size() - 1;
    Test.assert((batch[1][last] - SimulatedAccelSource.INERT_Y).abs() <= SimulatedAccelSource.INERT_NOISE);
    Test.assertMessage(!source.isInTransition(), "terminó tras TRANSITION_SAMPLES muestras");
    return true;
}
