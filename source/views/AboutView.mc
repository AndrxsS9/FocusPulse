import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! "Acerca de": nombre de la app, versión y una línea sobre lo que hace. Se abre desde
//! el menú principal; BACK vuelve al menú (BehaviorDelegate por defecto).
//!
//! De arriba abajo (milésimas del lado): nombre en TITLE (baja de fuente si no cabe),
//! versión en LABEL secundario, una raya corta de acento y la descripción en LABEL,
//! partida en varias líneas dentro de la zona segura redonda.
class AboutView extends WatchUi.View {

    const NAME_Y = 265;
    const VERSION_Y = 350;
    const RULE_Y = 405;
    const RULE_WIDTH = 90;
    const DESCRIPTION_TOP = 430;
    const DESCRIPTION_BOTTOM = 790;

    private var _layout as RoundLayout?;
    private var _name as String = "";
    private var _version as String = "";
    private var _description as String = "";

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _layout = new RoundLayout(dc.getWidth(), dc.getHeight());
        _name = DemoText.text(Rez.Strings.AppName);
        _version = Lang.format(DemoText.text(Rez.Strings.AboutVersionFormat), [AppInfo.VERSION]);
        _description = DemoText.text(Rez.Strings.AboutDescription);
    }

    function onUpdate(dc as Dc) as Void {
        var layout = _layout;
        if (layout == null) {
            return;
        }
        Draw.enableAntiAlias(dc);
        Draw.clear(dc, Palette.BACKGROUND);
        var cx = layout.centerX;

        var nameY = y(layout, NAME_Y);
        var nameFont = Draw.fittingFont(dc, _name, layout.safeWidthAt(nameY), Typography.title);
        Draw.centeredText(dc, cx, nameY, nameFont, _name, Palette.TEXT);
        Draw.centeredText(dc, cx, y(layout, VERSION_Y), Typography.label, _version,
            Palette.TEXT_SECONDARY);

        var rule = layout.scaled(RULE_WIDTH);
        var ruleY = y(layout, RULE_Y);
        dc.setPenWidth(2);
        dc.setColor(Palette.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - rule / 2, ruleY, cx + rule / 2, ruleY);
        dc.setPenWidth(1);

        var top = y(layout, DESCRIPTION_TOP);
        var bottom = y(layout, DESCRIPTION_BOTTOM);
        var width = layout.safeWidthBetween(top, bottom);
        var text = Graphics.fitTextToArea(_description, Typography.label, width, bottom - top, true);
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (top + bottom) / 2, Typography.label, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function y(layout as RoundLayout, permille as Number) as Number {
        return layout.scaled(permille);
    }
}
