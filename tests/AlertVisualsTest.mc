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
function alertPulsePeriodsMatchTheWebDesign(logger as Logger) as Boolean {
    // Nivel 1: 1,4 s; nivel 2: 0,7 s; nivel 3: parpadeo de 0,5 s por color.
    Test.assertEqual(AlertVisuals.pulsePeriodMs(1, false), 1400);
    Test.assertEqual(AlertVisuals.pulsePeriodMs(2, false), 700);
    Test.assertEqual(AlertVisuals.pulsePeriodMs(3, false), 1000);
    return true;
}

(:test)
function alertPulseIsSmoothTriangle(logger as Logger) as Boolean {
    for (var level = 1; level <= 2; level++) {
        var period = AlertVisuals.pulsePeriodMs(level, false);
        Test.assertEqual(AlertVisuals.pulse(level, false, 0), 0.0f);
        Test.assertEqual(AlertVisuals.pulse(level, false, period / 2), 1.0f);
        Test.assertEqual(AlertVisuals.pulse(level, false, period), 0.0f);
        // Sin saltos: entre muestras de 66 ms (un cuadro) cambia poco.
        var maxStep = 0.0f;
        for (var t = 66; t <= 2 * period; t += 66) {
            var step = AlertVisuals.pulse(level, false, t) - AlertVisuals.pulse(level, false, t - 66);
            step = step < 0 ? -step : step;
            maxStep = step > maxStep ? step : maxStep;
        }
        Test.assertMessage(maxStep < 0.2f, "nivel " + level + ": paso máximo por cuadro " + maxStep);
    }
    return true;
}

(:test)
function alertLevelThreeFlashesEveryHalfSecond(logger as Logger) as Boolean {
    // Rojo intenso → rojo oscuro en 0,5 s y de vuelta en 0,5 s.
    Test.assertEqual(AlertnessColors.alertPulseColor(3, AlertVisuals.pulse(3, false, 0)), 0xE01E1E);
    Test.assertEqual(AlertnessColors.alertPulseColor(3, AlertVisuals.pulse(3, false, 500)), 0x6A0000);
    Test.assertEqual(AlertnessColors.alertPulseColor(3, AlertVisuals.pulse(3, false, 1000)), 0xE01E1E);
    // A mitad de camino, un rojo intermedio (como en las referencias del diseño web).
    var middle = AlertnessColors.alertPulseColor(3, AlertVisuals.pulse(3, false, 250));
    Test.assertEqual(middle, ColorMath.blend(Palette.RED_DARK, Palette.RED_INTENSE, 500));
    return true;
}

(:test)
function alertPulseDimsTowardsBlack(logger as Logger) as Boolean {
    // Nivel 1: opacidad 1 → 0,72 mezclando con negro, como el diseño web.
    Test.assertEqual(AlertnessColors.alertPulseColor(1, 1.0f),
        ColorMath.blend(Palette.ORANGE, Palette.BLACK, 720));
    Test.assertEqual(AlertnessColors.alertPulseColor(1, 0.5f),
        ColorMath.blend(Palette.ORANGE, Palette.BLACK, 860));
    // Nivel 2: el 0,72 del diseño deja el texto negro por debajo de 4,5:1, así que se
    // conserva la profundidad de antes (0,88).
    Test.assert(Contrast.ratio(Palette.BLACK, ColorMath.blend(Palette.ORANGE_DEEP, Palette.BLACK, 720)) < 4.5f);
    Test.assertEqual(AlertnessColors.alertPulseColor(2, 1.0f),
        ColorMath.blend(Palette.ORANGE_DEEP, Palette.BLACK, 880));
    return true;
}

(:test)
function alertIconRipplesGrowAndFade(logger as Logger) as Boolean {
    Test.assertEqual(AlertVisuals.RIPPLES, 2);
    // Primera onda: de 1× y opacidad 1 a 1,25× y 0 en 1,1 s.
    Test.assert(nearlyEqual(AlertVisuals.rippleProgress(0, 0), 0.0f, 0.0001f));
    Test.assert(nearlyEqual(AlertVisuals.rippleProgress(0, 550), 0.5f, 0.0001f));
    Test.assert(nearlyEqual(AlertVisuals.rippleProgress(0, 1100), 0.0f, 0.0001f));
    Test.assert(nearlyEqual(AlertVisuals.rippleScale(0.0f), 1.0f, 0.0001f));
    Test.assert(nearlyEqual(AlertVisuals.rippleScale(1.0f), 1.25f, 0.0001f));
    Test.assertEqual(AlertVisuals.rippleAlpha(0.0f), 1000);
    Test.assertEqual(AlertVisuals.rippleAlpha(0.5f), 500);
    Test.assertEqual(AlertVisuals.rippleAlpha(1.0f), 0);
    // La segunda sale 0,55 s después y luego va media onda por detrás.
    Test.assert(AlertVisuals.rippleProgress(1, 549) < 0.0f);
    Test.assert(nearlyEqual(AlertVisuals.rippleProgress(1, 550), 0.0f, 0.0001f));
    Test.assert(nearlyEqual(AlertVisuals.rippleProgress(1, 1100), 0.5f, 0.0001f));
    Test.assert(nearlyEqual(AlertVisuals.rippleProgress(0, 1650), 0.5f, 0.0001f));
    Test.assert(nearlyEqual(AlertVisuals.rippleProgress(1, 1650), 0.0f, 0.0001f));
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
    Test.assertEqual(dark, Palette.RED_DARK);
    Test.assertEqual(dark, 0x6A0000);
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
    // Valores del diseño web.
    Test.assertEqual(AlertnessColors.alertBackgroundColor(1), 0xFF8A1F);
    Test.assertEqual(AlertnessColors.alertBackgroundColor(2), 0xFF5A1F);
    Test.assertEqual(AlertnessColors.alertBackgroundColor(3), 0xE01E1E);
    // Texto negro en los niveles 1 y 2, blanco en el 3.
    Test.assertEqual(AlertnessColors.alertTextColor(1), Palette.BLACK);
    Test.assertEqual(AlertnessColors.alertTextColor(2), Palette.BLACK);
    Test.assertEqual(AlertnessColors.alertTextColor(3), Palette.WHITE);
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
    // Cambia de lado cada SHAKE_STEP_MS (un cuadro).
    Test.assertEqual(AlertVisuals.shakeOffset(3, normal, false, 10),
        -AlertVisuals.shakeOffset(3, normal, false, 10 + AlertVisuals.SHAKE_STEP_MS));
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

(:test)
function alertFrameRateStaysBetweenTenAndFifteen(logger as Logger) as Boolean {
    // ~15 cuadros por segundo con la alerta (un cuadro por paso de la sacudida).
    var fps = 1000.0f / AlertVisuals.SHAKE_STEP_MS;
    Test.assertMessage(fps >= 10.0f && fps <= 15.0f, fps.format("%.1f") + " cuadros/s");
    return true;
}
