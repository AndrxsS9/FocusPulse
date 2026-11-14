import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! "Resumen de la guardia": se abre sobre la esfera al pausar una guardia que duró 1 min
//! o más, o que tuvo algún episodio (GuardSummary.shouldShow). El detalle de una guardia
//! del historial usa la misma vista con su fecha como título.
//!
//! De arriba abajo (fr165, 390×390; milésimas del lado):
//!   - título (LABEL, ACCENT): "Resumen de la guardia" o la fecha, y una raya corta;
//!   - cinco filas "etiqueta ······ valor": duración, episodios, respuesta media, nivel
//!     máximo y fatiga (el valor de la fatiga en su color: cian, ámbar o rojo);
//!   - "DEMO" (LABEL, ACCENT) si la guardia corrió en modo demo.
//! Las filas comparten el ancho seguro de la más estrecha (como mucho ROW_MAX_WIDTH),
//! con la etiqueta a la izquierda en TEXT_SECONDARY y el valor a la derecha en TEXT.
//!
//! AMOLED: solo texto y una raya; vista estática, sin timer.
class SummaryView extends WatchUi.View {

    const TITLE_Y = 255;
    const RULE_Y = 315;
    const RULE_WIDTH = 90;
    const ROW_Y = [380, 465, 550, 635, 720];
    const DEMO_Y = 815;

    //! Ancho máximo de una fila y margen a cada lado, en milésimas.
    const ROW_MAX_WIDTH = 800;
    const ROW_MARGIN = 25;

    private var _summary as GuardSummary;
    private var _title as String;
    private var _layout as RoundLayout?;

    private var _labels as Array<String> = [] as Array<String>;
    private var _values as Array<String> = [] as Array<String>;
    private var _demo as String = "";

    //! title: null para "Resumen de la guardia".
    function initialize(summary as GuardSummary, title as String?) {
        View.initialize();
        _summary = summary;
        _title = title != null ? title : "";
    }

    function onLayout(dc as Dc) as Void {
        _layout = new RoundLayout(dc.getWidth(), dc.getHeight());
        if (_title.length() == 0) {
            _title = DemoText.text(Rez.Strings.SummaryTitle);
        }
        _labels = [
            DemoText.text(Rez.Strings.SummaryDuration),
            DemoText.text(Rez.Strings.SummaryEpisodes),
            DemoText.text(Rez.Strings.SummaryResponse),
            DemoText.text(Rez.Strings.SummaryMaxLevel),
            DemoText.text(Rez.Strings.FatigueLabel)
        ] as Array<String>;
        _values = [
            SummaryText.duration(_summary.durationMs),
            _summary.episodes.toString(),
            SummaryText.response(_summary.avgResponseMs),
            SummaryText.maxLevel(_summary.maxLevel),
            SummaryText.fatigue(_summary.fatigue)
        ] as Array<String>;
        _demo = DemoText.text(Rez.Strings.BadgeDemo);
    }

    function onUpdate(dc as Dc) as Void {
        var layout = _layout;
        if (layout == null) {
            return;
        }
        Draw.enableAntiAlias(dc);
        Draw.clear(dc, Palette.BACKGROUND);
        var cx = layout.centerX;

        var titleY = layout.scaled(TITLE_Y);
        // LABEL para los dos títulos ("Resumen de la guardia" no cabe más grande a esta
        // altura); la fecha del detalle va igual, así no se pega a la raya.
        Draw.centeredText(dc, cx, titleY, Typography.LABEL, _title, Palette.ACCENT);
        var rule = layout.scaled(RULE_WIDTH);
        var ruleY = layout.scaled(RULE_Y);
        dc.setPenWidth(2);
        dc.setColor(Palette.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - rule / 2, ruleY, cx + rule / 2, ruleY);
        dc.setPenWidth(1);

        // Todas las filas con el mismo ancho, el que cabe en la más estrecha (las dos
        // columnas quedan alineadas).
        var rows = ROW_Y as Array<Number>;
        var width = layout.scaled(ROW_MAX_WIDTH);
        for (var i = 0; i < rows.size(); i++) {
            var safe = layout.safeWidthAt(layout.scaled(rows[i]));
            if (safe < width) {
                width = safe;
            }
        }
        var half = width / 2 - layout.scaled(ROW_MARGIN);
        for (var i = 0; i < rows.size(); i++) {
            var y = layout.scaled(rows[i]);
            dc.setColor(Palette.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx - half, y, Typography.LABEL, _labels[i],
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            var color = i == rows.size() - 1 ? SummaryText.fatigueColor(_summary.fatigue) : Palette.TEXT;
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + half, y, Typography.LABEL, _values[i],
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        if (_summary.demo) {
            Draw.centeredText(dc, cx, layout.scaled(DEMO_Y), Typography.LABEL, _demo, Palette.ACCENT);
        }
    }
}

//! Entrada del resumen: START o BACK lo cierran (vuelven a la esfera o a la lista del
//! historial). Los toques y el resto de botones no hacen nada.
class SummaryDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        return false;
    }

    function onKey(keyEvent as KeyEvent) as Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_ENTER) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return true;
        }
        return false;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onTap(clickEvent as ClickEvent) as Boolean {
        return true;
    }

    function onMenu() as Boolean {
        return true;
    }
}
