import Toybox.Lang;
import Toybox.Test;

//! Pruebas de TelemetryEngine (source/core): snapshot, frecuencia efectiva,
//! pico de sacudida por lote y reset.

//! Arreglo de n copias de value.
(:debug)
function repeatValue(n as Number, value as Number) as Array<Number> {
    var a = new Array<Number>[n];
    for (var i = 0; i < n; i++) {
        a[i] = value;
    }
    return a;
}

(:test)
function telemetryEngineSnapshotStartsEmpty(logger as Logger) as Boolean {
    var engine = new TelemetryEngine();
    var s = engine.snapshot();
    Test.assertEqual(s.samplesReceived, 0);
    Test.assertEqual(s.batchesReceived, 0);
    Test.assert(!s.windowFull);
    Test.assert(!s.isStill);
    Test.assert(nearlyEqual(s.effectiveHz, 0.0f, 0.001f));
    return true;
}

(:test)
function telemetryEngineReportsLastSampleAndCounts(logger as Logger) as Boolean {
    var engine = new TelemetryEngine();
    engine.addBatch([1, 2, 3] as Array<Number>, [4, 5, 6] as Array<Number>,
        [1000, 1001, 1002] as Array<Number>, 1000);
    var s = engine.snapshot();
    Test.assertEqual(s.x, 3);
    Test.assertEqual(s.y, 6);
    Test.assertEqual(s.z, 1002);
    Test.assertEqual(s.samplesReceived, 3);
    Test.assertEqual(s.batchesReceived, 1);

    // Si los ejes tienen distinto tamaño se usa el menor; un lote vacío se ignora.
    engine.addBatch([7, 8] as Array<Number>, [9] as Array<Number>, [10, 11] as Array<Number>, 2000);
    engine.addBatch([] as Array<Number>, [] as Array<Number>, [] as Array<Number>, 3000);
    s = engine.snapshot();
    Test.assertEqual(s.samplesReceived, 4);
    Test.assertEqual(s.batchesReceived, 2);
    Test.assertEqual(s.x, 7);
    return true;
}

(:test)
function telemetryEngineMeasuresEffectiveRate(logger as Logger) as Boolean {
    var engine = new TelemetryEngine();
    var rate = SlidingWindow.SAMPLE_RATE_HZ;
    var t = 5000;
    for (var i = 0; i < 4; i++) {
        engine.addBatch(repeatValue(rate, 0), repeatValue(rate, 0), repeatValue(rate, 1000), t);
        t += 1000;
    }
    Test.assert(nearlyEqual(engine.effectiveHz(), rate.toFloat(), 0.01f));

    // Lotes de 10 muestras por segundo (app inactiva sin grabar): la media baja.
    for (var i = 0; i < 6; i++) {
        engine.addBatch(repeatValue(10, 0), repeatValue(10, 0), repeatValue(10, 1000), t);
        t += 1000;
    }
    // (3 × 25 + 6 × 10) muestras en 9 s = 15 Hz.
    Test.assert(nearlyEqual(engine.effectiveHz(), 15.0f, 0.01f));
    return true;
}

(:test)
function telemetryEngineKeepsBatchPeakJerk(logger as Logger) as Boolean {
    var engine = new TelemetryEngine();
    var rate = SlidingWindow.SAMPLE_RATE_HZ;
    var zs = repeatValue(rate, 1000);

    // Pico de 600 mg al principio del lote: fuera de las 10 últimas muestras.
    zs[2] = 1600;
    engine.addBatch(repeatValue(rate, 0), repeatValue(rate, 0), zs, 1000);
    var s = engine.snapshot();
    Test.assertEqual(s.jerk, 0);
    Test.assertEqual(s.batchPeakJerk, 600);

    // El siguiente lote tranquilo deja el pico en 0.
    engine.addBatch(repeatValue(rate, 0), repeatValue(rate, 0), repeatValue(rate, 1000), 2000);
    Test.assertEqual(engine.snapshot().batchPeakJerk, 0);
    return true;
}

(:test)
function telemetryEngineSpreadsSampleTimesForStillness(logger as Logger) as Boolean {
    var engine = new TelemetryEngine();
    var rate = SlidingWindow.SAMPLE_RATE_HZ;
    var t = 1000;
    for (var i = 0; i < 5; i++) {
        engine.addBatch(repeatValue(rate, 22), repeatValue(rate, -18), repeatValue(rate, 996), t);
        t += 1000;
    }
    // La ventana se llena con la muestra 50 (fin del segundo lote, t = 2000) y desde
    // ahí van 3 s de quietud hasta t = 5000.
    var s = engine.snapshot();
    Test.assert(s.isStill);
    Test.assert(nearlyEqual(s.stillSeconds, 3.0f, 0.05f));
    return true;
}

(:test)
function telemetryEngineResetForgetsSamples(logger as Logger) as Boolean {
    var engine = new TelemetryEngine();
    engine.addBatch(repeatValue(5, 1), repeatValue(5, 2), repeatValue(5, 1000), 1000);
    engine.addBatch(repeatValue(5, 1), repeatValue(5, 2), repeatValue(5, 1000), 2000);
    engine.reset();
    var s = engine.snapshot();
    Test.assertEqual(s.samplesReceived, 0);
    Test.assertEqual(s.batchesReceived, 0);
    Test.assertEqual(s.x, 0);
    Test.assert(nearlyEqual(s.effectiveHz, 0.0f, 0.001f));
    return true;
}
