import Toybox.Lang;

//! Colores que dependen del nivel de alerta del usuario.
//!
//! Lógica pura: no importa WatchUi ni Graphics. Solo devuelve números de color
//! tomados de los tokens de Palette (source/util/Palette.mc, módulo de constantes
//! sin dependencias), para poder probarse con Toybox.Test.
//!
//! El puntaje de alerta va de 0 (dormido) a 100 (bien despierto). Los valores
//! fuera de ese rango se recortan.
module AlertnessColors {

    //! Bandas de alerta según el puntaje.
    enum AlertnessBand {
        BAND_LOW,     //! < 35: somnolencia, rojo.
        BAND_MEDIUM,  //! 35..59: atención, ámbar.
        BAND_HIGH     //! >= 60: despierto, cian.
    }

    //! Puntaje mínimo de la banda alta (cian).
    const HIGH_THRESHOLD = 60;

    //! Puntaje mínimo de la banda media (ámbar).
    const MEDIUM_THRESHOLD = 35;

    //! Nivel de alerta (pantalla completa) mínimo y máximo.
    const MIN_ALERT_LEVEL = 1;
    const MAX_ALERT_LEVEL = 3;

    //! Recorta el puntaje al rango 0..100.
    function clampScore(score as Number) as Number {
        if (score < 0) {
            return 0;
        }
        if (score > 100) {
            return 100;
        }
        return score;
    }

    //! Banda de alerta para un puntaje.
    function bandForScore(score as Number) as AlertnessBand {
        var clamped = clampScore(score);
        if (clamped >= HIGH_THRESHOLD) {
            return BAND_HIGH;
        }
        if (clamped >= MEDIUM_THRESHOLD) {
            return BAND_MEDIUM;
        }
        return BAND_LOW;
    }

    //! Color del anillo y del porcentaje: cian (>= 60), ámbar (>= 35), rojo (< 35).
    function colorForAlertness(score as Number) as Number {
        var band = bandForScore(score);
        if (band == BAND_HIGH) {
            return Palette.ACCENT;
        }
        if (band == BAND_MEDIUM) {
            return Palette.AMBER;
        }
        return Palette.RED;
    }

    //! Los 3 colores de los anillos del orbe IA, del exterior al interior.
    //! El primero siempre coincide con colorForAlertness(score).
    //! Devuelve un arreglo nuevo en cada llamada (el llamador puede modificarlo).
    function orbPalette(score as Number) as Array<Number> {
        var band = bandForScore(score);
        if (band == BAND_HIGH) {
            return [Palette.ACCENT, Palette.ACCENT_LIGHT, Palette.VIOLET] as Array<Number>;
        }
        if (band == BAND_MEDIUM) {
            return [Palette.AMBER, Palette.ORANGE, Palette.VIOLET] as Array<Number>;
        }
        return [Palette.RED, Palette.RED_INTENSE, Palette.ORANGE] as Array<Number>;
    }

    //! Recorta el nivel de alerta al rango 1..3.
    function clampAlertLevel(level as Number) as Number {
        if (level < MIN_ALERT_LEVEL) {
            return MIN_ALERT_LEVEL;
        }
        if (level > MAX_ALERT_LEVEL) {
            return MAX_ALERT_LEVEL;
        }
        return level;
    }

    //! Fondo de la alerta a pantalla completa:
    //! 1 naranja, 2 naranja intenso, 3 rojo intenso.
    function alertBackgroundColor(level as Number) as Number {
        var clamped = clampAlertLevel(level);
        if (clamped == 1) {
            return Palette.ORANGE;
        }
        if (clamped == 2) {
            return Palette.ORANGE_DEEP;
        }
        return Palette.RED_INTENSE;
    }

    //! Color del texto sobre alertBackgroundColor(level), elegido por contraste
    //! (mínimo 4,5:1): texto oscuro sobre los naranjas y blanco puro sobre el rojo
    //! intenso.
    function alertTextColor(level as Number) as Number {
        if (clampAlertLevel(level) == MAX_ALERT_LEVEL) {
            return Palette.WHITE;
        }
        return Palette.BACKGROUND;
    }
}
