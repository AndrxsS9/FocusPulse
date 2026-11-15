import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Lang;
import Toybox.System;

//! Graba la guardia como una actividad (archivo FIT) con `ActivityRecording`.
//!
//! **Por qué.** Si la app pasa a inactiva (selector de tareas) sin grabar una actividad,
//! el acelerómetro baja a 10 Hz o falla y `Attention.vibrate` queda denegado. Con una
//! sesión grabando, el sistema mantiene sensores y vibración. Se puede desactivar con el
//! ajuste `recordActivity`.
//!
//! **Tipo de deporte.** `Activity.SPORT_GENERIC` + `Activity.SUB_SPORT_GENERIC`. Es el más
//! neutro de la API: es el valor por defecto de `createSession`, aparece como "Otro" en
//! Garmin Connect y no activa algoritmos propios de un deporte (cadencia, distancia,
//! detección de repeticiones). Se descartaron:
//! - `SPORT_MEDITATION` / `SUB_SPORT_BREATHING`: la guardia no es meditación y esas
//!   actividades alimentan estadísticas de mindfulness y estrés.
//! - `SPORT_TRAINING` / `SUB_SPORT_EXERCISE`: contaría como entrenamiento.
//! No se activa el GPS (no se llama a `Position.enableLocationEvents`), así que solo se
//! graban el tiempo y los sensores internos (p. ej. frecuencia cardiaca).
//!
//! Requiere el permiso `Fit` en manifest.xml.
class SessionRecorder {

    private var _name as String;
    private var _session as ActivityRecording.Session? = null;

    //! name: nombre de la actividad en el historial (máx. recomendado 15 caracteres).
    function initialize(name as String) {
        _name = name;
    }

    //! true si el dispositivo puede grabar actividades.
    static function isSupported() as Boolean {
        return Toybox has :ActivityRecording;
    }

    //! Crea la sesión si hace falta y empieza a grabar. Devuelve false si no se pudo;
    //! nunca lanza excepciones.
    function start() as Boolean {
        if (isRecording()) {
            return true;
        }
        if (!isSupported()) {
            return false;
        }
        try {
            var session = _session;
            if (session == null) {
                session = ActivityRecording.createSession({
                    :name => _name,
                    :sport => Activity.SPORT_GENERIC,
                    :subSport => Activity.SUB_SPORT_GENERIC
                });
                _session = session;
            }
            return session.start();
        } catch (e instanceof Lang.Exception) {
            logError("start", e);
            return false;
        }
    }

    //! Detiene la grabación y cierra la sesión: la guarda en el historial si save es
    //! true o la descarta si es false. Devuelve true si se guardó o descartó bien.
    //! Sin sesión no hace nada y devuelve false.
    function stop(save as Boolean) as Boolean {
        var session = _session;
        if (session == null) {
            return false;
        }
        var ok = false;
        try {
            if (session.isRecording()) {
                session.stop();
            }
            ok = save ? session.save() : session.discard();
        } catch (e instanceof Lang.Exception) {
            logError("stop", e);
        }
        // Liberar la referencia: solo puede existir una sesión a la vez.
        _session = null;
        return ok;
    }

    //! true mientras la sesión está grabando.
    function isRecording() as Boolean {
        var session = _session;
        return session != null && session.isRecording();
    }

    //! En depuración, el error queda en la consola; en release no se escribe nada.
    (:debug)
    private function logError(where as String, e as Lang.Exception) as Void {
        System.println("SessionRecorder." + where + ": " + e.getErrorMessage());
    }

    (:release)
    private function logError(where as String, e as Lang.Exception) as Void {
    }
}
