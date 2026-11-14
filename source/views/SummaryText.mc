import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

//! Textos localizados del resumen de guardia y del historial: duración, respuesta,
//! nivel, fatiga, episodios y fecha.
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

    //! "1 episodio" / "3 episodios".
    function episodes(count as Number) as String {
        if (count == 1) {
            return DemoText.text(Rez.Strings.EpisodesOne);
        }
        return Lang.format(DemoText.text(Rez.Strings.EpisodesFormat), [count]);
    }

    //! Inicio de la guardia: "14 nov · 10:32" (español) / "Nov 14 · 10:32" (inglés), con
    //! la hora en 24 h o 12 h según el reloj.
    function date(dateSec as Number) as String {
        var info = Gregorian.info(new Time.Moment(dateSec), Time.FORMAT_MEDIUM);
        var month = info.month as String;
        if (DemoText.text(Rez.Strings.DateCase).equals("lower")) {
            month = month.toLower();
        }
        var time = ClockFormat.hoursMinutes(info.hour, info.min,
            System.getDeviceSettings().is24Hour);
        return Lang.format(DemoText.text(Rez.Strings.HistoryItemFormat), [info.day, month, time]);
    }

    //! Línea secundaria de la lista: "1 min 32 s · 3 episodios".
    function historyLine(summary as GuardSummary) as String {
        return Lang.format(DemoText.text(Rez.Strings.HistorySubFormat),
            [duration(summary.durationMs), episodes(summary.episodes)]);
    }

    //! Subtítulo de "Historial" en el menú: "3 guardias", "1 guardia" o "Aún no hay
    //! guardias".
    function historyCount(count as Number) as String {
        if (count == 0) {
            return DemoText.text(Rez.Strings.HistoryEmpty);
        }
        if (count == 1) {
            return DemoText.text(Rez.Strings.HistoryCountOne);
        }
        return Lang.format(DemoText.text(Rez.Strings.HistoryCountFormat), [count]);
    }
}
