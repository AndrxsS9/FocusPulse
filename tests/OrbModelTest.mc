import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

//! Pruebas de TrigTable y OrbModel (source/core): geometría, determinismo, velocidad
//! por estado, paleta y brillo de las partículas.

//! Orbe del fr165: radio 97 px centrado en la hora (195, 130).
(:debug)
const ORB_TEST_CX = 195;
(:debug)
const ORB_TEST_CY = 130;
(:debug)
const ORB_TEST_RADIUS = 97;

(:debug)
function orbPointArray() as Array<Number> {
    return new Array<Number>[OrbModel.POINTS];
}

(:test)
function trigTableMatchesMath(logger as Logger) as Boolean {
    var trig = new TrigTable();
    var angles = [0.0f, 30.0f, 45.0f, 90.0f, 135.0f, 270.0f, 359.0f] as Array<Float>;
    for (var i = 0; i < angles.size(); i++) {
        var rad = Math.toRadians(angles[i]);
        Test.assert(nearlyEqual(trig.sinDeg(angles[i]), Math.sin(rad).toFloat(), 0.001f));
        Test.assert(nearlyEqual(trig.cosDeg(angles[i]), Math.cos(rad).toFloat(), 0.001f));
    }
    // Ángulos negativos, mayores de una vuelta y con decimales (se redondean al grado).
    Test.assert(nearlyEqual(trig.sinDeg(-90.0f), -1.0f, 0.001f));
    Test.assert(nearlyEqual(trig.sinDeg(450.0f), 1.0f, 0.001f));
    Test.assert(nearlyEqual(trig.sinDeg(-330.0f), 0.5f, 0.001f));
    Test.assert(nearlyEqual(trig.sinDeg(29.6f), 0.5f, 0.001f));
    Test.assert(nearlyEqual(trig.cosDeg(7200.0f), 1.0f, 0.001f));
    return true;
}

(:test)
function orbRingPointsStayInsideOrbRadius(logger as Logger) as Boolean {
    var model = new OrbModel();
    model.setState(OrbState.ACTIVE);
    var xs = orbPointArray();
    var ys = orbPointArray();
    var maxSeen = 0.0f;

    // Varios instantes, todos los anillos.
    for (var step = 0; step < 40; step++) {
        model.advance(0.37f);
        for (var ring = 0; ring < OrbModel.RINGS; ring++) {
            model.ringPoints(ring, ORB_TEST_CX, ORB_TEST_CY, ORB_TEST_RADIUS, xs, ys);
            for (var k = 0; k < OrbModel.POINTS; k++) {
                var dx = xs[k] - ORB_TEST_CX;
                var dy = ys[k] - ORB_TEST_CY;
                var d = Math.sqrt(dx * dx + dy * dy).toFloat();
                if (d > maxSeen) {
                    maxSeen = d;
                }
                // Redondeo a píxel: hasta 1 px más.
                Test.assert(d <= ORB_TEST_RADIUS + 1.0f);
            }
        }
    }
    logger.debug("radio máximo visto: " + maxSeen + " de " + ORB_TEST_RADIUS);
    return true;
}

(:test)
function orbRingsAreOrganicNotCircles(logger as Logger) as Boolean {
    // Cada anillo debe tener radios distintos en distintos ángulos (deformación 5–8 %).
    var model = new OrbModel();
    var xs = orbPointArray();
    var ys = orbPointArray();
    for (var ring = 0; ring < OrbModel.RINGS; ring++) {
        model.ringPoints(ring, 0, 0, 1000, xs, ys);
        var minR = 100000.0f;
        var maxR = 0.0f;
        for (var k = 0; k < OrbModel.POINTS; k++) {
            var d = Math.sqrt(xs[k] * xs[k] + ys[k] * ys[k]).toFloat();
            minR = d < minR ? d : minR;
            maxR = d > maxR ? d : maxR;
        }
        logger.debug("anillo " + ring + ": " + minR + "–" + maxR);
        Test.assert(maxR - minR > 50.0f);
    }
    return true;
}

(:test)
function orbIsDeterministicForTheSameTime(logger as Logger) as Boolean {
    var a = new OrbModel();
    var b = new OrbModel();
    a.setState(OrbState.NORMAL);
    b.setState(OrbState.NORMAL);
    a.advance(2.5f);
    b.advance(1.0f);
    b.advance(1.5f);
    Test.assert(nearlyEqual(a.time(), b.time(), 0.0001f));

    var ax = orbPointArray();
    var ay = orbPointArray();
    var bx = orbPointArray();
    var by = orbPointArray();
    for (var ring = 0; ring < OrbModel.RINGS; ring++) {
        a.ringPoints(ring, ORB_TEST_CX, ORB_TEST_CY, ORB_TEST_RADIUS, ax, ay);
        b.ringPoints(ring, ORB_TEST_CX, ORB_TEST_CY, ORB_TEST_RADIUS, bx, by);
        for (var k = 0; k < OrbModel.POINTS; k++) {
            Test.assertEqual(ax[k], bx[k]);
            Test.assertEqual(ay[k], by[k]);
        }
    }
    return true;
}

(:test)
function orbDoesNotMoveWhilePaused(logger as Logger) as Boolean {
    var model = new OrbModel();
    Test.assertEqual(model.state(), OrbState.PAUSED);
    var before = model.ringRotation(0);
    model.advance(10.0f);
    Test.assert(nearlyEqual(model.time(), 0.0f, 0.0001f));
    Test.assert(nearlyEqual(model.ringRotation(0), before, 0.0001f));
    Test.assert(nearlyEqual(OrbModel.speedFor(OrbState.PAUSED), 0.0f, 0.0001f));
    return true;
}

(:test)
function orbActiveAdvancesTwiceAsFastAsNormal(logger as Logger) as Boolean {
    var normal = new OrbModel();
    var active = new OrbModel();
    var drowsy = new OrbModel();
    normal.setState(OrbState.NORMAL);
    active.setState(OrbState.ACTIVE);
    drowsy.setState(OrbState.DROWSY);
    for (var i = 0; i < 10; i++) {
        normal.advance(0.25f);
        active.advance(0.25f);
        drowsy.advance(0.25f);
    }
    Test.assert(nearlyEqual(active.time(), 2.0f * normal.time(), 0.001f));
    Test.assert(drowsy.time() < normal.time());
    Test.assert(nearlyEqual(drowsy.time(), 0.35f * normal.time(), 0.001f));

    // La rotación sigue al tiempo: el anillo medio gira al revés.
    var spinNormal = normal.ringRotation(0) - (OrbModel.RING_OFFSET as Array<Number>)[0];
    var spinActive = active.ringRotation(0) - (OrbModel.RING_OFFSET as Array<Number>)[0];
    Test.assert(nearlyEqual(spinActive, 2.0f * spinNormal, 0.01f));
    Test.assert(normal.ringRotation(1) < (OrbModel.RING_OFFSET as Array<Number>)[1]);
    return true;
}

(:test)
function orbStateFollowsGuardClassAndScore(logger as Logger) as Boolean {
    Test.assertEqual(OrbModel.stateFor(false, DrowsinessClass.ACTIVE, 88), OrbState.PAUSED);
    Test.assertEqual(OrbModel.stateFor(true, DrowsinessClass.NORMAL, 88), OrbState.NORMAL);
    Test.assertEqual(OrbModel.stateFor(true, DrowsinessClass.ACTIVE, 88), OrbState.ACTIVE);
    Test.assertEqual(OrbModel.stateFor(true, DrowsinessClass.INERT, 88), OrbState.DROWSY);
    Test.assertEqual(OrbModel.stateFor(true, DrowsinessClass.NOD, 88), OrbState.DROWSY);
    Test.assertEqual(OrbModel.stateFor(true, DrowsinessClass.NORMAL, 59), OrbState.DROWSY);
    Test.assertEqual(OrbModel.stateFor(true, DrowsinessClass.NORMAL, 60), OrbState.NORMAL);
    // Con actividad alta manda la actividad aunque el puntaje aún sea bajo.
    Test.assertEqual(OrbModel.stateFor(true, DrowsinessClass.ACTIVE, 40), OrbState.ACTIVE);
    return true;
}

(:test)
function orbStateFollowsSimulatedScenarios(logger as Logger) as Boolean {
    var scenarios = [AccelScenario.TYPING, AccelScenario.NORMAL, AccelScenario.INACTIVITY] as Array<AccelScenario.Id>;
    var expected = [OrbState.ACTIVE, OrbState.NORMAL, OrbState.DROWSY] as Array<OrbState.Id>;
    for (var i = 0; i < scenarios.size(); i++) {
        var rig = new DetectorRig(scenarios[i], SIM_TEST_SEED, true);
        rig.run(6);
        Test.assertEqual(OrbModel.stateFor(true, rig.classifier.topClass(), rig.score.value()), expected[i]);
    }
    return true;
}

(:test)
function orbPaletteFollowsScoreBands(logger as Logger) as Boolean {
    Test.assertEqual(OrbModel.paletteFor(60)[0], Palette.ACCENT);
    Test.assertEqual(OrbModel.paletteFor(60)[1], Palette.ACCENT_LIGHT);
    Test.assertEqual(OrbModel.paletteFor(60)[2], Palette.VIOLET);
    Test.assertEqual(OrbModel.paletteFor(59)[0], Palette.AMBER);
    Test.assertEqual(OrbModel.paletteFor(35)[0], Palette.AMBER);
    Test.assertEqual(OrbModel.paletteFor(34)[0], Palette.RED);
    return true;
}

(:test)
function orbParticleBrightnessStaysBetween0And1(logger as Logger) as Boolean {
    var model = new OrbModel();
    model.setState(OrbState.ACTIVE);
    var minSeen = 1.0f;
    var maxSeen = 0.0f;
    for (var step = 0; step < 60; step++) {
        model.advance(0.083f);
        for (var i = 0; i < OrbModel.PARTICLES; i++) {
            var b = model.particleBrightness(i);
            Test.assert(b >= 0.0f && b <= 1.0f);
            minSeen = b < minSeen ? b : minSeen;
            maxSeen = b > maxSeen ? b : maxSeen;
        }
    }
    // Titilan: recorren casi todo el rango.
    Test.assert(minSeen < 0.1f);
    Test.assert(maxSeen > 0.9f);
    return true;
}

(:test)
function orbParticlesSitOnTheirRing(logger as Logger) as Boolean {
    var model = new OrbModel();
    var xs = new Array<Number>[OrbModel.PARTICLES];
    var ys = new Array<Number>[OrbModel.PARTICLES];
    model.particlePoints(195, 195, 150, xs, ys);
    for (var i = 0; i < OrbModel.PARTICLES; i++) {
        var dx = xs[i] - 195;
        var dy = ys[i] - 195;
        var d = Math.sqrt(dx * dx + dy * dy).toFloat();
        Test.assert(d >= 150 * 0.96f - 1 && d <= 150 * 1.04f + 1);
        // Ninguna justo arriba ni abajo del centro.
        Test.assert(xs[i] != 195);
    }
    // Las posiciones no cambian con el tiempo.
    var x0 = xs[0];
    model.setState(OrbState.ACTIVE);
    model.advance(5.0f);
    model.particlePoints(195, 195, 150, xs, ys);
    Test.assertEqual(xs[0], x0);
    return true;
}
