import Toybox.Application;
import Toybox.Lang;

//! Único sitio que lee y escribe los ajustes de usuario en Application.Properties
//! (resources/settings/properties.xml). El resto de la app usa el objeto Settings
//! (source/core/Settings.mc) que devuelve load(): nadie más lee propiedades sueltas.
//!
//! - load(): al abrir la app (FocusPulseApp.onStart) y cada vez que llegan cambios de la
//!   app Garmin Connect (onSettingsChanged). Un valor ausente, de otro tipo o fuera de
//!   rango se cambia por el de por defecto (Settings.*From).
//! - save(): desde el menú Ajustes del reloj, con cada cambio.
module AppSettings {

    //! Claves de las propiedades (ids de properties.xml).
    const SENSITIVITY = "sensitivity";
    const VIBRATION = "vibration";
    const SOUND = "sound";
    const REDUCED_ANIMATIONS = "reducedAnimations";
    const AI_CONFIRMATION = "aiConfirmation";
    const RECORD_ACTIVITY = "recordActivity";
    const DEMO_ON_START = "demoOnStart";
    const DEMO_AUTO_SCRIPT = "demoAutoScript";

    //! Ajustes guardados, validados.
    function load() as Settings {
        var settings = new Settings();
        settings.sensitivity = Settings.sensitivityFrom(read(SENSITIVITY));
        settings.vibration = Settings.vibrationFrom(read(VIBRATION));
        settings.sound = Settings.booleanFrom(read(SOUND), Settings.DEFAULT_SOUND);
        settings.reducedAnimations = Settings.booleanFrom(read(REDUCED_ANIMATIONS),
            Settings.DEFAULT_REDUCED_ANIMATIONS);
        settings.aiConfirmation = Settings.booleanFrom(read(AI_CONFIRMATION),
            Settings.DEFAULT_AI_CONFIRMATION);
        settings.recordActivity = Settings.booleanFrom(read(RECORD_ACTIVITY),
            Settings.DEFAULT_RECORD_ACTIVITY);
        settings.demoOnStart = Settings.booleanFrom(read(DEMO_ON_START),
            Settings.DEFAULT_DEMO_ON_START);
        settings.demoAutoScript = Settings.booleanFrom(read(DEMO_AUTO_SCRIPT),
            Settings.DEFAULT_DEMO_AUTO_SCRIPT);
        return settings;
    }

    //! Guarda todos los ajustes. Si no se puede escribir, el cambio dura hasta cerrar la
    //! app.
    function save(settings as Settings) as Void {
        try {
            Application.Properties.setValue(SENSITIVITY, settings.sensitivity as Number);
            Application.Properties.setValue(VIBRATION, settings.vibration as Number);
            Application.Properties.setValue(SOUND, settings.sound);
            Application.Properties.setValue(REDUCED_ANIMATIONS, settings.reducedAnimations);
            Application.Properties.setValue(AI_CONFIRMATION, settings.aiConfirmation);
            Application.Properties.setValue(RECORD_ACTIVITY, settings.recordActivity);
            Application.Properties.setValue(DEMO_ON_START, settings.demoOnStart);
            Application.Properties.setValue(DEMO_AUTO_SCRIPT, settings.demoAutoScript);
        } catch (e instanceof Lang.Exception) {
            // Propiedad inexistente o de otro tipo: se sigue con los ajustes en memoria.
        }
    }

    //! Valor de una propiedad, o null si no existe.
    function read(key as String) as Object? {
        try {
            return Application.Properties.getValue(key);
        } catch (e instanceof Lang.Exception) {
            // InvalidKeyException: propiedad de una versión que aún no la tenía.
            return null;
        }
    }
}
