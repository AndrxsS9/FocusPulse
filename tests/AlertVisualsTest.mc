import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

//! Contraste WCAG 2.x entre dos colores 0xRRGGBB. Clase (:test): queda fuera de la
//! compilación normal.
(:test)
class Contrast {

    static function channel(value as Number) as Float {
        var c = value / 255.0f;
        if (c <= 0.04045f) {
            return c / 12.92f;
        }
        return Math.pow((c + 0.055f) / 1.055f, 2.4f).toFloat();
    }

    static function luminance(color as Number) as Float {
        return 0.2126f * channel((color >> 16) & 0xFF)
            + 0.7152f * channel((color >> 8) & 0xFF)
            + 0.0722f * channel(color & 0xFF);
    }

    static function ratio(a as Number, b as Number) as Float {
        var la = luminance(a);
        var lb = luminance(b);
        return la > lb ? (la + 0.05f) / (lb + 0.05f) : (lb + 0.05f) / (la + 0.05f);
    }
}

(:test)
function alertPulseIsSlowerThanThreeHertz(logger as Logger) as Boolean {
    for (var level = 1; level <= 3; level++) {
        var period = AlertVisuals.pulsePeriodMs(level, false);
        Test.assertMessage(period >= AlertVisuals.PHOTOSENSITIVE_MIN_PERIOD_MS,
            "nivel " + level + ": " + period + " ms por ciclo (< 3 Hz)");
        // Contando máximos en 3 s muestreados cada 10 ms: menos de 9 (3 por segundo).
        var peaks = 0;
        var previous = AlertVisuals.pulse(level, false, 0);
        var rising = true;
        for (var t = 10; t <= 3000; t += 10) {
            var value = AlertVisuals.pulse(level, false, t);
            if (rising && value < previous) {
                peaks++;
            }
            rising = value >= previous;
            previous = value;
        }
        Test.assertMessage(peaks < 9, "nivel " + level + ": " + peaks + " ciclos en 3 s");
        logger.debug("nivel " + level + ": periodo " + period + " ms, " + peaks + " ciclos en 3 s");
    }
    return true;
}

(:test)
function alertPulseIsSmoothTriangle(logger as Logger) as Boolean {
    var period = AlertVisuals.pulsePeriodMs(2, false);
    Test.assertEqual(AlertVisuals.pulse(2, false, 0), 0.0f);
    Test.assertEqual(AlertVisuals.pulse(2, false, period / 2), 1.0f);
    Test.assertEqual(AlertVisuals.pulse(2, false, period), 0.0f);
    // Sin saltos: entre muestras de 66 ms (un cuadro) cambia poco.
    var maxStep = 0.0f;
    for (var t = 66; t <= 2 * period; t += 66) {
        var step = AlertVisuals.pulse(2, false, t) - AlertVisuals.pulse(2, false, t - 66);
        step = step < 0 ? -step : step;
        maxStep = step > maxStep ? step : maxStep;
    }
    Test.assertMessage(maxStep < 0.2f, "paso máximo por cuadro " + maxStep);
    return true;
}

(:test)
function alertPulseColorsKeepTextReadable(logger as Logger) as Boolean {
    for (var level = 1; level <= 3; level++) {
        var base = AlertnessColors.alertPulseColor(level, 0.0f);
        var darkest = AlertnessColors.alertPulseColor(level, 1.0f);
        Test.assertEqual(base, AlertnessColors.alertBackgroundColor(level));
        Test.assertMessage(darkest != base, "nivel " + level + ": el pulso cambia el fondo");
        var text = AlertnessColors.alertTextColor(level);
        for (var p = 0; p <= 10; p++) {
            var ratio = Contrast.ratio(text, AlertnessColors.alertPulseColor(level, p / 10.0f));
            Test.assertMessage(ratio >= 4.5f,
                "nivel " + level + ", pulso " + p + "/10: contraste " + ratio.format("%.2f"));
        }
        logger.debug("nivel " + level + ": contraste " + Contrast.ratio(text, base).format("%.2f")
            + " → " + Contrast.ratio(text, darkest).format("%.2f"));
    }
    return true;
}

(:test)
function alertLevelThreeAlternatesWithDarkRed(logger as Logger) as Boolean {
    var dark = AlertnessColors.alertPulseColor(3, 1.0f);
    Test.assertEqual(dark, ColorMath.blend(Palette.RED_INTENSE, Palette.BACKGROUND, 600));
    Test.assertEqual(AlertnessColors.alertPulseColor(3, 0.0f), Palette.RED_INTENSE);
    Test.assertEqual(AlertnessColors.alertTextColor(3), Palette.WHITE);
    // Fuera de rango se recorta.
    Test.assertEqual(AlertnessColors.alertPulseColor(3, 2.0f), dark);
    Test.assertEqual(AlertnessColors.alertPulseColor(1, -1.0f), Palette.ORANGE);
    return true;
}

(:test)
function alertColorsPerLevel(logger as Logger) as Boolean {
    Test.assertEqual(AlertnessColors.alertBackgroundColor(1), Palette.ORANGE);
    Test.assertEqual(AlertnessColors.alertBackgroundColor(2), Palette.ORANGE_DEEP);
    Test.assertEqual(AlertnessColors.alertBackgroundColor(3), Palette.RED_INTENSE);
    Test.assertEqual(AlertnessColors.alertTextColor(1), Palette.BACKGROUND);
    Test.assertEqual(AlertnessColors.alertTextColor(2), Palette.BACKGROUND);
    return true;
}

(:test)
function alertEntranceBouncesInto300Ms(logger as Logger) as Boolean {
    Test.assertEqual(AlertVisuals.entranceScale(0), 0.0f);
    Test.assertEqual(AlertVisuals.entranceScale(AlertVisuals.ENTRANCE_MS), 1.0f);
    Test.assertEqual(AlertVisuals.entranceScale(5000), 1.0f);
    var peak = 0.0f;
    for (var t = 0; t <= AlertVisuals.ENTRANCE_MS; t += 10) {
        var s = AlertVisuals.entranceScale(t);
        peak = s > peak ? s : peak;
    }
    Test.assertMessage(peak > 1.02f && peak < 1.15f, "rebote pequeño: pico " + peak.format("%.3f"));
    Test.assertEqual(AlertVisuals.entranceProgress(150), 0.5f);
    return true;
}

(:test)
function alertShakeFollowsVibration(logger as Logger) as Boolean {
    var normal = VibrationLevel.NORMAL;
    for (var level = 1; level <= 3; level++) {
        var amplitude = AlertVisuals.shakeAmplitude(level);
        Test.assertMessage(amplitude >= 2 && amplitude <= 6, "nivel " + level + ": " + amplitude + " px");
        // Al empezar el motor está encendido: se mueve.
        var offset = AlertVisuals.shakeOffset(level, normal, false, 10);
        Test.assertEqual(offset < 0 ? -offset : offset, amplitude);
        // Después de la ráfaga, quieto.
        Test.assertEqual(AlertVisuals.shakeOffset(level, normal, false, VibePatterns.burstMs(level, normal) + 50), 0);
        // Con la vibración apagada no se sacude nunca.
        Test.assertEqual(AlertVisuals.shakeOffset(level, VibrationLevel.OFF, false, 10), 0);
    }
    Test.assert(AlertVisuals.shakeAmplitude(1) < AlertVisuals.shakeAmplitude(2));
    Test.assert(AlertVisuals.shakeAmplitude(2) < AlertVisuals.shakeAmplitude(3));
    // En la pausa entre pulsos del nivel 1 (150–300 ms) tampoco se mueve.
    Test.assertEqual(AlertVisuals.shakeOffset(1, normal, false, 200), 0);
    // Con vibración suave el nivel 1 es un solo pulso: a los 350 ms ya está quieto.
    Test.assertEqual(AlertVisuals.shakeOffset(1, VibrationLevel.SOFT, false, 350), 0);
    Test.assert(AlertVisuals.shakeOffset(1, VibrationLevel.STRONG, false, 350) != 0);
    // Cambia de lado cada SHAKE_STEP_MS.
    Test.assertEqual(AlertVisuals.shakeOffset(3, normal, false, 10), -AlertVisuals.shakeOffset(3, normal, false, 60));
    return true;
}

(:test)
function alertReducedAnimationsKeepTheAlertClear(logger as Logger) as Boolean {
    for (var level = 1; level <= 3; level++) {
        // Pulso el doble de lento, todavía una onda suave de 0 a 1.
        var period = AlertVisuals.pulsePeriodMs(level, true);
        Test.assertEqual(period, 2 * AlertVisuals.pulsePeriodMs(level, false));
        Test.assertEqual(AlertVisuals.pulse(level, true, period / 2), 1.0f);
        Test.assertEqual(AlertVisuals.pulse(level, true, period), 0.0f);
        // Sin sacudida aunque el motor esté encendido.
        Test.assertEqual(AlertVisuals.shakeOffset(level, VibrationLevel.NORMAL, true, 10), 0);
        // El color de fondo y el del texto son los mismos que sin reducir: la alerta se
        // reconoce por el color de cada nivel y por sus textos.
        Test.assertEqual(AlertnessColors.alertPulseColor(level, AlertVisuals.pulse(level, true, 0)),
            AlertnessColors.alertBackgroundColor(level));
    }
    Test.assertMessage(AlertVisuals.pulsePeriodMs(3, true) >= AlertVisuals.pulsePeriodMs(1, false),
        "reducido, ni el nivel 3 late más rápido que el nivel 1 normal");
    return true;
}
