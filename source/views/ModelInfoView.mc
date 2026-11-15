import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! "Modelo IA": qué clasificador usa la app y cómo le fue en la prueba. Se abre desde el
//! menú principal (también en release); BACK vuelve al menú (BehaviorDelegate por defecto).
//!
//! De arriba abajo (fr165, 390×390; milésimas del lado), con el estilo del resumen:
//!   - título "Modelo IA" (LABEL, ACCENT) y una raya corta;
//!   - el tipo de modelo, centrado: "Regresión logística · 4 clases";
//!   - tres filas "etiqueta ······ valor": versión, exactitud y falsos cabeceos, con
//!     los valores de ClassifierWeights (los escribe ml/export_weights.py);
//!   - "Entrenado con datos sintéticos" (ACCENT), partido en dos líneas si no cabe: las
//!     cifras salen de datos simulados y no son precisión en muñecas reales.
//!
//! AMOLED: solo texto y una raya; vista estática, sin timer.
class ModelInfoView extends WatchUi.View {

    const TITLE_Y = 230;
    const RULE_Y = 290;
    const RULE_WIDTH = 90;
    const TYPE_Y = 360;
    const ROW_Y = [440, 520, 600];
    const NOTE_TOP = 670;
    const NOTE_BOTTOM = 860;

    //! Ancho máximo de una fila y margen a cada lado, en milésimas (como SummaryView).
    const ROW_MAX_WIDTH = 800;
    const ROW_MARGIN = 25;

    private var _layout as RoundLayout?;
    private var _title as String = "";
    private var _type as String = "";
    private var _note as String = "";
    private var _labels as Array<String> = [] as Array<String>;
    private var _values as Array<String> = [] as Array<String>;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _layout = new RoundLayout(dc.getWidth(), dc.getHeight());
        _title = DemoText.text(Rez.Strings.MenuModel);
        _type = DemoText.text(Rez.Strings.ModelType);
        _note = DemoText.text(Rez.Strings.ModelSynthetic);
        _labels = [
            DemoText.text(Rez.Strings.ModelVersion),
            DemoText.text(Rez.Strings.ModelAccuracy),
            DemoText.text(Rez.Strings.ModelFalseNods)
        ] as Array<String>;
        _values = [
            ClassifierWeights.VERSION,
            percent(ClassifierWeights.TEST_ACCURACY),
            percent(ClassifierWeights.FALSE_NOD_RATE)
        ] as Array<String>;
    }

    //! Fracción (0–1) como porcentaje con un decimal: "93,3 %" / "93.3%".
    static function percent(fraction as Float) as String {
        var tenths = (fraction * 1000.0f + 0.5f).toNumber();
        return Lang.format(DemoText.text(Rez.Strings.ModelPercentFormat), [tenths / 10, tenths % 10]);
    }

    function onUpdate(dc as Dc) as Void {
        var layout = _layout;
        if (layout == null) {
            return;
        }
        Draw.enableAntiAlias(dc);
        Draw.clear(dc, Palette.BACKGROUND);
        var cx = layout.centerX;

        Draw.centeredText(dc, cx, layout.scaled(TITLE_Y), Typography.title, _title, Palette.ACCENT);
        var rule = layout.scaled(RULE_WIDTH);
        var ruleY = layout.scaled(RULE_Y);
        dc.setPenWidth(2);
        dc.setColor(Palette.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - rule / 2, ruleY, cx + rule / 2, ruleY);
        dc.setPenWidth(1);

        var typeY = layout.scaled(TYPE_Y);
        var typeFont = Draw.fittingFont(dc, _type, layout.safeWidthAt(typeY), Typography.body);
        Draw.centeredText(dc, cx, typeY, typeFont, _type, Palette.TEXT);

        // Filas con el ancho de la más estrecha, para alinear las dos columnas.
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
            dc.drawText(cx - half, y, Typography.body, _labels[i],
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + half, y, Typography.valueFont(_values[i]), _values[i],
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        var top = layout.scaled(NOTE_TOP);
        var bottom = layout.scaled(NOTE_BOTTOM);
        var note = Graphics.fitTextToArea(_note, Typography.body, layout.safeWidthBetween(top, bottom),
            bottom - top, true);
        dc.setColor(Palette.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (top + bottom) / 2, Typography.body, note,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
