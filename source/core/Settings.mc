import Toybox.Lang;

//! Sensibilidad del detector (ajuste "Sensibilidad").
module SensitivityLevel {

    enum Id {
        //! Menos alertas: hace falta una caída más brusca y más inclinada, y más tiempo
        //! inmóvil.
        LOW = 0,
        //! Valores de siempre (fases 6–10).
        MEDIUM = 1,
        //! Más alertas: caídas más suaves y menos tiempo inmóvil.
        HIGH = 2
    }

    const COUNT = 3;
}

//! Nivel de vibración de la alerta (ajuste "Vibración"). Los Forerunner ignoran la
//! intensidad del motor: los niveles cambian el número y la duración de los pulsos
//! (VibePatterns).
module VibrationLevel {

    enum Id {
        OFF = 0,
        SOFT = 1,
        //! Patrones de siempre (fase 7).
        NORMAL = 2,
        STRONG = 3
    }

    const COUNT = 4;
}

//! Ajustes de usuario ya validados: lo que el resto de la app necesita saber de
//! resources/settings/properties.xml.
//!
//! Lógica pura (sin Application.Properties): AppSettings (source/app) es el único sitio
//! que lee y escribe las propiedades y las convierte con los *From de esta clase, que
//! descartan valores ausentes, de otro tipo o fuera de rango y ponen el valor por
//! defecto. Así una propiedad dañada o de otra versión nunca rompe la app.
class Settings {

    //! Valores por defecto (los mismos que resources/settings/properties.xml).
    static const DEFAULT_SENSITIVITY = SensitivityLevel.MEDIUM;
    static const DEFAULT_VIBRATION = VibrationLevel.NORMAL;
    static const DEFAULT_SOUND = true;
    static const DEFAULT_REDUCED_ANIMATIONS = false;
    static const DEFAULT_AI_CONFIRMATION = true;
    static const DEFAULT_RECORD_ACTIVITY = true;
    static const DEFAULT_DEMO_ON_START = false;
    static const DEFAULT_DEMO_AUTO_SCRIPT = false;

    var sensitivity as SensitivityLevel.Id = DEFAULT_SENSITIVITY;
    var vibration as VibrationLevel.Id = DEFAULT_VIBRATION;

    //! Tonos de alerta (solo si el reloj tiene altavoz o zumbador).
    var sound as Boolean = DEFAULT_SOUND;

    //! Orbe sin partículas, alerta sin sacudida y con el pulso más lento.
    var reducedAnimations as Boolean = DEFAULT_REDUCED_ANIMATIONS;

    //! El modelo confirma los cabeceos del detector antes de abrir la alerta.
    var aiConfirmation as Boolean = DEFAULT_AI_CONFIRMATION;

    //! Grabar la guardia como actividad (fase 3).
    var recordActivity as Boolean = DEFAULT_RECORD_ACTIVITY;

    //! "Iniciar en modo demo": al abrir la app el modo demo queda activo (DemoLaunch).
    var demoOnStart as Boolean = DEFAULT_DEMO_ON_START;

    //! "Guion automático al abrir": al abrir la app, el modo demo y, a los 3 s, el guion
    //! automático (DemoLaunch). Para la sustentación sin tocar nada.
    var demoAutoScript as Boolean = DEFAULT_DEMO_AUTO_SCRIPT;

    function initialize() {
    }

    //! Copia independiente (los menús editan una copia y la guardan).
    function copy() as Settings {
        var other = new Settings();
        other.sensitivity = sensitivity;
        other.vibration = vibration;
        other.sound = sound;
        other.reducedAnimations = reducedAnimations;
        other.aiConfirmation = aiConfirmation;
        other.recordActivity = recordActivity;
        other.demoOnStart = demoOnStart;
        other.demoAutoScript = demoAutoScript;
        return other;
    }

    //! true si la alerta quedaría solo visual: no vibra (apagada aquí, sin motor o
    //! apagada en el reloj) y no suena (apagado aquí, sin altavoz o tonos apagados en el
    //! reloj). canVibrate y canPlayTone son lo que permite el reloj (Haptics).
    function isVisualOnly(canVibrate as Boolean, canPlayTone as Boolean) as Boolean {
        var vibrates = vibration != VibrationLevel.OFF && canVibrate;
        var sounds = sound && canPlayTone;
        return !vibrates && !sounds;
    }

    //! Sensibilidad a partir de un valor de Properties (Number 0–2).
    static function sensitivityFrom(value as Object?) as SensitivityLevel.Id {
        if (value instanceof Number && value >= 0 && value < SensitivityLevel.COUNT) {
            return value as SensitivityLevel.Id;
        }
        return DEFAULT_SENSITIVITY;
    }

    //! Vibración a partir de un valor de Properties (Number 0–3).
    static function vibrationFrom(value as Object?) as VibrationLevel.Id {
        if (value instanceof Number && value >= 0 && value < VibrationLevel.COUNT) {
            return value as VibrationLevel.Id;
        }
        return DEFAULT_VIBRATION;
    }

    //! Booleano a partir de un valor de Properties; fallback si no es Boolean.
    static function booleanFrom(value as Object?, fallback as Boolean) as Boolean {
        if (value instanceof Boolean) {
            return value;
        }
        return fallback;
    }
}
