import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Esfera principal (vista de guardia).
//!
//! Orden de dibujo, de atrás hacia delante:
//!   1. fondo (BACKGROUND);
//!   2. orbe IA detrás de la hora (reservado: llega en la fase siguiente);
//!   3. anillo de nivel de alerta en el borde;
//!   4. contenido.
//!
//! Medidas: RoundLayout (source/util/Layout.mc) y docs/DISENO.md.
class MainView extends WatchUi.View {

    //! Batería en o por debajo de este porcentaje: ícono y número en rojo.
    const BATTERY_LOW = 15;

    //! Ícono de batería, en milésimas del lado de la pantalla (fr165: 27×14 px).
    const BATTERY_WIDTH = 70;
    const BATTERY_HEIGHT = 36;

    //! Separación (px, en milésimas) entre el ícono de batería y su porcentaje.
    const BATTERY_GAP = 15;

    private var _guard as GuardController;
    private var _layout as RoundLayout?;

    private var _percentFormat as String = "";
    private var _dateFormat as String = "";
    private var _dateLowercase as Boolean = false;
    private var _statusPaused as String = "";
    private var _statusActive as String = "";
    private var _statusSensorUnavailable as String = "";
    private var _statusDemo as String = "";

    function initialize(guard as GuardController) {
        View.initialize();
        _guard = guard;
    }

    function onLayout(dc as Dc) as Void {
        _layout = new RoundLayout(dc.getWidth(), dc.getHeight());
        _percentFormat = WatchUi.loadResource(Rez.Strings.PercentFormat) as String;
        _dateFormat = WatchUi.loadResource(Rez.Strings.DateFormat) as String;
        _dateLowercase = (WatchUi.loadResource(Rez.Strings.DateCase) as String).equals("lower");
        _statusPaused = WatchUi.loadResource(Rez.Strings.StatusPaused) as String;
        _statusActive = WatchUi.loadResource(Rez.Strings.StatusActive) as String;
        _statusSensorUnavailable = WatchUi.loadResource(Rez.Strings.StatusSensorUnavailable) as String;
        _statusDemo = WatchUi.loadResource(Rez.Strings.StatusDemo) as String;
    }

    function onUpdate(dc as Dc) as Void {
        var layout = _layout;
        if (layout == null) {
            return;
        }
        Draw.enableAntiAlias(dc);
        var score = _guard.alertness();

        Draw.clear(dc, Palette.BACKGROUND);
        drawOrb(dc, layout, score);
        drawRing(dc, layout, score);
        drawContent(dc, layout);
    }

    //! Orbe IA detrás de la hora. Reservado para la fase siguiente: el espacio
    //! (layout.orbRadius alrededor de la hora) y su lugar en el orden de dibujo ya están.
    private function drawOrb(dc as Dc, layout as RoundLayout, score as Number) as Void {
    }

    //! Anillo de nivel de alerta: pista RING_TRACK completa y avance desde las 12 en
    //! sentido horario, del color de la banda del puntaje.
    private function drawRing(dc as Dc, layout as RoundLayout, score as Number) as Void {
        Draw.progressRing(dc, layout.centerX, layout.centerY, layout.ringRadius, layout.ringWidth,
            score, Palette.RING_TRACK, AlertnessColors.colorForAlertness(score));
    }

    private function drawContent(dc as Dc, layout as RoundLayout) as Void {
        drawBattery(dc, layout);
        drawClock(dc, layout);
        drawStatus(dc, layout);
    }

    //! Ícono de batería y porcentaje real, centrados en topY.
    private function drawBattery(dc as Dc, layout as RoundLayout) as Void {
        var percent = ClockFormat.batteryPercent(System.getSystemStats().battery);
        var color = percent <= BATTERY_LOW ? Palette.RED : Palette.TEXT_SECONDARY;
        var text = Lang.format(_percentFormat, [percent]);

        var iconWidth = layout.scaled(BATTERY_WIDTH);
        var iconHeight = layout.scaled(BATTERY_HEIGHT);
        var gap = layout.scaled(BATTERY_GAP);
        var textWidth = dc.getTextWidthInPixels(text, Typography.LABEL);
        var left = layout.centerX - (iconWidth + gap + textWidth) / 2;

        Draw.battery(dc, new Rect(left, layout.topY - iconHeight / 2, iconWidth, iconHeight),
            percent, color);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + iconWidth + gap, layout.topY, Typography.LABEL, text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! Hora grande (24 h o 12 h según el sistema) y fecha corta en el idioma del reloj.
    private function drawClock(dc as Dc, layout as RoundLayout) as Void {
        var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var time = ClockFormat.hoursMinutes(now.hour, now.min, System.getDeviceSettings().is24Hour);
        Draw.centeredText(dc, layout.centerX, layout.timeY, Typography.TIME, time, Palette.TEXT);

        var weekday = now.day_of_week as String;
        var month = now.month as String;
        if (_dateLowercase) {
            weekday = weekday.toLower();
            month = month.toLower();
        }
        var date = Lang.format(_dateFormat, [weekday, now.day, month]);
        Draw.centeredText(dc, layout.centerX, layout.dateY, Typography.LABEL, date,
            Palette.TEXT_SECONDARY);
    }

    //! Estado provisional en texto (la píldora llega en el siguiente paso).
    private function drawStatus(dc as Dc, layout as RoundLayout) as Void {
        var text = _statusPaused;
        var color = Palette.TEXT_SECONDARY;
        if (_guard.isActive()) {
            text = _statusActive;
            color = Palette.ACCENT;
        } else if (_guard.isSensorUnavailable()) {
            text = _statusSensorUnavailable;
            color = Palette.AMBER;
        }
        Draw.centeredText(dc, layout.centerX, layout.pillY, Typography.LABEL, text, color);
        if (_guard.isDemoSource()) {
            Draw.centeredText(dc, layout.centerX, layout.footerY, Typography.LABEL, _statusDemo,
                Palette.TEXT_SECONDARY);
        }
    }
}
