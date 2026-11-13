import Toybox.Application;
import Toybox.Lang;

//! Lectura tipada de los ajustes de usuario (resources/settings/properties.xml).
//!
//! Los ajustes se cambian desde la app Garmin Connect mientras la app está cerrada o
//! abierta; se leen cada vez que hacen falta (p. ej. al iniciar la guardia), así que no
//! hace falta reaccionar a onSettingsChanged().
module AppSettings {

    //! Clave de la propiedad "Grabar guardia como actividad".
    const RECORD_ACTIVITY = "recordActivity";

    //! true si la guardia debe grabarse como actividad (por defecto true).
    function recordActivity() as Boolean {
        return readBoolean(RECORD_ACTIVITY, true);
    }

    //! Lee una propiedad booleana; si falta o tiene otro tipo devuelve fallback.
    function readBoolean(key as String, fallback as Boolean) as Boolean {
        try {
            var value = Application.Properties.getValue(key);
            if (value instanceof Boolean) {
                return value;
            }
        } catch (e instanceof Lang.Exception) {
            // Propiedad inexistente (InvalidKeyException): se usa el valor por defecto.
        }
        return fallback;
    }
}
