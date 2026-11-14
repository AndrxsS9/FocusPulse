import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Aviso "Alerta solo visual": se abre al dejar en Ajustes la vibración apagada sin
//! sonido (o en un reloj sin altavoz) y desde el ítem de aviso de Ajustes. Con esos
//! ajustes un micro-sueño solo se avisaría en la pantalla, que un usuario dormido no
//! mira: por eso es una pantalla propia y no solo un subtítulo.
//!
//! De arriba abajo (milésimas del lado): un círculo ámbar con "!", el título en ámbar
//! (TITLE, baja de fuente si no cabe) y la explicación en LABEL, partida en varias
//! líneas dentro de la zona segura redonda. Casi todo negro (AMOLED): solo se encienden
//! el círculo y los textos. START, un toque o BACK la cierran (NoFeedbackDelegate).
class NoFeedbackView extends WatchUi.View {

    const ICON_Y = 230;
    const ICON_RADIUS = 70;
    const ICON_PEN = 8;
    const TITLE_Y = 400;
    const BODY_TOP = 460;
    const BODY_BOTTOM = 800;

    private var _layout as RoundLayout?;
    private var _title as String = "";
    private var _body as String = "";

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _layout = new RoundLayout(dc.getWidth(), dc.getHeight());
        _title = DemoText.text(Rez.Strings.WarningVisualOnlyTitle);
        _body = DemoText.text(Rez.Strings.WarningVisualOnlyBody);
    }

    function onUpdate(dc as Dc) as Void {
        var layout = _layout;
        if (layout == null) {
            return;
        }
        Draw.enableAntiAlias(dc);
        Draw.clear(dc, Palette.BACKGROUND);
        var cx = layout.centerX;

        // Ícono: círculo ámbar con un signo de exclamación.
        var iconY = layout.scaled(ICON_Y);
        var radius = layout.scaled(ICON_RADIUS);
        dc.setPenWidth(layout.scaled(ICON_PEN));
        dc.setColor(Palette.AMBER, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, iconY, radius);
        dc.setPenWidth(1);
        var bar = radius * 2 / 3;
        var barWidth = layout.scaled(ICON_PEN) + 2;
        dc.fillRoundedRectangle(cx - barWidth / 2, iconY - bar * 3 / 4, barWidth, bar, barWidth / 2);
        dc.fillCircle(cx, iconY + bar / 2, barWidth * 2 / 3);

        var titleY = layout.scaled(TITLE_Y);
        var titleFont = Draw.fittingFont(dc, _title, layout.safeWidthAt(titleY), Typography.TITLE);
        Draw.centeredText(dc, cx, titleY, titleFont, _title, Palette.AMBER);

        var top = layout.scaled(BODY_TOP);
        var bottom = layout.scaled(BODY_BOTTOM);
        var width = layout.safeWidthBetween(top, bottom);
        var text = Graphics.fitTextToArea(_body, Typography.LABEL, width, bottom - top, true);
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (top + bottom) / 2, Typography.LABEL, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

//! START, un toque o BACK cierran el aviso y vuelven a Ajustes.
class NoFeedbackDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
