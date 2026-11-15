import Toybox.Attention;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;

//! Vibración, luz de pantalla y tono de la alerta (adaptador de Toybox.Attention).
//!
//! - start(nivel): convierte el patrón del nivel y del ajuste de vibración
//!   (VibePatterns.segments) en VibeProfile (tramos pares encendidos al 100 %, impares
//!   apagados al 0 %) y lo repite cada VibePatterns.periodMs con un Timer. La primera
//!   ráfaga sale enseguida.
//! - **Vibración** solo si el reloj la tiene (`Attention has :vibrate`), el usuario no
//!   la apagó en el reloj (DeviceSettings.vibrateOn) y el ajuste "Vibración" no está en
//!   Apagada (setVibration). Si no, la alerta no vibra.
//! - **Luz**: Attention.backlight(true) en cada ráfaga, para que la pantalla siga
//!   encendida mientras dura la alerta. En AMOLED con protección contra quemado lanza
//!   BacklightOnTooLongException si se mantiene demasiado tiempo: se atrapa y se sigue.
//! - **Tono**: un tono por pulso (ToneProfile con silencios en las pausas) si existe
//!   Attention.playTone (hasToneHardware), los tonos están activados en el reloj
//!   (DeviceSettings.tonesOn) y el ajuste "Sonido" está activado (setSound). Si el
//!   reloj no tiene ToneProfile, un TONE_ALERT_HI por ráfaga. Si no, nada.
//! - stop(): detiene el timer y corta la ráfaga en curso con un VibeProfile nulo.
//! - notify(): un aviso suave y único (dos pulsos cortos del nivel 1, sin tono ni
//!   repetición), p. ej. al terminar el descanso guiado.
//!
//! Attention puede quedar denegada (app inactiva sin grabar actividad): cada llamada va
//! dentro de try/catch para que la alerta visual nunca se caiga por el hardware.
class Haptics {

    //! Tono de cada pulso (Hz) y largo del VibeProfile que corta una ráfaga (ms).
    const TONE_HZ = 2500;
    const STOP_MS = 10;

    private var _timer as Timer.Timer? = null;
    private var _level as Number = 1;

    //! Ajuste "Vibración": cuántos pulsos y de qué duración (VibePatterns).
    private var _vibration as VibrationLevel.Id = VibrationLevel.NORMAL;

    //! Ajuste "Sonido": tonos de alerta (solo en relojes con playTone).
    private var _sound as Boolean = true;
    private var _vibes as Array<Attention.VibeProfile>? = null;
    private var _tones as Array<Attention.ToneProfile>? = null;

    //! true mientras repite el patrón.
    private var _running as Boolean = false;

    //! Ráfagas emitidas desde start() (para la depuración).
    private var _bursts as Number = 0;

    function initialize() {
    }

    //! Aplica el ajuste "Vibración". Si hay una alerta en marcha, el cambio se nota en su
    //! próxima subida de nivel (o en la siguiente alerta).
    function setVibration(vibration as VibrationLevel.Id) as Void {
        _vibration = vibration;
    }

    //! Vibración que de verdad tendrá la alerta: la del ajuste, u OFF si el reloj no
    //! puede vibrar o el usuario la apagó en el reloj.
    function alertVibration() as VibrationLevel.Id {
        return canVibrate() ? _vibration : VibrationLevel.OFF;
    }

    //! Aplica el ajuste "Sonido". Si hay una alerta en marcha, se nota desde la próxima
    //! ráfaga.
    function setSound(enabled as Boolean) as Void {
        _sound = enabled;
        if (!enabled) {
            _tones = null;
        } else if (_running && _tones == null && canPlayTone()) {
            _tones = buildTones(_level, _vibration);
        }
    }

    //! true si la alerta sonará: el ajuste está activado y el reloj puede sonar.
    function alertSounds() as Boolean {
        return _sound && canPlayTone();
    }

    //! true si el reloj tiene altavoz o zumbador (Attention.playTone). Sin él, la app
    //! esconde el ajuste "Sonido".
    static function hasToneHardware() as Boolean {
        return Attention has :playTone;
    }

    //! true si el reloj puede vibrar y el usuario tiene la vibración activada.
    static function canVibrate() as Boolean {
        return (Attention has :vibrate) && System.getDeviceSettings().vibrateOn;
    }

    //! true si el reloj puede sonar y el usuario tiene los tonos activados.
    static function canPlayTone() as Boolean {
        return (Attention has :playTone) && System.getDeviceSettings().tonesOn;
    }

    //! Empieza (o cambia) el patrón del nivel 1–3 y lo repite hasta stop().
    function start(level as Number) as Void {
        stopTimer();
        _level = AlertnessColors.clampAlertLevel(level);
        _vibes = alertVibration() != VibrationLevel.OFF ? buildVibes(_level, _vibration) : null;
        _tones = alertSounds() ? buildTones(_level, _vibration) : null;
        _running = true;
        _bursts = 0;
        logStart();

        burst();
        var timer = new Timer.Timer();
        timer.start(method(:onTick), VibePatterns.periodMs(_level), true);
        _timer = timer;
    }

    //! Detiene la repetición y corta la vibración en curso.
    function stop() as Void {
        var wasRunning = _running;
        stopTimer();
        _running = false;
        if (wasRunning && _vibes != null) {
            try {
                Attention.vibrate([new Attention.VibeProfile(0, STOP_MS)]);
            } catch (e instanceof Lang.Exception) {
                // Sin permiso de Attention: la ráfaga termina sola.
            }
        }
        _vibes = null;
        _tones = null;
    }

    //! Aviso suave de una sola ráfaga (patrón del nivel 1) y luz. No interfiere con una
    //! alerta en marcha: si hay una, no hace nada.
    function notify() as Void {
        if (_running) {
            return;
        }
        lightUp();
        if (alertVibration() == VibrationLevel.OFF) {
            return;
        }
        try {
            Attention.vibrate(buildVibes(1, _vibration));
        } catch (e instanceof Lang.Exception) {
            // Sin permiso de Attention: queda el aviso en pantalla.
        }
    }

    function isRunning() as Boolean {
        return _running;
    }

    //! Callback del timer: una ráfaga más.
    function onTick() as Void {
        if (_running) {
            burst();
        }
    }

    private function stopTimer() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
        }
        _timer = null;
    }

    //! Una ráfaga: luz, vibración y tono.
    private function burst() as Void {
        _bursts++;
        lightUp();
        var vibes = _vibes;
        if (vibes != null) {
            try {
                Attention.vibrate(vibes);
            } catch (e instanceof Lang.Exception) {
                // Attention denegada (app inactiva): queda la alerta visual.
            }
        }
        playTones();
    }

    private function lightUp() as Void {
        if (!(Attention has :backlight)) {
            return;
        }
        try {
            Attention.backlight(true);
        } catch (e instanceof Lang.Exception) {
            // BacklightOnTooLongException (protección contra quemado) u otra negativa:
            // la alerta sigue con el brillo que el sistema permita.
        }
    }

    private function playTones() as Void {
        if (!alertSounds()) {
            return;
        }
        try {
            var tones = _tones;
            if (tones != null) {
                Attention.playTone({ :toneProfile => tones });
            } else {
                Attention.playTone(Attention.TONE_ALERT_HI);
            }
        } catch (e instanceof Lang.Exception) {
            // Perfil no admitido: en adelante, el tono predefinido.
            _tones = null;
        }
    }

    //! VibeProfile del nivel: tramos pares encendidos, impares apagados.
    private static function buildVibes(level as Number, vibration as VibrationLevel.Id)
            as Array<Attention.VibeProfile> {
        var segments = VibePatterns.segments(level, vibration);
        var vibes = new Array<Attention.VibeProfile>[segments.size()];
        for (var i = 0; i < segments.size(); i++) {
            vibes[i] = new Attention.VibeProfile(i % 2 == 0 ? 100 : 0, segments[i]);
        }
        return vibes;
    }

    //! Un tono por pulso, con silencios (0 Hz) en las pausas. null si el reloj no tiene
    //! ToneProfile (se usa el tono predefinido).
    private function buildTones(level as Number, vibration as VibrationLevel.Id)
            as Array<Attention.ToneProfile>? {
        if (!(Attention has :ToneProfile)) {
            return null;
        }
        var segments = VibePatterns.segments(level, vibration);
        var tones = new Array<Attention.ToneProfile>[segments.size()];
        for (var i = 0; i < segments.size(); i++) {
            tones[i] = new Attention.ToneProfile(i % 2 == 0 ? TONE_HZ : 0, segments[i]);
        }
        return tones;
    }

    //! En depuración, qué puede hacer el reloj al empezar cada alerta.
    (:debug)
    private function logStart() as Void {
        System.println("ALERTA nivel " + _level + ": vibración "
            + (_vibes != null ? VibePatterns.segments(_level, _vibration).toString() + " cada "
                + VibePatterns.periodMs(_level) + " ms (ajuste " + (_vibration as Number) + ")"
                : "no (apagada en el ajuste o en el reloj, o sin motor)")
            + ", tono " + (alertSounds() ? (_tones != null ? "por pulso" : "predefinido")
                : (_sound ? "no (el reloj no suena)" : "no (ajuste Sonido apagado)"))
            + ", luz " + ((Attention has :backlight) ? "sí" : "no"));
    }

    (:release)
    private function logStart() as Void {
    }

    //! Ráfagas emitidas desde el último start().
    function bursts() as Number {
        return _bursts;
    }
}
