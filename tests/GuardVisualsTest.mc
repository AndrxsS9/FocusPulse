import Toybox.Lang;
import Toybox.Test;

//! Pruebas de GuardVisuals (source/core): arco de escaneo y ping de la píldora.

(:test)
function guardScanArcMatchesTheWebDesign(logger as Logger) as Boolean {
    // 46 px sobre un radio de 164 px ≈ 16°.
    Test.assertEqual(GuardVisuals.scanLengthDegrees(), 16);
    // Sale de las 12 y gira en sentido horario (grados de drawArc decrecientes).
    Test.assertEqual(GuardVisuals.scanHeadDegrees(0), 90);
    Test.assertEqual(GuardVisuals.scanHeadDegrees(GuardVisuals.SCAN_PERIOD_MS / 4), 0);
    Test.assertEqual(GuardVisuals.scanHeadDegrees(GuardVisuals.SCAN_PERIOD_MS / 2), 270);
    Test.assertEqual(GuardVisuals.scanHeadDegrees(3 * GuardVisuals.SCAN_PERIOD_MS / 4), 180);
    // Una vuelta cada 2,8 s.
    Test.assertEqual(GuardVisuals.SCAN_PERIOD_MS, 2800);
    Test.assertEqual(GuardVisuals.scanHeadDegrees(2800), 90);
    Test.assertEqual(GuardVisuals.scanHeadDegrees(5600 + 700), 0);
    // Siempre en 0..359, también con tiempos negativos (contador que dio la vuelta).
    for (var t = -3000; t < 6000; t += 37) {
        var head = GuardVisuals.scanHeadDegrees(t);
        Test.assert(head >= 0 && head < 360);
    }
    return true;
}

(:test)
function guardPingGrowsAndFades(logger as Logger) as Boolean {
    Test.assert(nearlyEqual(GuardVisuals.pingProgress(0), 0.0f, 0.0001f));
    Test.assert(nearlyEqual(GuardVisuals.pingProgress(800), 0.5f, 0.0001f));
    Test.assert(nearlyEqual(GuardVisuals.pingProgress(1600), 0.0f, 0.0001f));
    // De 1× a 2,6× y de 0,8 a 0 de opacidad.
    Test.assert(nearlyEqual(GuardVisuals.pingScale(0.0f), 1.0f, 0.0001f));
    Test.assert(nearlyEqual(GuardVisuals.pingScale(0.5f), 1.8f, 0.0001f));
    Test.assert(nearlyEqual(GuardVisuals.pingScale(1.0f), 2.6f, 0.0001f));
    Test.assertEqual(GuardVisuals.pingAlpha(0.0f), 800);
    Test.assertEqual(GuardVisuals.pingAlpha(0.5f), 400);
    Test.assertEqual(GuardVisuals.pingAlpha(1.0f), 0);
    // Fuera de rango se recorta.
    Test.assert(nearlyEqual(GuardVisuals.pingScale(2.0f), 2.6f, 0.0001f));
    Test.assertEqual(GuardVisuals.pingAlpha(-1.0f), 800);
    return true;
}
