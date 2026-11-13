import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Detector en vivo (solo en depuración): para recorrer los escenarios en el simulador y
//! ver qué decide el detector y qué opina el clasificador.
//!
//! De arriba abajo: estado del detector (pausa, calibrando, vigilando, caída detectada o
//! el evento recién emitido), fuente de datos, una barra por clase con su probabilidad
//! suavizada (la ganadora en texto claro), línea base y umbral de quietud efectivo,
//! quietud e inclinación, y el último evento con su hora.
//!
//! Se redibuja con cada lote (GuardController.onBatch pide requestUpdate). La entrada es
//! la de la telemetría en vivo (TelemetryDebugDelegate): START inicia o pausa la guardia
//! y UP/DOWN cambian de fuente.
(:debug)
class DetectorDebugView extends WatchUi.View {

    //! Centros verticales, en milésimas de la altura: estado, fuente, las 4 barras,
    //! línea base, quietud e inclinación, último evento.
    const STATE_Y = 150;
    const SOURCE_Y = 230;
    const BAR_Y = [325, 405, 485, 565];
    const BASELINE_Y = 650;
    const STILL_Y = 730;
    const EVENT_Y = 810;

    //! Ancho máximo de las filas de barras, separación entre la barra y los textos, y
    //! alto de la barra, en milésimas del lado (fr165: 304, 9 y 10 px). El espacio de la
    //! etiqueta y del porcentaje se mide con la fuente en onLayout.
    const ROW_MAX_WIDTH = 780;
    const BAR_GAP = 24;
    const BAR_HEIGHT = 26;

    //! Color de la barra de cada clase, en el orden de DrowsinessClass.
    const CLASS_COLORS = [Palette.ACCENT, Palette.ACCENT_LIGHT, Palette.RED, Palette.AMBER];

    private var _guard as GuardController;
    private var _layout as RoundLayout?;

    private var _classNames as Array<String> = [] as Array<String>;
    private var _paused as String = "";
    private var _calibrating as String = "";
    private var _watching as String = "";
    private var _fallDetected as String = "";
    private var _eventFmt as String = "";
    private var _eventNod as String = "";
    private var _eventInactivity as String = "";
    private var _baselineFmt as String = "";
    private var _stillTiltFmt as String = "";
    private var _lastEventFmt as String = "";
    private var _noEvents as String = "";
    private var _percentFmt as String = "";

    //! Ancho (px) de la etiqueta más larga y de "100 %".
    private var _labelWidth as Number = 0;
    private var _percentWidth as Number = 0;

    function initialize(guard as GuardController) {
        View.initialize();
        _guard = guard;
    }

    function onLayout(dc as Dc) as Void {
        _layout = new RoundLayout(dc.getWidth(), dc.getHeight());
        _classNames = [
            DebugMenu.text(Rez.Strings.AiClassActive),
            DebugMenu.text(Rez.Strings.AiClassNormal),
            DebugMenu.text(Rez.Strings.AiClassNod),
            DebugMenu.text(Rez.Strings.AiClassInert)
        ] as Array<String>;
        _paused = DebugMenu.text(Rez.Strings.StatusPaused);
        _calibrating = DebugMenu.text(Rez.Strings.StatusCalibrating);
        _watching = DebugMenu.text(Rez.Strings.DetectorWatching);
        _fallDetected = DebugMenu.text(Rez.Strings.DetectorFallDetected);
        _eventFmt = DebugMenu.text(Rez.Strings.DetectorEventFormat);
        _eventNod = DebugMenu.text(Rez.Strings.EventNod);
        _eventInactivity = DebugMenu.text(Rez.Strings.EventInactivity);
        _baselineFmt = DebugMenu.text(Rez.Strings.DebugBaselineFormat);
        _stillTiltFmt = DebugMenu.text(Rez.Strings.DebugStillTiltFormat);
        _lastEventFmt = DebugMenu.text(Rez.Strings.DebugLastEventFormat);
        _noEvents = DebugMenu.text(Rez.Strings.DebugNoEvents);
        _percentFmt = DebugMenu.text(Rez.Strings.PercentFormat);

        _labelWidth = 0;
        for (var k = 0; k < _classNames.size(); k++) {
            var w = dc.getTextWidthInPixels(_classNames[k], Typography.LABEL);
            if (w > _labelWidth) {
                _labelWidth = w;
            }
        }
        _percentWidth = dc.getTextWidthInPixels(Lang.format(_percentFmt, [100]), Typography.LABEL);
    }

    function onUpdate(dc as Dc) as Void {
        Draw.clear(dc, Palette.BACKGROUND);
        var layout = _layout;
        if (layout == null) {
            return;
        }
        Draw.enableAntiAlias(dc);
        var detector = _guard.detector();
        var classifier = _guard.classifier();
        var baseline = detector.baseline();

        drawState(dc, layout, detector);
        line(dc, layout, SOURCE_Y, DebugSource.label(_guard), Palette.TEXT_SECONDARY);

        var top = classifier.topClass() as Number;
        var probabilities = classifier.probabilities();
        var bars = BAR_Y as Array<Number>;
        for (var k = 0; k < DrowsinessClass.COUNT; k++) {
            drawBar(dc, layout, layout.height * bars[k] / 1000, k, probabilities[k], k == top);
        }

        line(dc, layout, BASELINE_Y, Lang.format(_baselineFmt, [baseline.mean().format("%.1f"),
            baseline.stdDev().format("%.2f"), detector.stillThreshold().format("%.0f")]), Palette.TEXT);
        line(dc, layout, STILL_Y, Lang.format(_stillTiltFmt, [detector.stillSeconds().format("%.0f"),
            detector.tiltDegrees().format("%.0f")]), Palette.TEXT);
        drawLastEvent(dc, layout);
    }

    //! Estado del detector, en el color de su gravedad.
    private function drawState(dc as Dc, layout as RoundLayout, detector as DrowsinessDetector) as Void {
        var text = _watching;
        var color = Palette.ACCENT;
        switch (detector.state()) {
            case DetectorState.IDLE:
                text = _paused;
                color = Palette.TEXT_SECONDARY;
                break;
            case DetectorState.CALIBRATING:
                text = _calibrating;
                color = Palette.TEXT_SECONDARY;
                break;
            case DetectorState.FALL_DETECTED:
                text = _fallDetected;
                color = Palette.AMBER;
                break;
            case DetectorState.EVENT:
                text = Lang.format(_eventFmt, [eventName(detector.lastEvent())]);
                color = Palette.RED;
                break;
            default:
                break;
        }
        line(dc, layout, STATE_Y, text, color);
    }

    //! Fila de una clase: nombre, barra con la probabilidad y porcentaje.
    private function drawBar(dc as Dc, layout as RoundLayout, y as Number, k as Number,
            probability as Float, isTop as Boolean) as Void {
        var font = Typography.LABEL;
        var h = dc.getFontHeight(font);
        var width = layout.safeWidthBetween(y - h / 2, y + h / 2);
        var maxWidth = layout.scaled(ROW_MAX_WIDTH);
        if (width > maxWidth) {
            width = maxWidth;
        }
        var left = layout.centerX - width / 2;
        var right = left + width;
        var gap = layout.scaled(BAR_GAP);
        var barLeft = left + _labelWidth + gap;
        var barRight = right - _percentWidth - gap;
        var barHeight = layout.scaled(BAR_HEIGHT);
        var barWidth = barRight - barLeft;
        var textColor = isTop ? Palette.TEXT : Palette.TEXT_SECONDARY;

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, y, font, _classNames[k], Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Palette.RING_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(barLeft, y - barHeight / 2, barWidth, barHeight, barHeight / 2);
        var filled = (barWidth * probability + 0.5f).toNumber();
        if (filled >= barHeight) {
            dc.setColor((CLASS_COLORS as Array<Number>)[k], Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(barLeft, y - barHeight / 2, filled, barHeight, barHeight / 2);
        }

        var percent = (probability * 100.0f + 0.5f).toNumber();
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(right, y, font, Lang.format(_percentFmt, [percent]),
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! Último evento y su hora, o "sin eventos".
    private function drawLastEvent(dc as Dc, layout as RoundLayout) as Void {
        var moment = _guard.lastEventMoment();
        if (moment == null) {
            line(dc, layout, EVENT_Y, _noEvents, Palette.TEXT_SECONDARY);
            return;
        }
        var info = Gregorian.info(moment as Time.Moment, Time.FORMAT_SHORT);
        var time = ClockFormat.hoursMinutesSeconds(info.hour, info.min, info.sec,
            System.getDeviceSettings().is24Hour);
        line(dc, layout, EVENT_Y, Lang.format(_lastEventFmt, [eventName(_guard.lastEvent()), time]),
            Palette.AMBER);
    }

    private function eventName(event as DrowsinessEvent.Id) as String {
        return event == DrowsinessEvent.NOD ? _eventNod : _eventInactivity;
    }

    //! Texto centrado en y (milésimas de la altura), bajando la fuente si no cabe.
    private function line(dc as Dc, layout as RoundLayout, yPermille as Number, text as String,
            color as Number) as Void {
        var y = layout.height * yPermille / 1000;
        var font = Typography.LABEL;
        var h = dc.getFontHeight(font);
        var maxWidth = layout.safeWidthBetween(y - h / 2, y + h / 2);
        Draw.centeredText(dc, layout.centerX, y, Draw.fittingFont(dc, text, maxWidth, font), text, color);
    }
}
