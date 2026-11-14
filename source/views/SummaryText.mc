import Toybox.Lang;

//! Textos localizados del resumen de guardia: duración, respuesta, nivel y fatiga.
module SummaryText {

    //! Duración: "45 s", "1 min 32 s" (menos de 10 min), "47 min", "2 h 05 min".
    function duration(ms as Number) as String {
        var seconds = ms / 1000;
        if (seconds < 60) {
            return Lang.format(DemoText.text(Rez.Strings.DurationSecFormat), [seconds]);
        }
        var minutes = seconds / 60;
        if (minutes < 10) {
            return Lang.format(DemoText.text(Rez.Strings.DurationMinSecFormat),
                [minutes, (seconds % 60).format("%02d")]);
        }
        if (minutes < 60) {
            return Lang.format(DemoText.text(Rez.Strings.DurationMinFormat), [minutes]);
        }
        return Lang.format(DemoText.text(Rez.Strings.DurationHourFormat),
            [minutes / 60, (minutes % 60).format("%02d")]);
    }

    //! Tiempo de respuesta con una décima: "2,4 s" / "2.4 s"; "—" si no hay.
    function response(ms as Number?) as String {
        if (ms == null) {
            return DemoText.text(Rez.Strings.ValueNone);
        }
        var tenths = (ms + 50) / 100;
        return Lang.format(DemoText.text(Rez.Strings.ResponseFormat), [tenths / 10, tenths % 10]);
    }

    //! Nivel máximo: "2 de 3"; "—" sin episodios.
    function maxLevel(level as Number) as String {
        if (level <= 0) {
            return DemoText.text(Rez.Strings.ValueNone);
        }
        return Lang.format(DemoText.text(Rez.Strings.MaxLevelFormat), [level]);
    }

    function fatigue(level as FatigueLevel.Id) as String {
        if (level == FatigueLevel.HIGH) {
            return DemoText.text(Rez.Strings.FatigueHigh);
        }
        return DemoText.text(level == FatigueLevel.MODERATE ? Rez.Strings.FatigueModerate
            : Rez.Strings.FatigueLow);
    }

    //! Color de la fatiga: cian (Bajo), ámbar (Moderado), rojo (Alto). El nivel también va
    //! en texto: el color no es el único indicador.
    function fatigueColor(level as FatigueLevel.Id) as Number {
        if (level == FatigueLevel.HIGH) {
            return Palette.RED;
        }
        return level == FatigueLevel.MODERATE ? Palette.AMBER : Palette.ACCENT;
    }
}
