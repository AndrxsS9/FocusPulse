import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Pantalla principal: nombre de la app y estado del monitoreo, centrados.
class MainView extends WatchUi.View {

    //! Separación vertical (px) entre el título, el acento y el estado.
    const GAP = 10;

    //! Ancho (px) de la línea de acento cian.
    const ACCENT_WIDTH = 48;

    private var _title as String = "";
    private var _statusPaused as String = "";

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _title = WatchUi.loadResource(Rez.Strings.AppName) as String;
        _statusPaused = WatchUi.loadResource(Rez.Strings.StatusPaused) as String;
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

        dc.setColor(Palette.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, statusY, statusFont, _statusPaused, justify);
    }
}
