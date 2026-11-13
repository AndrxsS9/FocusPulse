import Toybox.Graphics;
import Toybox.Lang;
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

    //! Separación vertical (px) entre el título, el acento y el estado.
    const GAP = 10;

    //! Ancho (px) de la línea de acento cian.
    const ACCENT_WIDTH = 48;

    private var _guard as GuardController;
    private var _layout as RoundLayout?;

    private var _title as String = "";
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
        _title = WatchUi.loadResource(Rez.Strings.AppName) as String;
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
        var centerX = layout.centerX;
        var centerY = layout.centerY;
        var justify = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        var titleFont = Graphics.FONT_MEDIUM;
        var statusFont = Graphics.FONT_SMALL;
        var titleY = centerY - GAP - dc.getFontHeight(titleFont) / 2;
        var statusY = centerY + GAP + dc.getFontHeight(statusFont) / 2;

        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, titleY, titleFont, _title, justify);

        dc.setColor(Palette.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(centerX - ACCENT_WIDTH / 2, centerY - 1, ACCENT_WIDTH, 2);

        if (_guard.isActive()) {
            dc.setColor(Palette.ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, statusY, statusFont, _statusActive, justify);
        } else if (_guard.isSensorUnavailable()) {
            dc.setColor(Palette.AMBER, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, statusY, statusFont, _statusSensorUnavailable, justify);
        } else {
            dc.setColor(Palette.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, statusY, statusFont, _statusPaused, justify);
        }

        if (_guard.isDemoSource()) {
            var labelY = statusY + dc.getFontHeight(statusFont) / 2 + GAP
                + dc.getFontHeight(Typography.LABEL) / 2;
            dc.setColor(Palette.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, labelY, Typography.LABEL, _statusDemo, justify);
        }
    }
}
