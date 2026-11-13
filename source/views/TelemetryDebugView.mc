import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Telemetría en vivo (solo en depuración): para comprobar en el simulador o en el
//! reloj que el acelerómetro llega y que las características tienen sentido.
//!
//! Muestra, de arriba abajo: muestras recibidas, fuente (sensor real o escenario
//! simulado), X/Y/Z de la última muestra, varianza de la magnitud, sacudida (últimas
//! 10 muestras y pico del último lote), segundos de quietud, frecuencia efectiva
//! frente a la nominal y si se está grabando la actividad.
//!
//! Se redibuja con cada lote (GuardController.onBatch pide requestUpdate).
(:debug)
class TelemetryDebugView extends WatchUi.View {

    //! Centros verticales de las líneas, en milésimas de la altura.
    const LINE_Y = [165, 255, 360, 455, 545, 635, 725, 815];

    private var _guard as GuardController;
    private var _layout as RoundLayout?;

    private var _recording as String = "";
    private var _notRecording as String = "";
    private var _paused as String = "";
    private var _sensorUnavailable as String = "";
    private var _axesFmt as String = "";
    private var _varianceFmt as String = "";
    private var _jerkFmt as String = "";
    private var _stillFmt as String = "";
    private var _rateFmt as String = "";
    private var _samplesFmt as String = "";

    function initialize(guard as GuardController) {
        View.initialize();
        _guard = guard;
    }

    function onLayout(dc as Dc) as Void {
        _layout = new RoundLayout(dc.getWidth(), dc.getHeight());
        _recording = DebugMenu.text(Rez.Strings.DebugRecording);
        _notRecording = DebugMenu.text(Rez.Strings.DebugNotRecording);
        _paused = DebugMenu.text(Rez.Strings.StatusPaused);
        _sensorUnavailable = DebugMenu.text(Rez.Strings.StatusSensorUnavailable);
        _axesFmt = DebugMenu.text(Rez.Strings.DebugAxesFormat);
        _varianceFmt = DebugMenu.text(Rez.Strings.DebugVarianceFormat);
        _jerkFmt = DebugMenu.text(Rez.Strings.DebugJerkFormat);
        _stillFmt = DebugMenu.text(Rez.Strings.DebugStillFormat);
        _rateFmt = DebugMenu.text(Rez.Strings.DebugRateFormat);
        _samplesFmt = DebugMenu.text(Rez.Strings.DebugSamplesFormat);
    }

    function onUpdate(dc as Dc) as Void {
        Draw.clear(dc, Palette.BACKGROUND);
        var layout = _layout;
        if (layout == null) {
            return;
        }
        var s = _guard.snapshot();

        // Arriba, donde la pantalla es más estrecha, solo el número de muestras.
        line(dc, layout, 0, Lang.format(_samplesFmt, [s.samplesReceived]), Graphics.FONT_XTINY,
            Palette.TEXT_SECONDARY);
        line(dc, layout, 1, DebugSource.label(_guard), Graphics.FONT_XTINY, Palette.ACCENT);
        line(dc, layout, 2, Lang.format(_axesFmt, [s.x, s.y, s.z]), Graphics.FONT_TINY, Palette.TEXT);
        line(dc, layout, 3, Lang.format(_varianceFmt, [s.variance.format("%.1f")]),
            Graphics.FONT_XTINY, Palette.TEXT);
        line(dc, layout, 4, Lang.format(_jerkFmt, [s.jerk, s.batchPeakJerk]),
            Graphics.FONT_XTINY, s.batchPeakJerk > 400 ? Palette.AMBER : Palette.TEXT);
        line(dc, layout, 5, Lang.format(_stillFmt, [s.stillSeconds.format("%.1f")]),
            Graphics.FONT_XTINY, s.isStill ? Palette.ACCENT : Palette.TEXT);
        line(dc, layout, 6, Lang.format(_rateFmt, [s.effectiveHz.format("%.1f"), _guard.nominalRateHz()]),
            Graphics.FONT_XTINY, Palette.TEXT);

        // Abajo, el estado: grabando, sin grabar, en pausa o sensor no disponible.
        if (_guard.isActive()) {
            var recording = _guard.isRecording();
            line(dc, layout, 7, recording ? _recording : _notRecording, Graphics.FONT_XTINY,
                recording ? Palette.RED : Palette.TEXT_SECONDARY);
        } else if (_guard.isSensorUnavailable()) {
            line(dc, layout, 7, _sensorUnavailable, Graphics.FONT_XTINY, Palette.AMBER);
        } else {
            line(dc, layout, 7, _paused, Graphics.FONT_XTINY, Palette.TEXT_SECONDARY);
        }
    }

    //! Dibuja la línea index centrada, bajando la fuente si no cabe en el círculo.
    private function line(dc as Dc, layout as RoundLayout, index as Number, text as String,
            font as FontDefinition, color as Number) as Void {
        var y = layout.height * (LINE_Y as Array<Number>)[index] / 1000;
        var h = dc.getFontHeight(font);
        var maxWidth = layout.safeWidthBetween(y - h / 2, y + h / 2);
        Draw.centeredText(dc, layout.centerX, y, Draw.fittingFont(dc, text, maxWidth, font), text, color);
    }
}

//! Entrada de la telemetría en vivo.
//!
//! - START/STOP o toque: inicia o pausa la guardia.
//! - DOWN / UP: siguiente / anterior fuente (sensor real y los 5 escenarios).
//! - BACK: vuelve al menú de depuración.
(:debug)
class TelemetryDebugDelegate extends WatchUi.BehaviorDelegate {

    private var _guard as GuardController;

    function initialize(guard as GuardController) {
        BehaviorDelegate.initialize();
        _guard = guard;
    }

    function onSelect() as Boolean {
        _guard.toggle();
        return true;
    }

    function onTap(clickEvent as ClickEvent) as Boolean {
        _guard.toggle();
        return true;
    }

    function onNextPage() as Boolean {
        cycleSource(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        cycleSource(-1);
        return true;
    }

    //! Recorre: sensor real → normal → tecleo → cabeceo → inactividad → manual.
    private function cycleSource(step as Number) as Void {
        var count = AccelScenario.COUNT + 1;
        var current = _guard.isDemoSource() ? (_guard.demoScenario() as Number) + 1 : 0;
        var next = (current + step + count) % count;
        DebugSource.select(_guard, next == 0 ? DebugSource.REAL : next - 1);
    }
}
