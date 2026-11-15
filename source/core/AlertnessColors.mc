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

    //! Los 3 colores de los contornos del orbe IA (A, B, C), los del diseño web:
    //! cian / cian claro / violeta (>= 60), ámbar / ámbar claro / naranja (35–59) y
    //! rojo / rojo claro / ámbar (< 35). El primero siempre coincide con
    //! colorForAlertness(score).
    //! Devuelve un arreglo nuevo en cada llamada (el llamador puede modificarlo).
    function orbPalette(score as Number) as Array<Number> {
        var band = bandForScore(score);
        if (band == BAND_HIGH) {
            return [Palette.ACCENT, Palette.ACCENT_LIGHT, Palette.VIOLET] as Array<Number>;
        }
        if (band == BAND_MEDIUM) {
            return [Palette.AMBER, Palette.AMBER_LIGHT, Palette.ORANGE] as Array<Number>;
        }
        return [Palette.RED, Palette.RED_LIGHT, Palette.AMBER] as Array<Number>;
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

    //! Opacidad mínima (milésimas) del fondo de los niveles 1 y 2 en el pulso de brillo,
    //! que se simula mezclando con negro (diseño web: 1 → 0,72 → 1).
    //! - Nivel 1: 0,72, como el diseño; el texto negro queda en 4,83:1.
    //! - Nivel 2: el diseño también pide 0,72, pero ORANGE_DEEP al 0,72 deja el texto
    //!   negro en 3,81:1 (< 4,5:1). Se conserva la profundidad que ya tenía la app, 0,88
    //!   (5,3:1), y se anota en docs/PENDIENTES.md.
    const ALERT_PULSE_MIN_ALPHA = [720, 880];

    //! Fondo de la alerta en un momento del pulso (pulse 0–1, ver AlertVisuals.pulse):
    //! - niveles 1 y 2: el color del nivel en 0 y, en 1, mezclado con negro hasta su
    //!   opacidad mínima (ALERT_PULSE_MIN_ALPHA);
    //! - nivel 3: de RED_INTENSE en 0 a RED_DARK en 1 (parpadeo de 0,5 s hacia cada
    //!   color).
    function alertPulseColor(level as Number, pulse as Float) as Number {
        var p = pulse < 0.0f ? 0.0f : (pulse > 1.0f ? 1.0f : pulse);
        var clamped = clampAlertLevel(level);
        if (clamped == MAX_ALERT_LEVEL) {
            return ColorMath.blend(Palette.RED_DARK, Palette.RED_INTENSE, (1000 * p + 0.5f).toNumber());
        }
        var minAlpha = (ALERT_PULSE_MIN_ALPHA as Array<Number>)[clamped - 1];
        return ColorMath.blend(alertBackgroundColor(level), Palette.BLACK,
            1000 - ((1000 - minAlpha) * p + 0.5f).toNumber());
    }

    //! Color del texto sobre alertBackgroundColor(level), elegido por contraste
    //! (mínimo 4,5:1): negro sobre los naranjas y blanco puro sobre los rojos del
    //! nivel 3.
    function alertTextColor(level as Number) as Number {
        if (clampAlertLevel(level) == MAX_ALERT_LEVEL) {
            return Palette.WHITE;
        }
        return Palette.BLACK;
    }
}
