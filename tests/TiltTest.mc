import Toybox.Lang;
import Toybox.Test;

//! Pruebas de la gravedad por ventana (SlidingWindow.meanX/Y/Z) y de Tilt.

(:test)
function tiltAngleOfKnownVectors(logger as Logger) as Boolean {
    Test.assert(nearlyEqual(Tilt.angleDegrees(0.0f, 0.0f, 1000.0f, 0.0f, 0.0f, 980.0f), 0.0f, 0.01f));
    Test.assert(nearlyEqual(Tilt.angleDegrees(0.0f, 0.0f, 1000.0f, 1000.0f, 0.0f, 0.0f), 90.0f, 0.01f));
    Test.assert(nearlyEqual(Tilt.angleDegrees(0.0f, 0.0f, 1000.0f, 0.0f, 0.0f, -1000.0f), 180.0f, 0.01f));
    Test.assert(nearlyEqual(Tilt.angleDegrees(0.0f, 0.0f, 1000.0f, 0.0f, 707.0f, 707.0f), 45.0f, 0.05f));
    // Con un vector nulo (ventana vacía) el ángulo no está definido: 0.
    Test.assert(nearlyEqual(Tilt.angleDegrees(0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1000.0f), 0.0f, 0.001f));
    return true;
}

(:test)
function slidingWindowGravityIsAxisMean(logger as Logger) as Boolean {
    var window = new SlidingWindow();
    Test.assert(nearlyEqual(window.meanZ(), 0.0f, 0.001f));
    window.push(10, -20, 990, 0);
    window.push(30, -40, 1010, 40);
    Test.assert(nearlyEqual(window.meanX(), 20.0f, 0.001f));
    Test.assert(nearlyEqual(window.meanY(), -30.0f, 0.001f));
    Test.assert(nearlyEqual(window.meanZ(), 1000.0f, 0.001f));

    // Al deslizar, las muestras viejas salen de la media sin dejar rastro.
    for (var i = 0; i < SlidingWindow.WINDOW_SAMPLES; i++) {
        window.push(-500, 0, 866, 80 + i * 40);
    }
    Test.assert(nearlyEqual(window.meanX(), -500.0f, 0.001f));
    Test.assert(nearlyEqual(window.meanZ(), 866.0f, 0.001f));

    window.reset();
    Test.assert(nearlyEqual(window.meanX(), 0.0f, 0.001f));
    return true;
}

(:test)
function tiltSeparatesNodFromTyping(logger as Logger) as Boolean {
    // Cabeceo: la gravedad antes de la caída (lote 3) y con el brazo colgando (lote 7)
    // forman más de 35°.
    var nod = new SimulatedAccelSource(AccelScenario.NOD, SIM_TEST_SEED);
    var engine = new TelemetryEngine();
    var t = feedSeconds(nod, engine, 3, 1000);
    var before = engine.snapshot();
    feedSeconds(nod, engine, 4, t);
    var after = engine.snapshot();
    var nodTilt = Tilt.between(before, after);
    logger.debug("cabeceo: gravedad antes=(" + before.gravityX + ", " + before.gravityY + ", "
        + before.gravityZ + ") después=(" + after.gravityX + ", " + after.gravityY + ", "
        + after.gravityZ + ") inclinación=" + nodTilt);
    Test.assert(nodTilt > 35.0f);

    // Tecleo: mucho movimiento, pero la gravedad media casi no cambia de un lote a otro.
    var typing = new SimulatedAccelSource(AccelScenario.TYPING, SIM_TEST_SEED);
    var typingEngine = new TelemetryEngine();
    var tt = feedSeconds(typing, typingEngine, 2, 1000);
    var maxTilt = 0.0f;
    for (var i = 0; i < 20; i++) {
        var prev = typingEngine.snapshot();
        tt = feedSeconds(typing, typingEngine, 1, tt);
        var tilt = Tilt.between(prev, typingEngine.snapshot());
        if (tilt > maxTilt) {
            maxTilt = tilt;
        }
    }
    logger.debug("tecleo: inclinación máxima entre lotes=" + maxTilt);
    Test.assert(maxTilt < 10.0f);
    return true;
}
