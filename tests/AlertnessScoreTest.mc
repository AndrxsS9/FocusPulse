import Toybox.Lang;
import Toybox.Test;

//! Pruebas de AlertnessScore (source/core): dirección según la actividad, límites,
//! pausa e independencia de dt. Combina snapshots armados a mano con los escenarios
//! de SimulatedAccelSource pasados por TelemetryEngine.

//! Snapshot con la ventana llena y la varianza dada.
function scoreSnapshot(variance as Float) as TelemetrySnapshot {
    var s = new TelemetrySnapshot();
    s.windowFull = true;
    s.variance = variance;
    s.isStill = variance < SlidingWindow.STILL_VARIANCE_MAX;
    return s;
}

//! Puntaje activo (recién reiniciado) llevado a value aplicando el escenario
//! correspondiente: se usa para partir de valores distintos de 88.
function scoreAt(value as Float) as AlertnessScore {
    var score = new AlertnessScore();
    score.reset();
    var still = scoreSnapshot(5.0f);
    score.update(still, (AlertnessScore.INITIAL - value) / AlertnessScore.STILL_DROP_PER_S);
    return score;
}

//! Pasa seconds segundos del escenario por un motor y actualiza el puntaje con cada
//! lote de 1 s, como hace GuardController.
function scoreScenario(score as AlertnessScore, scenario as AccelScenario.Id,
        seconds as Number) as Number {
    var source = new SimulatedAccelSource(scenario, SIM_TEST_SEED);
    var engine = new TelemetryEngine();
    var t = 1000;
    for (var i = 0; i < seconds; i++) {
        t = feedSeconds(source, engine, 1, t);
        score.update(engine.snapshot(), 1.0f);
    }
    return score.value();
}

(:test)
function alertnessScoreStartsAt88AndFrozen(logger as Logger) as Boolean {
    var score = new AlertnessScore();
    Test.assertEqual(score.value(), 88);
    Test.assert(!score.isActive());

    // Antes de iniciar la guardia no cambia.
    score.update(scoreSnapshot(5.0f), 10.0f);
    Test.assertEqual(score.value(), 88);

    score.reset();
    Test.assert(score.isActive());
    Test.assertEqual(score.value(), 88);
    return true;
}

(:test)
function alertnessScoreRisesWithTyping(logger as Logger) as Boolean {
    var score = scoreAt(60.0f);
    var result = scoreScenario(score, AccelScenario.TYPING, 6);
    logger.debug("tecleo: 60 → " + result);
    // La ventana se llena con el segundo lote; desde ahí sube 3 puntos por segundo.
    Test.assert(result >= 60 + 4 * 3);
    Test.assert(result <= 60 + 5 * 3);
    return true;
}

(:test)
function alertnessScoreDropsGraduallyWhenStill(logger as Logger) as Boolean {
    var score = new AlertnessScore();
    score.reset();
    var after5 = scoreScenario(score, AccelScenario.INACTIVITY, 5);
    var after15 = scoreScenario(score, AccelScenario.INACTIVITY, 15);
    logger.debug("inactividad: 88 → " + after5 + " → " + after15);

    Test.assert(after5 < 88);
    Test.assert(after15 < after5);
    // Gradual: 2 puntos por segundo, nunca de golpe.
    Test.assert(after5 >= 88 - 5 * 2);
    Test.assert(AlertnessColors.bandForScore(after15) != AlertnessColors.BAND_HIGH);
    return true;
}

(:test)
function alertnessScoreTendsTo85WithNormalMovement(logger as Logger) as Boolean {
    // Desde arriba.
    var high = new AlertnessScore();
    high.reset();
    Test.assertEqual(scoreScenario(high, AccelScenario.NORMAL, 8), 85);

    // Desde abajo.
    var low = scoreAt(40.0f);
    var partial = scoreScenario(low, AccelScenario.NORMAL, 12);
    logger.debug("normal desde 40: " + partial);
    Test.assert(partial > 40 && partial < 85);
    Test.assertEqual(scoreScenario(low, AccelScenario.NORMAL, 40), 85);
    return true;
}

(:test)
function alertnessScoreStaysWithinLimits(logger as Logger) as Boolean {
    var score = new AlertnessScore();
    score.reset();
    score.update(scoreSnapshot(20000.0f), 1000.0f);
    Test.assertEqual(score.value(), 100);
    score.update(scoreSnapshot(20000.0f), 5.0f);
    Test.assertEqual(score.value(), 100);

    score.update(scoreSnapshot(3.0f), 1000.0f);
    Test.assertEqual(score.value(), 0);
    score.update(scoreSnapshot(3.0f), 5.0f);
    Test.assertEqual(score.value(), 0);
    return true;
}

(:test)
function alertnessScoreFreezesWhilePaused(logger as Logger) as Boolean {
    var score = new AlertnessScore();
    score.reset();
    score.update(scoreSnapshot(3.0f), 5.0f);
    var frozen = score.value();

    score.setActive(false);
    score.update(scoreSnapshot(3.0f), 30.0f);
    score.update(scoreSnapshot(20000.0f), 30.0f);
    Test.assertEqual(score.value(), frozen);

    // Al reanudar sin reiniciar sigue desde el mismo valor.
    score.setActive(true);
    score.update(scoreSnapshot(3.0f), 1.0f);
    Test.assertEqual(score.value(), frozen - 2);
    return true;
}

(:test)
function alertnessScoreIgnoresIncompleteWindow(logger as Logger) as Boolean {
    var score = new AlertnessScore();
    score.reset();
    var s = scoreSnapshot(3.0f);
    s.windowFull = false;
    s.isStill = false;
    score.update(s, 10.0f);
    Test.assertEqual(score.value(), 88);
    return true;
}

(:test)
function alertnessScoreIsIndependentOfDt(logger as Logger) as Boolean {
    var snapshots = [scoreSnapshot(3000.0f), scoreSnapshot(5.0f), scoreSnapshot(600.0f)]
        as Array<TelemetrySnapshot>;
    for (var k = 0; k < snapshots.size(); k++) {
        var coarse = scoreAt(50.0f);
        var fine = scoreAt(50.0f);
        coarse.update(snapshots[k], 4.0f);
        for (var i = 0; i < 10; i++) {
            fine.update(snapshots[k], 0.4f);
        }
        logger.debug("dt 4 s: " + coarse.exactValue() + "  10 × 0,4 s: " + fine.exactValue());
        Test.assert(nearlyEqual(coarse.exactValue(), fine.exactValue(), 0.01f));
    }
    return true;
}
