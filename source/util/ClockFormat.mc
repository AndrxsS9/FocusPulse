import Toybox.Lang;

//! Formato de la hora de la esfera, sin dependencias de Graphics ni WatchUi.
//!
//! El separador ":" es parte del formato numérico de la hora (igual en todos los
//! idiomas de la app), no un texto traducible.
module ClockFormat {

    //! Hora y minutos: "07:42" en 24 h; "7:42" en 12 h (sin a. m./p. m.; la 0 y las 12
    //! se muestran como 12).
    function hoursMinutes(hour as Number, minute as Number, is24Hour as Boolean) as String {
        if (is24Hour) {
            return hour.format("%02d") + ":" + minute.format("%02d");
        }
        var h = hour % 12;
        if (h == 0) {
            h = 12;
        }
        return h.format("%d") + ":" + minute.format("%02d");
    }

    //! Hora, minutos y segundos ("07:42:05" en 24 h, "7:42:05" en 12 h), para marcar
    //! eventos en la depuración.
    function hoursMinutesSeconds(hour as Number, minute as Number, second as Number,
            is24Hour as Boolean) as String {
        return hoursMinutes(hour, minute, is24Hour) + ":" + second.format("%02d");
    }

    //! Cuenta regresiva en minutos y segundos: "15:00", "0:05". Negativos como 0.
    function countdown(seconds as Number) as String {
        var s = seconds < 0 ? 0 : seconds;
        return (s / 60).format("%d") + ":" + (s % 60).format("%02d");
    }

    //! Nivel de batería (0–100, Float de System.Stats) redondeado y recortado.
    function batteryPercent(battery as Float) as Number {
        var value = (battery + 0.5f).toNumber();
        if (value < 0) {
            return 0;
        }
        return value > 100 ? 100 : value;
    }
}
