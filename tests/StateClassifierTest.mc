import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

//! Pruebas de StateClassifier y ClassifierWeights: softmax, forma de la tabla, EMA,
//! clase ganadora por escenario y matriz de confusión sobre secuencias simuladas.

//! Probabilidades crudas de unas características escritas a mano.
function classifyFeatures(logVariance as Float, peakJerk as Number, stillSeconds as Float,
        tilt as Float, fallPending as Boolean) as Array<Float> {
    var features = new Array<Float>[StateClassifier.FEATURE_COUNT];
    StateClassifier.featuresInto(features, Math.pow(Math.E, logVariance).toFloat() - 1.0f, peakJerk,
        stillSeconds, tilt, fallPending);
    var p = new Array<Float>[DrowsinessClass.COUNT];
    StateClassifier.probabilitiesInto(p, features);
    return p;
}

//! Índice de la mayor probabilidad.
function argmax(values as Array<Float>) as Number {
    var best = 0;
    for (var k = 1; k < values.size(); k++) {
        if (values[k] > values[best]) {
            best = k;
        }
    }
    return best;
}

//! Clase real de un lote de un escenario simulado (para la matriz de confusión). En el
//! cabeceo depende del momento: Normal antes de la caída; Cabeceo desde el lote de la
//! caída hasta que la ventana de 2 s deja de contenerla; Inerte después (el usuario se
//! quedó dormido).
function trueClass(scenario as AccelScenario.Id, timeMs as Number) as DrowsinessClass.Id {
    if (scenario == AccelScenario.TYPING) {
        return DrowsinessClass.ACTIVE;
    }
    if (scenario == AccelScenario.INACTIVITY) {
        return DrowsinessClass.INERT;
    }
    if (scenario != AccelScenario.NOD || timeMs < NOD_DROP_MS) {
        return DrowsinessClass.NORMAL;
    }
    var profile = SimulatedAccelSource.NOD_PROFILE as Array<Number>;
    var dropEndMs = (SimulatedAccelSource.NOD_LEAD_SAMPLES + profile.size()) * 1000
        / SlidingWindow.SAMPLE_RATE_HZ;
    if (timeMs < dropEndMs + SlidingWindow.WINDOW_SECONDS * 1000) {
        return DrowsinessClass.NOD;
    }
    return DrowsinessClass.INERT;
}

(:test)
function classifierWeightTableHasTheRightShape(logger as Logger) as Boolean {
    var coef = ClassifierWeights.COEF as Array<Array<Float>>;
    Test.assertEqual(coef.size(), DrowsinessClass.COUNT);
    for (var k = 0; k < coef.size(); k++) {
        Test.assertEqual(coef[k].size(), StateClassifier.FEATURE_COUNT);
    }
    Test.assertEqual((ClassifierWeights.INTERCEPT as Array<Float>).size(), DrowsinessClass.COUNT);
    var scale = ClassifierWeights.FEATURE_SCALE as Array<Float>;
    Test.assertEqual(scale.size(), StateClassifier.FEATURE_COUNT);
    Test.assertEqual((ClassifierWeights.FEATURE_MEAN as Array<Float>).size(), StateClassifier.FEATURE_COUNT);
    for (var j = 0; j < scale.size(); j++) {
        Test.assert(scale[j] > 0.0f);
    }
    return true;
}

(:test)
function classifierSoftmaxSeparatesTypicalFeatures(logger as Logger) as Boolean {
    var typing = classifyFeatures(9.6f, 550, 0.0f, 1.5f, false);
    var normal = classifyFeatures(6.6f, 120, 0.0f, 0.3f, false);
    var nod = classifyFeatures(7.4f, 10, 0.0f, 70.0f, true);
    var inert = classifyFeatures(2.0f, 10, 5.0f, 0.0f, false);

    var sum = 0.0f;
    for (var k = 0; k < DrowsinessClass.COUNT; k++) {
        Test.assert(typing[k] >= 0.0f && typing[k] <= 1.0f);
        sum += typing[k];
    }
    Test.assert(nearlyEqual(sum, 1.0f, 0.0001f));

    Test.assertEqual(argmax(typing), DrowsinessClass.ACTIVE);
    Test.assertEqual(argmax(normal), DrowsinessClass.NORMAL);
    Test.assertEqual(argmax(nod), DrowsinessClass.NOD);
    Test.assertEqual(argmax(inert), DrowsinessClass.INERT);
    Test.assert(normal[DrowsinessClass.NORMAL] > 0.9f);

    // Girar la muñeca para mirar la hora: inclinación grande pero sin caída pendiente.
    Test.assertEqual(argmax(classifyFeatures(6.8f, 250, 0.0f, 90.0f, false)), DrowsinessClass.NORMAL);
    // Quien apenas se mueve (≈ 200 mg²) sigue siendo Normal, no Inerte.
    Test.assertEqual(argmax(classifyFeatures(5.3f, 60, 0.0f, 0.2f, false)), DrowsinessClass.NORMAL);
    // Valores extremos: sin desbordes.
    var extreme = classifyFeatures(12.0f, 8000, 1000.0f, 180.0f, true);
    Test.assert(nearlyEqual(extreme[0] + extreme[1] + extreme[2] + extreme[3], 1.0f, 0.0001f));
    return true;
}

(:test)
function classifierSmoothsProbabilitiesWithEma(logger as Logger) as Boolean {
    var rig = new DetectorRig(AccelScenario.TYPING, SIM_TEST_SEED, true);
    Test.assertEqual(rig.classifier.topClass(), DrowsinessClass.NORMAL);
    Test.assert(nearlyEqual(rig.classifier.probability(DrowsinessClass.NORMAL), 1.0f, 0.0001f));

    // Primer lote: la ventana no está llena y nada cambia.
    rig.step();
    Test.assert(!rig.classifier.isReady());
    Test.assert(nearlyEqual(rig.classifier.probability(DrowsinessClass.NORMAL), 1.0f, 0.0001f));

    // Segundo: p = SMOOTHING × cruda + (1 − SMOOTHING) × anterior.
    rig.step();
    Test.assert(rig.classifier.isReady());
    var raw = rig.classifier.rawProbabilities();
    var a = StateClassifier.SMOOTHING;
    Test.assert(nearlyEqual(rig.classifier.probability(DrowsinessClass.ACTIVE),
        a * raw[DrowsinessClass.ACTIVE], 0.0001f));
    Test.assert(nearlyEqual(rig.classifier.probability(DrowsinessClass.NORMAL),
        a * raw[DrowsinessClass.NORMAL] + (1.0f - a), 0.0001f));

    rig.classifier.reset();
    Test.assertEqual(rig.classifier.topClass(), DrowsinessClass.NORMAL);
    Test.assert(!rig.classifier.isReady());
    return true;
}

(:test)
function classifierTopClassMatchesScenario(logger as Logger) as Boolean {
    var scenarios = [AccelScenario.TYPING, AccelScenario.NORMAL, AccelScenario.INACTIVITY] as Array<AccelScenario.Id>;
    var expected = [DrowsinessClass.ACTIVE, DrowsinessClass.NORMAL, DrowsinessClass.INERT] as Array<DrowsinessClass.Id>;
    for (var i = 0; i < scenarios.size(); i++) {
        var rig = new DetectorRig(scenarios[i], SIM_TEST_SEED, true);
        rig.run(10);
        var p = rig.classifier.probabilities();
        logger.debug("escenario " + scenarios[i] + ": " + p);
        Test.assertEqual(rig.classifier.topClass(), expected[i]);
        Test.assert(p[expected[i] as Number] > 0.9f);
    }

    // Cabeceo: Cabeceo gana mientras se verifica la quietud tras la caída, y después
    // Inerte (brazo colgando).
    var nod = new DetectorRig(AccelScenario.NOD, SIM_TEST_SEED, true);
    nod.run(3);
    Test.assertEqual(nod.classifier.topClass(), DrowsinessClass.NORMAL);
    nod.run(2);
    Test.assert(nod.detector.isFallPending());
    logger.debug("cabeceo pendiente: " + nod.classifier.probabilities());
    Test.assertEqual(nod.classifier.topClass(), DrowsinessClass.NOD);
    nod.run(5);
    Test.assertEqual(nod.classifier.topClass(), DrowsinessClass.INERT);
    return true;
}

(:test)
function classifierConfusionMatrixOnSimulatedScenarios(logger as Logger) as Boolean {
    var scenarios = [AccelScenario.TYPING, AccelScenario.NORMAL, AccelScenario.NOD,
        AccelScenario.INACTIVITY] as Array<AccelScenario.Id>;
    var seconds = [40, 40, 15, 40];
    var seeds = 5;

    // matrix[real][predicha]
    var matrix = new Array<Array<Number>>[DrowsinessClass.COUNT];
    for (var k = 0; k < DrowsinessClass.COUNT; k++) {
        matrix[k] = [0, 0, 0, 0];
    }

    for (var s = 0; s < seeds; s++) {
        var seed = SIM_TEST_SEED + s * 7919;
        for (var i = 0; i < scenarios.size(); i++) {
            var rig = new DetectorRig(scenarios[i], seed, true);
            for (var n = 0; n < seconds[i]; n++) {
                rig.step();
                rig.countInto(matrix, trueClass(scenarios[i], rig.timeMs));
            }
        }

        // Secuencia mixta en una misma guardia: normal → tecleo → normal → inactividad,
        // 10 s cada uno (15 la inactividad). La clase real es la del escenario en curso,
        // así que el retraso de la ventana de 2 s y de la EMA cuenta como error.
        var mixed = new DetectorRig(AccelScenario.NORMAL, seed + 1, true);
        var plan = [AccelScenario.NORMAL, AccelScenario.TYPING, AccelScenario.NORMAL,
            AccelScenario.INACTIVITY] as Array<AccelScenario.Id>;
        for (var n = 0; n < 45; n++) {
            var phase = plan[n / 10 < 3 ? n / 10 : 3];
            if (phase != mixed.source.scenario()) {
                mixed.source.setScenario(phase);
            }
            mixed.step();
            mixed.countInto(matrix, trueClass(phase, mixed.timeMs));
        }
    }

    var names = ["Activo ", "Normal ", "Cabeceo", "Inerte "];
    logger.debug("Matriz de confusión (" + ClassifierWeights.VERSION + ", " + seeds
        + " semillas, lotes de 1 s). Filas: clase real; columnas: predicha");
    logger.debug("           Activo  Normal Cabeceo  Inerte | acierto");
    var correct = 0;
    var total = 0;
    for (var real = 0; real < DrowsinessClass.COUNT; real++) {
        var row = matrix[real];
        var rowTotal = row[0] + row[1] + row[2] + row[3];
        correct += row[real];
        total += rowTotal;
        logger.debug(names[real] + "    " + row[0].format("%6d") + "  " + row[1].format("%6d") + "  "
            + row[2].format("%6d") + "  " + row[3].format("%6d") + " | "
            + (100.0f * row[real] / rowTotal).format("%.1f") + " %");
        // En cada fila gana la diagonal.
        for (var k = 0; k < DrowsinessClass.COUNT; k++) {
            Test.assert(row[real] >= row[k]);
        }
    }
    var accuracy = correct.toFloat() / total;
    logger.debug("Exactitud global: " + correct + " de " + total + " = " + (100.0f * accuracy).format("%.1f") + " %");
    Test.assert(accuracy > 0.9f);
    // Nunca se confunden los extremos: tecleo con inerte ni al revés.
    Test.assertEqual(matrix[DrowsinessClass.ACTIVE][DrowsinessClass.INERT], 0);
    Test.assertEqual(matrix[DrowsinessClass.INERT][DrowsinessClass.ACTIVE], 0);
    return true;
}
