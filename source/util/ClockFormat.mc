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

    //! Nivel de batería (0–100, Float de System.Stats) redondeado y recortado.
    function batteryPercent(battery as Float) as Number {
        var value = (battery + 0.5f).toNumber();
        if (value < 0) {
            return 0;
        }
        return value > 100 ? 100 : value;
    }
}
