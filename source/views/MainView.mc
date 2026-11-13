import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Pantalla principal: nombre de la app y estado de la guardia, centrados.
//!
//! Estados: "Monitoreo en pausa", "Guardia activa" o "Sensor no disponible" (si el
//! último intento de iniciar falló). Con la fuente simulada añade "Modo demo" debajo.
//! Se rehace en la fase 7 con RoundLayout.
class MainView extends WatchUi.View {

    //! Separación vertical (px) entre el título, el acento y el estado.
    const GAP = 10;

    //! Ancho (px) de la línea de acento cian.
    const ACCENT_WIDTH = 48;

    private var _guard as GuardController;
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
        _title = WatchUi.loadResource(Rez.Strings.AppName) as String;
        _statusPaused = WatchUi.loadResource(Rez.Strings.StatusPaused) as String;
        _statusActive = WatchUi.loadResource(Rez.Strings.StatusActive) as String;
        _statusSensorUnavailable = WatchUi.loadResource(Rez.Strings.StatusSensorUnavailable) as String;
        _statusDemo = WatchUi.loadResource(Rez.Strings.StatusDemo) as String;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Palette.BACKGROUND, Palette.BACKGROUND);
        dc.clear();

        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;
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
