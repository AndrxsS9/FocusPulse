import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

//! Pruebas de AppSettings con el Application.Properties real del simulador. Deja los
//! ajustes como estaban antes de la prueba.

(:test)
function appSettingsSavesAndLoads(logger as Logger) as Boolean {
    var previous = AppSettings.load();
    try {
        var settings = new Settings();
        settings.sensitivity = SensitivityLevel.HIGH;
        settings.vibration = VibrationLevel.OFF;
        settings.sound = false;
        settings.reducedAnimations = true;
        settings.aiConfirmation = false;
        settings.recordActivity = false;
        settings.demoOnStart = true;
        settings.demoAutoScript = true;
        AppSettings.save(settings);

        var loaded = AppSettings.load();
        Test.assertEqual(loaded.sensitivity, SensitivityLevel.HIGH);
        Test.assertEqual(loaded.vibration, VibrationLevel.OFF);
        Test.assertMessage(!loaded.sound, "sonido guardado");
        Test.assertMessage(loaded.reducedAnimations, "animaciones reducidas guardadas");
        Test.assertMessage(!loaded.aiConfirmation, "confirmación por IA guardada");
        Test.assertMessage(!loaded.recordActivity, "grabar actividad guardado");
        Test.assertMessage(loaded.demoOnStart, "iniciar en modo demo guardado");
        Test.assertMessage(loaded.demoAutoScript, "guion automático al abrir guardado");

        // Un valor fuera de rango (p. ej. de otra versión) vuelve al de por defecto.
        Application.Properties.setValue(AppSettings.VIBRATION, 9);
        Test.assertEqual(AppSettings.load().vibration, VibrationLevel.NORMAL);
        // Una clave que no existe no rompe nada.
        Test.assertMessage(AppSettings.read("noExiste") == null, "clave inexistente: null");
    } finally {
        AppSettings.save(previous);
    }
    return true;
}
