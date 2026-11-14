import Toybox.Lang;
import Toybox.Test;

//! Pruebas de Settings (source/core): valores por defecto, validación de lo que llega de
//! Application.Properties y el aviso de alerta solo visual.

(:test)
function settingsDefaultsMatchProperties(logger as Logger) as Boolean {
    var settings = new Settings();
    // Los mismos valores que resources/settings/properties.xml.
    Test.assertEqual(settings.sensitivity, SensitivityLevel.MEDIUM);
    Test.assertEqual(settings.vibration, VibrationLevel.NORMAL);
    Test.assertMessage(settings.sound, "sonido activado por defecto");
    Test.assertMessage(!settings.reducedAnimations, "animaciones completas por defecto");
    Test.assertMessage(settings.aiConfirmation, "confirmación por IA activada por defecto");
    Test.assertMessage(settings.recordActivity, "grabar actividad activado por defecto");
    return true;
}

(:test)
function settingsRejectInvalidValues(logger as Logger) as Boolean {
    Test.assertEqual(Settings.sensitivityFrom(0), SensitivityLevel.LOW);
    Test.assertEqual(Settings.sensitivityFrom(2), SensitivityLevel.HIGH);
    Test.assertEqual(Settings.sensitivityFrom(3), SensitivityLevel.MEDIUM);
    Test.assertEqual(Settings.sensitivityFrom(-1), SensitivityLevel.MEDIUM);
    Test.assertEqual(Settings.sensitivityFrom(null), SensitivityLevel.MEDIUM);
    Test.assertEqual(Settings.sensitivityFrom("2"), SensitivityLevel.MEDIUM);

    Test.assertEqual(Settings.vibrationFrom(0), VibrationLevel.OFF);
    Test.assertEqual(Settings.vibrationFrom(3), VibrationLevel.STRONG);
    Test.assertEqual(Settings.vibrationFrom(4), VibrationLevel.NORMAL);
    Test.assertEqual(Settings.vibrationFrom(1.0f), VibrationLevel.NORMAL);

    Test.assertMessage(!Settings.booleanFrom(false, true), "false se respeta");
    Test.assertMessage(Settings.booleanFrom(null, true), "sin valor: el de por defecto");
    Test.assertMessage(!Settings.booleanFrom(1, false), "un número no es un booleano");
    return true;
}

(:test)
function settingsCopyIsIndependent(logger as Logger) as Boolean {
    var settings = new Settings();
    var copy = settings.copy();
    copy.vibration = VibrationLevel.OFF;
    copy.sound = false;
    copy.sensitivity = SensitivityLevel.HIGH;
    Test.assertEqual(settings.vibration, VibrationLevel.NORMAL);
    Test.assertMessage(settings.sound, "el original no cambia");
    Test.assertEqual(settings.sensitivity, SensitivityLevel.MEDIUM);
    return true;
}

(:test)
function settingsDetectVisualOnlyAlert(logger as Logger) as Boolean {
    var settings = new Settings();
    Test.assertMessage(!settings.isVisualOnly(true, true), "vibra y suena");

    settings.vibration = VibrationLevel.OFF;
    Test.assertMessage(!settings.isVisualOnly(true, true), "sin vibración pero con sonido");
    Test.assertMessage(settings.isVisualOnly(true, false), "sin vibración y el reloj no suena");

    settings.sound = false;
    Test.assertMessage(settings.isVisualOnly(true, true), "vibración y sonido apagados");

    settings.vibration = VibrationLevel.SOFT;
    Test.assertMessage(!settings.isVisualOnly(true, false), "vibración suave basta");
    Test.assertMessage(settings.isVisualOnly(false, true),
        "vibración elegida pero apagada en el reloj, y sonido apagado");
    return true;
}
