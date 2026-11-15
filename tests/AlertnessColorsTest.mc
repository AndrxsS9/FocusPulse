import Toybox.Lang;
import Toybox.Test;

//! Pruebas de AlertnessColors (source/core) en los límites de cada banda:
//! 0, 34 | 35, 59 | 60, 100, más valores fuera de rango.

//! true si dos arreglos de colores tienen el mismo contenido.
//! (Array no compara por contenido con equals.) No usa Toybox.Test para que
//! compile también fuera del modo de pruebas, ya que tests/ está en sourcePath.
(:debug)
function colorsMatch(actual as Array<Number>, expected as Array<Number>) as Boolean {
    if (actual.size() != expected.size()) {
        return false;
    }
    for (var i = 0; i < expected.size(); i++) {
        if (actual[i] != expected[i]) {
            return false;
        }
    }
    return true;
}

(:test)
function alertnessBandLimits(logger as Logger) as Boolean {
    Test.assertEqual(AlertnessColors.bandForScore(0), AlertnessColors.BAND_LOW);
    Test.assertEqual(AlertnessColors.bandForScore(34), AlertnessColors.BAND_LOW);
    Test.assertEqual(AlertnessColors.bandForScore(35), AlertnessColors.BAND_MEDIUM);
    Test.assertEqual(AlertnessColors.bandForScore(59), AlertnessColors.BAND_MEDIUM);
    Test.assertEqual(AlertnessColors.bandForScore(60), AlertnessColors.BAND_HIGH);
    Test.assertEqual(AlertnessColors.bandForScore(100), AlertnessColors.BAND_HIGH);
    return true;
}

(:test)
function colorForAlertnessIsRedBelow35(logger as Logger) as Boolean {
    Test.assertEqualMessage(AlertnessColors.colorForAlertness(0), Palette.RED, "0 -> rojo");
    Test.assertEqualMessage(AlertnessColors.colorForAlertness(34), Palette.RED, "34 -> rojo");
    return true;
}

(:test)
function colorForAlertnessIsAmberFrom35To59(logger as Logger) as Boolean {
    Test.assertEqualMessage(AlertnessColors.colorForAlertness(35), Palette.AMBER, "35 -> ámbar");
    Test.assertEqualMessage(AlertnessColors.colorForAlertness(59), Palette.AMBER, "59 -> ámbar");
    return true;
}

(:test)
function colorForAlertnessIsCyanFrom60(logger as Logger) as Boolean {
    Test.assertEqualMessage(AlertnessColors.colorForAlertness(60), Palette.ACCENT, "60 -> cian");
    Test.assertEqualMessage(AlertnessColors.colorForAlertness(100), Palette.ACCENT, "100 -> cian");
    return true;
}

(:test)
function colorForAlertnessClampsOutOfRange(logger as Logger) as Boolean {
    Test.assertEqualMessage(AlertnessColors.colorForAlertness(-10), Palette.RED, "-10 se trata como 0");
    Test.assertEqualMessage(AlertnessColors.colorForAlertness(250), Palette.ACCENT, "250 se trata como 100");
    return true;
}

(:test)
function orbPaletteFollowsBands(logger as Logger) as Boolean {
    var low = [Palette.RED, Palette.RED_LIGHT, Palette.AMBER] as Array<Number>;
    var medium = [Palette.AMBER, Palette.AMBER_LIGHT, Palette.ORANGE] as Array<Number>;
    var high = [Palette.ACCENT, Palette.ACCENT_LIGHT, Palette.VIOLET] as Array<Number>;

    Test.assertMessage(colorsMatch(AlertnessColors.orbPalette(0), low), "orbe 0");
    Test.assertMessage(colorsMatch(AlertnessColors.orbPalette(34), low), "orbe 34");
    Test.assertMessage(colorsMatch(AlertnessColors.orbPalette(35), medium), "orbe 35");
    Test.assertMessage(colorsMatch(AlertnessColors.orbPalette(59), medium), "orbe 59");
    Test.assertMessage(colorsMatch(AlertnessColors.orbPalette(60), high), "orbe 60");
    Test.assertMessage(colorsMatch(AlertnessColors.orbPalette(100), high), "orbe 100");
    return true;
}

(:test)
function orbPaletteOuterRingMatchesAlertnessColor(logger as Logger) as Boolean {
    var scores = [0, 34, 35, 59, 60, 100] as Array<Number>;
    for (var i = 0; i < scores.size(); i++) {
        var score = scores[i];
        Test.assertEqualMessage(
            AlertnessColors.orbPalette(score)[0],
            AlertnessColors.colorForAlertness(score),
            "anillo exterior del orbe para " + score);
    }
    return true;
}

(:test)
function orbPaletteReturnsIndependentArrays(logger as Logger) as Boolean {
    var first = AlertnessColors.orbPalette(80);
    first[0] = 0;
    Test.assertEqualMessage(AlertnessColors.orbPalette(80)[0], Palette.ACCENT,
        "modificar un resultado no debe afectar a las llamadas siguientes");
    return true;
}

(:test)
function alertLevelColors(logger as Logger) as Boolean {
    Test.assertEqual(AlertnessColors.alertBackgroundColor(1), Palette.ORANGE);
    Test.assertEqual(AlertnessColors.alertBackgroundColor(2), Palette.ORANGE_DEEP);
    Test.assertEqual(AlertnessColors.alertBackgroundColor(3), Palette.RED_INTENSE);

    Test.assertEqual(AlertnessColors.alertTextColor(1), Palette.BACKGROUND);
    Test.assertEqual(AlertnessColors.alertTextColor(2), Palette.BACKGROUND);
    Test.assertEqual(AlertnessColors.alertTextColor(3), Palette.WHITE);

    // Fuera de rango se recorta a 1..3.
    Test.assertEqual(AlertnessColors.alertBackgroundColor(0), Palette.ORANGE);
    Test.assertEqual(AlertnessColors.alertBackgroundColor(7), Palette.RED_INTENSE);
    Test.assertEqual(AlertnessColors.alertTextColor(7), Palette.WHITE);
    return true;
}
