import Toybox.Lang;
import Toybox.Test;

//! Pruebas de AlertnessScore (source/core): objetivo según las probabilidades del
//! clasificador, dirección según el escenario, límites, pausa e independencia de dt.
//! Combina probabilidades escritas a mano con los escenarios de SimulatedAccelSource
//! pasados por el banco del detector (DetectorRig), como hace GuardController.

//! Probabilidades en el orden de DrowsinessClass.
function classProbabilities(active as Float, normal as Float, nod as Float, inert as Float) as Array<Float> {
    return [active, normal, nod, inert] as Array<Float>;
}

//! Todo inerte: objetivo 10.
function inertProbabilities() as Array<Float> {
    return classProbabilities(0.0f, 0.0f, 0.0f, 1.0f);
}

//! Puntaje activo (recién reiniciado) llevado a value (≥ 10) con probabilidades de
//! inerte: se usa para partir de valores distintos de 88.
function scoreAt(value as Float) as AlertnessScore {
    var score = new AlertnessScore();
    score.reset();
    score.update(inertProbabilities(), (AlertnessScore.INITIAL - value) / AlertnessScore.DROP_PER_S);
    return score;
}

(:test)
function alertnessTargetWeighsClassLevels(logger as Logger) as Boolean {
    Test.assert(nearlyEqual(AlertnessScore.targetFor(classProbabilities(1.0f, 0.0f, 0.0f, 0.0f)), 100.0f, 0.001f));
    Test.assert(nearlyEqual(AlertnessScore.targetFor(classProbabilities(0.0f, 1.0f, 0.0f, 0.0f)), 85.0f, 0.001f));
    Test.assert(nearlyEqual(AlertnessScore.targetFor(classProbabilities(0.0f, 0.0f, 1.0f, 0.0f)), 0.0f, 0.001f));
    Test.assert(nearlyEqual(AlertnessScore.targetFor(inertProbabilities()), 10.0f, 0.001f));
    Test.assert(nearlyEqual(AlertnessScore.targetFor(classProbabilities(0.5f, 0.5f, 0.0f, 0.0f)), 92.5f, 0.001f));
    return true;
}

(:test)
function alertnessScoreStartsAt88AndFrozen(logger as Logger) as Boolean {
    var score = new AlertnessScore();
    Test.assertEqual(score.value(), 88);
    Test.assert(!score.isActive());

    // Antes de iniciar la guardia no cambia.
    score.update(inertProbabilities(), 10.0f);
    Test.assertEqual(score.value(), 88);

    score.reset();
    Test.assert(score.isActive());
    Test.assertEqual(score.value(), 88);
    return true;
}

(:test)
function alertnessScoreRisesWithTyping(logger as Logger) as Boolean {
    var rig = new DetectorRig(AccelScenario.TYPING, SIM_TEST_SEED, true);
    rig.score = scoreAt(60.0f);
    rig.run(6);
    var result = rig.score.value();
    logger.debug("tecleo: 60 → " + result);
    // El clasificador opina desde el segundo lote; desde ahí sube 3 puntos por segundo.
    Test.assert(result >= 60 + 4 * 3);
    Test.assert(result <= 60 + 5 * 3);
    return true;
}

(:test)
function alertnessScoreDropsGraduallyWhenStill(logger as Logger) as Boolean {
    var rig = new DetectorRig(AccelScenario.INACTIVITY, SIM_TEST_SEED, true);
    rig.run(5);
    var after5 = rig.score.value();
    rig.run(15);
    var after20 = rig.score.value();
    logger.debug("inactividad: 88 → " + after5 + " → " + after20);

    Test.assert(after5 < 88);
    Test.assert(after20 < after5);
    // Gradual: 2 puntos por segundo, nunca de golpe.
    Test.assert(after5 >= 88 - 4 * 2);
    Test.assert(AlertnessColors.bandForScore(after20) != AlertnessColors.BAND_HIGH);
    return true;
}

(:test)
function alertnessScoreDropsAfterNod(logger as Logger) as Boolean {
    var rig = new DetectorRig(AccelScenario.NOD, SIM_TEST_SEED, true);
    rig.run(3);
    var before = rig.score.value();
    rig.run(12);
    logger.debug("cabeceo: " + before + " → " + rig.score.value());
    Test.assert(rig.score.value() < before - 20);
    return true;
}

(:test)
function alertnessScoreTendsTo85WithNormalMovement(logger as Logger) as Boolean {
    // Desde arriba.
    var high = new DetectorRig(AccelScenario.NORMAL, SIM_TEST_SEED, true);
    high.run(8);
    logger.debug("normal desde 88: " + high.score.exactValue());
    Test.assert(within(high.score.value(), 85, 3));

    // Desde abajo.
    var low = new DetectorRig(AccelScenario.NORMAL, SIM_TEST_SEED, true);
    low.score = scoreAt(40.0f);
    low.run(12);
    var partial = low.score.value();
    logger.debug("normal desde 40: " + partial);
    Test.assert(partial > 40 && partial < 80);
    low.run(28);
    Test.assert(within(low.score.value(), 85, 3));
    return true;
}

(:test)
function alertnessScoreStaysWithinLimits(logger as Logger) as Boolean {
    var score = new AlertnessScore();
    score.reset();
    var active = classProbabilities(1.0f, 0.0f, 0.0f, 0.0f);
    score.update(active, 1000.0f);
    Test.assertEqual(score.value(), 100);
    score.update(active, 5.0f);
    Test.assertEqual(score.value(), 100);

    var nod = classProbabilities(0.0f, 0.0f, 1.0f, 0.0f);
    score.update(nod, 1000.0f);
    Test.assertEqual(score.value(), 0);
    score.update(nod, 5.0f);
    Test.assertEqual(score.value(), 0);
    return true;
}

(:test)
function alertnessScoreFreezesWhilePaused(logger as Logger) as Boolean {
    var score = new AlertnessScore();
    score.reset();
    score.update(inertProbabilities(), 5.0f);
    var frozen = score.value();

    score.setActive(false);
    score.update(inertProbabilities(), 30.0f);
    score.update(classProbabilities(1.0f, 0.0f, 0.0f, 0.0f), 30.0f);
    Test.assertEqual(score.value(), frozen);

    // Al reanudar sin reiniciar sigue desde el mismo valor.
    score.setActive(true);
    score.update(inertProbabilities(), 1.0f);
    Test.assertEqual(score.value(), frozen - 2);
    return true;
}

(:test)
function alertnessScoreWaitsForTheClassifier(logger as Logger) as Boolean {
    var score = new AlertnessScore();
    score.reset();
    score.update(null, 10.0f);
    Test.assertEqual(score.value(), 88);
    return true;
}

(:test)
function alertnessScoreIsIndependentOfDt(logger as Logger) as Boolean {
    var cases = [classProbabilities(0.9f, 0.1f, 0.0f, 0.0f), inertProbabilities(),
        classProbabilities(0.05f, 0.9f, 0.0f, 0.05f)] as Array<Array<Float>>;
    for (var k = 0; k < cases.size(); k++) {
        var coarse = scoreAt(50.0f);
        var fine = scoreAt(50.0f);
        coarse.update(cases[k], 4.0f);
        for (var i = 0; i < 10; i++) {
            fine.update(cases[k], 0.4f);
        }
        logger.debug("dt 4 s: " + coarse.exactValue() + "  10 × 0,4 s: " + fine.exactValue());
        Test.assert(nearlyEqual(coarse.exactValue(), fine.exactValue(), 0.01f));
    }
    return true;
}
