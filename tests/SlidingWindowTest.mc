import Toybox.Lang;
import Toybox.Test;

//! Pruebas de SlidingWindow (source/core): varianza conocida, cálculo incremental,
//! sacudida y segundos de quietud.

//! Periodo entre muestras a 25 Hz (ms).
(:debug)
const WINDOW_TEST_PERIOD_MS = 40;

//! true si a y b difieren en menos de tolerance.
(:debug)
function nearlyEqual(a as Float, b as Float, tolerance as Float) as Boolean {
    var d = a - b;
    return d < tolerance && d > -tolerance;
}

//! Empuja n muestras iguales a la ventana empezando en startMs y devuelve el
//! instante de la siguiente muestra.
(:debug)
function pushConstant(window as SlidingWindow, n as Number, x as Number, y as Number, z as Number,
        startMs as Number) as Number {
    var t = startMs;
    for (var i = 0; i < n; i++) {
        window.push(x, y, z, t);
        t += WINDOW_TEST_PERIOD_MS;
    }
    return t;
}

(:test)
function slidingWindowKnownVariance(logger as Logger) as Boolean {
    var window = new SlidingWindow();

    // Magnitudes 990 y 1010 alternadas: media 1000, varianza 100 exacta.
    var t = 0;
    for (var i = 0; i < SlidingWindow.WINDOW_SAMPLES; i++) {
        window.push(0, 0, (i % 2 == 0) ? 990 : 1010, t);
        t += WINDOW_TEST_PERIOD_MS;
    }
    Test.assert(window.isFull());
    Test.assert(nearlyEqual(window.mean(), 1000.0f, 0.001f));
    Test.assert(nearlyEqual(window.variance(), 100.0f, 0.001f));
    Test.assert(nearlyEqual(window.stdDev(), 10.0f, 0.001f));

    // Una ventana completa de valores constantes deja la varianza en 0.
    pushConstant(window, SlidingWindow.WINDOW_SAMPLES, 0, 0, 1000, t);
    Test.assert(nearlyEqual(window.variance(), 0.0f, 0.001f));
    Test.assert(nearlyEqual(window.mean(), 1000.0f, 0.001f));
    return true;
}

(:test)
function slidingWindowIncrementalMatchesDirectComputation(logger as Logger) as Boolean {
    var window = new SlidingWindow();
    var total = SlidingWindow.WINDOW_SAMPLES * 3 + 7;
    var magnitudes = new Array<Number>[total];
    var seed = 12345;

    for (var i = 0; i < total; i++) {
        seed = (seed * 75 + 74) % 65537;
        var z = 700 + seed % 600;
        magnitudes[i] = z;
        window.push(0, 0, z, i * WINDOW_TEST_PERIOD_MS);
    }

    // Media y varianza calculadas desde cero sobre las últimas WINDOW_SAMPLES.
    var n = SlidingWindow.WINDOW_SAMPLES;
    var sum = 0.0d;
    for (var i = total - n; i < total; i++) {
        sum += magnitudes[i];
    }
    var mean = sum / n;
    var sq = 0.0d;
    for (var i = total - n; i < total; i++) {
        var d = magnitudes[i] - mean;
        sq += d * d;
    }
    var expected = (sq / n).toFloat();

    logger.debug("varianza incremental=" + window.variance() + " directa=" + expected);
    Test.assert(nearlyEqual(window.mean(), mean.toFloat(), 0.01f));
    Test.assert(nearlyEqual(window.variance(), expected, 0.5f));
    return true;
}

(:test)
function slidingWindowJerkTracksLastTenSamples(logger as Logger) as Boolean {
    var window = new SlidingWindow();
    var t = pushConstant(window, 20, 0, 0, 1000, 0);
    Test.assertEqual(window.jerk(), 0);

    // Salto de (0, 0, 1000) a (300, 400, 1000): |Δ| = 500.
    window.push(300, 400, 1000, t);
    t += WINDOW_TEST_PERIOD_MS;
    Test.assertEqual(window.lastDelta(), 500);
    Test.assertEqual(window.jerk(), 500);

    // Con 8 muestras más, el salto sigue dentro de las últimas 10.
    t = pushConstant(window, SlidingWindow.JERK_SAMPLES - 2, 300, 400, 1000, t);
    Test.assertEqual(window.jerk(), 500);

    // Con una más, la muestra anterior al salto sale de las últimas 10.
    t = pushConstant(window, 1, 300, 400, 1000, t);
    Test.assertEqual(window.jerk(), 0);

    // Se queda con el mayor de varios saltos.
    window.push(300, 400, 1100, t);
    window.push(300, 400, 1000, t + WINDOW_TEST_PERIOD_MS);
    window.push(300, 100, 1000, t + 2 * WINDOW_TEST_PERIOD_MS);
    Test.assertEqual(window.jerk(), 300);
    return true;
}

(:test)
function slidingWindowCountsStillSeconds(logger as Logger) as Boolean {
    var window = new SlidingWindow();

    // Con la ventana incompleta nunca hay quietud.
    var t = pushConstant(window, SlidingWindow.WINDOW_SAMPLES - 1, 22, -18, 996, 0);
    Test.assert(!window.isStill());
    Test.assert(nearlyEqual(window.stillSeconds(), 0.0f, 0.001f));

    // Al llenarse empieza a contar desde 0.
    t = pushConstant(window, 1, 22, -18, 996, t);
    Test.assert(window.isStill());
    Test.assert(nearlyEqual(window.stillSeconds(), 0.0f, 0.001f));

    // 25 muestras más a 25 Hz = 1 s de quietud.
    t = pushConstant(window, SlidingWindow.SAMPLE_RATE_HZ, 22, -18, 996, t);
    Test.assert(nearlyEqual(window.stillSeconds(), 1.0f, 0.001f));

    // Un golpe (magnitud 1,6 g) sube la varianza y reinicia la cuenta. Un giro puro
    // no serviría: la magnitud seguiría en ≈1 g y la varianza no cambiaría.
    window.push(0, 0, 1600, t);
    Test.assert(!window.isStill());
    Test.assert(nearlyEqual(window.stillSeconds(), 0.0f, 0.001f));
    return true;
}

(:test)
function slidingWindowResetClearsEverything(logger as Logger) as Boolean {
    var window = new SlidingWindow();
    pushConstant(window, SlidingWindow.WINDOW_SAMPLES + 5, 0, 0, 1000, 0);
    window.push(500, 0, 1000, 10000);
    window.reset();

    Test.assertEqual(window.count(), 0);
    Test.assertEqual(window.jerk(), 0);
    Test.assert(!window.isStill());
    Test.assert(nearlyEqual(window.variance(), 0.0f, 0.001f));
    Test.assertEqual(window.lastZ(), 0);
    return true;
}
