import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

//! Pruebas de TrigTable y OrbModel (source/core): contornos de Bézier, fotogramas clave,
//! velocidad por estado, paleta y brillo de las partículas.

///! Orbe del fr165: centrado en la pantalla (195, 195), 1 px por unidad del diseño.
(:debug)
const ORB_TEST_CX = 195;
(:debug)
const ORB_TEST_CY = 195;

(:debug)
function orbPointArray() as Array<Float> {
    return new Array<Float>[OrbModel.POINTS];
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
function orbContoursFollowTheirBezierPaths(logger as Logger) as Boolean {
    var model = new OrbModel();
    Test.assertEqual(OrbModel.POINTS, OrbModel.SEGMENTS * OrbModel.SEGMENT_POINTS);
    var paths = [OrbModel.CONTOUR_A, OrbModel.CONTOUR_B, OrbModel.CONTOUR_C] as Array<Array<Number> >;
    for (var ring = 0; ring < OrbModel.RINGS; ring++) {
        var path = paths[ring];
        // Trazado cerrado (Z): termina donde empieza.
        Test.assertEqual(path[24], path[0]);
        Test.assertEqual(path[25], path[1]);
        // El primer punto de cada curva es el final de la anterior (t = 0 exacto).
        for (var s = 0; s < OrbModel.SEGMENTS; s++) {
            var k = s * OrbModel.SEGMENT_POINTS;
            Test.assert(nearlyEqual(model.localX(ring, k), path[6 * s].toFloat(), 0.001f));
            Test.assert(nearlyEqual(model.localY(ring, k), path[6 * s + 1].toFloat(), 0.001f));
        }
    }
    // A, a mitad de su primera curva: B(0,5) = (P0 + 3·P1 + 3·P2 + P3) / 8.
    var half = OrbModel.SEGMENT_POINTS / 2;
    Test.assert(nearlyEqual(model.localX(0, half), (0 + 3 * 80 + 3 * 140 + 145) / 8.0f, 0.001f));
    Test.assert(nearlyEqual(model.localY(0, half), (-150 - 3 * 152 - 3 * 90 - 10) / 8.0f, 0.001f));
    return true;
}

(:test)
function orbContoursAreOrganicNotCircles(logger as Logger) as Boolean {
    var model = new OrbModel();
    for (var ring = 0; ring < OrbModel.RINGS; ring++) {
        var minR = 100000.0f;
        var maxR = 0.0f;
        for (var k = 0; k < OrbModel.POINTS; k++) {
            var x = model.localX(ring, k);
            var y = model.localY(ring, k);
            var d = Math.sqrt(x * x + y * y).toFloat();
            minR = d < minR ? d : minR;
            maxR = d > maxR ? d : maxR;
        }
        logger.debug("contorno " + ring + ": radio " + minR.format("%.1f") + "–" + maxR.format("%.1f"));
        // Radios distintos en distintos ángulos (no un círculo) y del tamaño del diseño.
        Test.assert(maxR - minR > 5.0f);
        Test.assert(minR > 120.0f && maxR < 165.0f);
    }
    return true;
}

(:test)
function orbStaysInsideTheAlertRing(logger as Logger) as Boolean {
    // fr165: el anillo de nivel de alerta empieza a 177 px del centro. Con la escala
    // máxima de cada contorno ningún punto debe tocarlo.
    var layout = new RoundLayout(390, 390);
    var model = new OrbModel();
    model.setState(OrbState.ACTIVE);
    var xs = orbPointArray();
    var ys = orbPointArray();
    var maxSeen = 0.0f;
    for (var step = 0; step < 120; step++) {
        model.advance(0.29f);
        for (var ring = 0; ring < OrbModel.RINGS; ring++) {
            model.ringPoints(ring, ORB_TEST_CX, ORB_TEST_CY, 1.0f, xs, ys);
            for (var k = 0; k < OrbModel.POINTS; k++) {
                var dx = xs[k] - ORB_TEST_CX;
                var dy = ys[k] - ORB_TEST_CY;
                var d = Math.sqrt(dx * dx + dy * dy).toFloat();
                maxSeen = d > maxSeen ? d : maxSeen;
            }
        }
    }
    logger.debug("radio máximo visto: " + maxSeen.format("%.1f") + " de " + layout.ringInnerRadius);
    Test.assert(maxSeen < layout.ringInnerRadius - 2);
    return true;
}

(:test)
function orbKeyframesMatchTheWebAnimation(logger as Logger) as Boolean {
    // A: 0° (1, 1) → 180° (1,07, 0,93) → 360° (1, 1).
    Test.assert(nearlyEqual(OrbModel.rotationAt(0, 0.0f), 0.0f, 0.001f));
    Test.assert(nearlyEqual(OrbModel.rotationAt(0, 0.5f), 180.0f, 0.001f));
    Test.assert(nearlyEqual(OrbModel.scaleXAt(0, 0.5f), 1.07f, 0.0001f));
    Test.assert(nearlyEqual(OrbModel.scaleYAt(0, 0.5f), 0.93f, 0.0001f));
    Test.assert(nearlyEqual(OrbModel.scaleXAt(0, 1.0f), 1.0f, 0.0001f));
    // B gira al revés: 0° (0,95, 1,04) → -180° (1,05, 0,95) → -360°.
    Test.assert(nearlyEqual(OrbModel.rotationAt(1, 0.5f), -180.0f, 0.001f));
    Test.assert(nearlyEqual(OrbModel.rotationAt(1, 1.0f), -360.0f, 0.001f));
    Test.assert(nearlyEqual(OrbModel.scaleXAt(1, 0.0f), 0.95f, 0.0001f));
    Test.assert(nearlyEqual(OrbModel.scaleYAt(1, 0.0f), 1.04f, 0.0001f));
    Test.assert(nearlyEqual(OrbModel.scaleXAt(1, 0.5f), 1.05f, 0.0001f));
    Test.assert(nearlyEqual(OrbModel.scaleYAt(1, 0.5f), 0.95f, 0.0001f));
    // C: 40° (1, 1) → 220° (0,92, 1,06) → 400° (1, 1).
    Test.assert(nearlyEqual(OrbModel.rotationAt(2, 0.0f), 40.0f, 0.001f));
    Test.assert(nearlyEqual(OrbModel.rotationAt(2, 0.5f), 220.0f, 0.001f));
    Test.assert(nearlyEqual(OrbModel.rotationAt(2, 1.0f), 400.0f, 0.001f));
    Test.assert(nearlyEqual(OrbModel.scaleXAt(2, 0.5f), 0.92f, 0.0001f));
    Test.assert(nearlyEqual(OrbModel.scaleYAt(2, 0.5f), 1.06f, 0.0001f));
    // Interpolación lineal: a un cuarto del ciclo, a medio camino.
    Test.assert(nearlyEqual(OrbModel.scaleXAt(0, 0.25f), 1.035f, 0.0001f));
    Test.assert(nearlyEqual(OrbModel.scaleXAt(0, 0.75f), 1.035f, 0.0001f));
    return true;
}

(:test)
function orbRingPointsApplyScaleThenRotation(logger as Logger) as Boolean {
    var model = new OrbModel();
    var xs = orbPointArray();
    var ys = orbPointArray();
    // Fase 0 de A: sin girar ni escalar, solo trasladado y escalado por k.
    model.ringPoints(0, ORB_TEST_CX, ORB_TEST_CY, 2.0f, xs, ys);
    Test.assert(nearlyEqual(xs[0], ORB_TEST_CX.toFloat(), 0.001f));
    Test.assert(nearlyEqual(ys[0], ORB_TEST_CY - 300.0f, 0.001f));
    // Fase 0 de C: girado 40° en sentido horario (y hacia abajo) sin escala.
    model.ringPoints(2, 0, 0, 1.0f, xs, ys);
    var radians = Math.toRadians(40);
    var x0 = model.localX(2, 0);
    var y0 = model.localY(2, 0);
    Test.assert(nearlyEqual(xs[0], (x0 * Math.cos(radians) - y0 * Math.sin(radians)).toFloat(), 0.01f));
    Test.assert(nearlyEqual(ys[0], (x0 * Math.sin(radians) + y0 * Math.cos(radians)).toFloat(), 0.01f));
    // A a mitad de ciclo (180°, escala 1,07 × 0,93): el punto de arriba (0, -150) queda
    // abajo, a 150 × 0,93.
    model.setState(OrbState.NORMAL);
    model.advance(((OrbModel.CYCLE_MS as Array<Number>)[0] / 2) / 1000.0f);
    Test.assert(nearlyEqual(model.phase(0), 0.5f, 0.001f));
    model.ringPoints(0, 0, 0, 1.0f, xs, ys);
    Test.assert(nearlyEqual(xs[0], 0.0f, 0.05f));
    Test.assert(nearlyEqual(ys[0], 150.0f * 0.93f, 0.05f));
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
        Test.assert(nearlyEqual(a.phase(ring), b.phase(ring), 0.0001f));
        a.ringPoints(ring, ORB_TEST_CX, ORB_TEST_CY, 1.0f, ax, ay);
        b.ringPoints(ring, ORB_TEST_CX, ORB_TEST_CY, 1.0f, bx, by);
        for (var k = 0; k < OrbModel.POINTS; k++) {
            Test.assert(nearlyEqual(ax[k], bx[k], 0.01f));
            Test.assert(nearlyEqual(ay[k], by[k], 0.01f));
        }
    }
    return true;
}

(:test)
function orbPhasesWrapAfterAFullCycle(logger as Logger) as Boolean {
    var model = new OrbModel();
    model.setState(OrbState.NORMAL);
    var cycle = (OrbModel.CYCLE_MS as Array<Number>)[0] / 1000.0f;
    for (var i = 0; i < 10; i++) {
        model.advance(cycle / 4.0f);
    }
    // 2,5 ciclos: la fase vuelve a 0,5 y siempre queda en 0..1.
    Test.assert(nearlyEqual(model.phase(0), 0.5f, 0.001f));
    for (var ring = 0; ring < OrbModel.RINGS; ring++) {
        Test.assert(model.phase(ring) >= 0.0f && model.phase(ring) < 1.0f);
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
    Test.assert(nearlyEqual(active.phase(0), 2.0f * normal.phase(0), 0.001f));
    Test.assert(drowsy.phase(0) < normal.phase(0));
    // B gira al revés.
    Test.assert(normal.ringRotation(1) < 0.0f);
    Test.assert(normal.ringRotation(0) > 0.0f);
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
