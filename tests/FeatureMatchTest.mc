import Toybox.Lang;
import Toybox.Test;

//! Equivalencia de características entre Python (ml/features.py) y el reloj.
//!
//! FeatureVectors.mc lo genera ml/test_vectors.py: unas muestras fijas, el evento del
//! detector de cada lote y las 5 características de cada ventana llena según Python.
//! Aquí se pasan las mismas muestras por la cadena del reloj (TelemetryEngine →
//! DrowsinessDetector → StateClassifier.featuresInto, como GuardController.onBatch) y
//! se compara. Si falla, el modelo entrenado en Python no vería lo mismo que el reloj.

//! Tolerancia de cada característica: ln(varianza + 1), sacudida (mg, exacta), quietud
//! (s), inclinación (grados) y caída pendiente (exacta). Python imita el Float de 32
//! bits, así que las diferencias son de redondeo.
(:debug)
const FEATURE_TOLERANCE = [0.001f, 0.0f, 0.001f, 0.01f, 0.0f];

//! Une las filas de FeatureVectors (el compilador no admite literales muy largos).
(:debug)
function flattenRows(rows as Array<Array<Number or Float>>) as Array<Number or Float> {
    var out = [] as Array<Number or Float>;
    for (var i = 0; i < rows.size(); i++) {
        out.addAll(rows[i]);
    }
    return out;
}

(:test)
function featuresMatchPythonVectors(logger as Logger) as Boolean {
    var starts = FeatureVectors.STARTS as Array<Number>;
    var demo = FeatureVectors.DEMO as Array<Boolean>;
    var xs = flattenRows(FeatureVectors.X as Array<Array<Number or Float>>) as Array<Number>;
    var ys = flattenRows(FeatureVectors.Y as Array<Array<Number or Float>>) as Array<Number>;
    var zs = flattenRows(FeatureVectors.Z as Array<Array<Number or Float>>) as Array<Number>;
    var events = flattenRows(FeatureVectors.EVENTS as Array<Array<Number or Float>>) as Array<Number>;
    var expected = flattenRows(FeatureVectors.FEATURES as Array<Array<Number or Float>>) as Array<Float>;
    var tolerance = FEATURE_TOLERANCE as Array<Float>;
    var batch = SlidingWindow.SAMPLE_RATE_HZ;

    var features = new Array<Float>[StateClassifier.FEATURE_COUNT];
    var maxDiff = [0.0f, 0.0f, 0.0f, 0.0f, 0.0f] as Array<Float>;
    var windows = 0;
    var batches = 0;
    var nods = 0;
    for (var s = 0; s < demo.size(); s++) {
        var engine = new TelemetryEngine();
        var detector = new DrowsinessDetector();
        detector.start(0, demo[s]);
        var count = (starts[s + 1] - starts[s]) / batch;
        for (var k = 0; k < count; k++) {
            var from = starts[s] + k * batch;
            var timeMs = (k + 1) * 1000;
            engine.addBatch(xs.slice(from, from + batch), ys.slice(from, from + batch),
                zs.slice(from, from + batch), timeMs);
            var snapshot = engine.snapshot();
            var event = detector.update(snapshot, timeMs);
            Test.assertEqualMessage(event as Number, events[batches],
                "evento distinto en la secuencia " + s + ", lote " + (k + 1));
            if (event == DrowsinessEvent.NOD) {
                nods += 1;
            }
            batches += 1;
            if (!snapshot.windowFull) {
                continue;
            }
            StateClassifier.featuresInto(features, snapshot.variance, snapshot.batchPeakJerk,
                detector.stillSeconds(), detector.tiltDegrees(), detector.isFallPending());
            for (var j = 0; j < StateClassifier.FEATURE_COUNT; j++) {
                var diff = features[j] - expected[windows * StateClassifier.FEATURE_COUNT + j];
                if (diff < 0.0f) {
                    diff = -diff;
                }
                if (diff > maxDiff[j]) {
                    maxDiff[j] = diff;
                }
                Test.assertMessage(diff <= tolerance[j], "característica " + j + " distinta en la secuencia "
                    + s + ", lote " + (k + 1) + ": reloj " + features[j] + ", Python "
                    + expected[windows * StateClassifier.FEATURE_COUNT + j]);
            }
            windows += 1;
        }
    }
    logger.debug("Equivalencia Python/Monkey C: " + batches + " lotes, " + windows
        + " ventanas, " + nods + " cabeceos; diferencia máxima por característica " + maxDiff);
    Test.assertEqual(batches, events.size());
    Test.assertEqual(windows * StateClassifier.FEATURE_COUNT, expected.size());
    // Las secuencias recorren el caso del cabeceo, no solo movimiento.
    Test.assert(nods >= 1);
    return true;
}
