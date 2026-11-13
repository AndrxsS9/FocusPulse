import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Guía de estilo: pantalla oculta de depuración para revisar el sistema de
//! diseño en el simulador (y mostrarlo en la sustentación).
//!
//! Páginas: paleta, tipografía numérica, tipografía de texto, componentes
//! (anillo en 3 estados, orbe, píldora, botón) y alertas por nivel.
//!
//! Se abre con pulsación larga del botón de menú desde la pantalla principal
//! (MainDelegate.onMenu). La anotación (:debug) la excluye de las compilaciones
//! release (scripts/export.ps1), así que nunca llega a la tienda.
(:debug)
class StyleGuideView extends WatchUi.View {

    const PAGE_PALETTE = 0;
    const PAGE_TYPE_NUMBERS = 1;
    const PAGE_TYPE_TEXT = 2;
    const PAGE_COMPONENTS = 3;
    const PAGE_ALERTS = 4;
    const PAGE_COUNT = 5;

    //! Puntaje de ejemplo para el rol "número".
    const SAMPLE_SCORE = 72;

    private var _page as Number = PAGE_PALETTE;
    private var _layout as RoundLayout?;

    // Textos cargados en onLayout.
    private var _titles as Array<String> = [] as Array<String>;
    private var _roleTime as String = "";
    private var _roleNumber as String = "";
    private var _roleAlert as String = "";
    private var _roleTitle as String = "";
    private var _roleBody as String = "";
    private var _roleLabel as String = "";
    private var _statusActive as String = "";
    private var _startGuard as String = "";
    private var _imAwake as String = "";
    private var _alertLevels as Array<String> = [] as Array<String>;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _layout = new RoundLayout(dc.getWidth(), dc.getHeight());

        var typography = text(Rez.Strings.StyleGuideTypography);
        _titles = [
            text(Rez.Strings.StyleGuidePalette),
            typography,
            typography,
            text(Rez.Strings.StyleGuideComponents),
            text(Rez.Strings.StyleGuideAlerts)
        ] as Array<String>;

        _roleTime = text(Rez.Strings.TypeRoleTime);
        _roleNumber = text(Rez.Strings.TypeRoleNumber);
        _roleAlert = text(Rez.Strings.TypeRoleAlert);
        _roleTitle = text(Rez.Strings.TypeRoleTitle);
        _roleBody = text(Rez.Strings.TypeRoleBody);
        _roleLabel = text(Rez.Strings.TypeRoleLabel);

        _statusActive = text(Rez.Strings.StatusActive);
        _startGuard = text(Rez.Strings.ButtonStartGuard);
        _imAwake = text(Rez.Strings.ButtonImAwake);
        _alertLevels = [
            text(Rez.Strings.AlertLevel1),
            text(Rez.Strings.AlertLevel2),
            text(Rez.Strings.AlertLevel3)
        ] as Array<String>;
    }

    //! Avanza a la página siguiente (vuelve a la primera tras la última).
    function showNext() as Void {
        _page = (_page + 1) % PAGE_COUNT;
        WatchUi.requestUpdate();
    }

    //! Retrocede a la página anterior.
    function showPrevious() as Void {
        _page = (_page + PAGE_COUNT - 1) % PAGE_COUNT;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var layout = _layout;
        if (layout == null) {
            return;
        }

        Draw.enableAntiAlias(dc);
        Draw.clear(dc, Palette.BACKGROUND);
        Draw.centeredText(dc, layout.centerX, layout.topY, Typography.TITLE, _titles[_page], Palette.TEXT);

        if (_page == PAGE_PALETTE) {
            drawPalette(dc, layout);
        } else if (_page == PAGE_TYPE_NUMBERS) {
            drawNumberTypography(dc, layout);
        } else if (_page == PAGE_TYPE_TEXT) {
            drawTextTypography(dc, layout);
        } else if (_page == PAGE_COMPONENTS) {
            drawComponents(dc, layout);
        } else {
            drawAlerts(dc, layout);
        }

        Draw.pageDots(dc, layout.centerX, layout.footerY, PAGE_COUNT, _page,
            layout.scaled(10), Palette.ACCENT, Palette.BORDER_STRONG);
    }

    // --- Página: paleta ------------------------------------------------------

    //! Muestras de cada token con su valor hexadecimal, en filas 3-4-4-3
    //! para aprovechar la pantalla redonda.
    private function drawPalette(dc as Dc, layout as RoundLayout) as Void {
        var colors = [
            Palette.BACKGROUND, Palette.SURFACE, Palette.BORDER,
            Palette.BORDER_STRONG, Palette.TEXT, Palette.TEXT_SECONDARY, Palette.ACCENT,
            Palette.ACCENT_LIGHT, Palette.VIOLET, Palette.AMBER, Palette.RED,
            Palette.RED_INTENSE, Palette.ORANGE, Palette.ORANGE_DEEP
        ] as Array<Number>;
        var rows = [3, 4, 4, 3] as Array<Number>;

        var swatchRadius = layout.scaled(45);
        var labelHeight = dc.getFontHeight(Typography.LABEL);
        var unitHeight = 2 * swatchRadius + labelHeight;
        var columnSpacing = layout.scaled(190);
        var rowSpacing = unitHeight + layout.scaled(15);
        var firstRowY = layout.centerY + layout.scaled(35) - (rows.size() - 1) * rowSpacing / 2;

        var index = 0;
        for (var row = 0; row < rows.size(); row++) {
            var count = rows[row];
            var unitTop = firstRowY + row * rowSpacing - unitHeight / 2;
            var swatchY = unitTop + swatchRadius;
            var labelY = unitTop + 2 * swatchRadius + labelHeight / 2;
            var firstX = layout.centerX - (count - 1) * columnSpacing / 2;

            for (var column = 0; column < count; column++) {
                var color = colors[index];
                var x = firstX + column * columnSpacing;

                dc.setColor(color, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, swatchY, swatchRadius);
                dc.setColor(Palette.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(x, swatchY, swatchRadius);

                Draw.centeredText(dc, x, labelY, Typography.LABEL, color.format("%06X"),
                    Palette.TEXT_SECONDARY);
                index++;
            }
        }
    }

    // --- Páginas: tipografía -------------------------------------------------

    //! Roles numéricos (solo dígitos): cada muestra con su nombre encima.
    private function drawNumberTypography(dc as Dc, layout as RoundLayout) as Void {
        var clock = System.getClockTime();
        var time = clock.hour.format("%02d") + ":" + clock.min.format("%02d");

        drawStack(dc, layout,
            [Typography.LABEL, Typography.TIME, Typography.LABEL, Typography.NUMBER] as Array<FontDefinition>,
            [_roleTime, time, _roleNumber, SAMPLE_SCORE.format("%d")] as Array<String>,
            [Palette.TEXT_SECONDARY, Palette.TEXT, Palette.TEXT_SECONDARY, Palette.ACCENT] as Array<Number>);
    }

    //! Roles de texto: cada nombre de rol escrito con su propia fuente.
    private function drawTextTypography(dc as Dc, layout as RoundLayout) as Void {
        drawStack(dc, layout,
            [Typography.ALERT, Typography.TITLE, Typography.BODY, Typography.LABEL] as Array<FontDefinition>,
            [_roleAlert, _roleTitle, _roleBody, _roleLabel] as Array<String>,
            [Palette.TEXT, Palette.TEXT, Palette.TEXT, Palette.TEXT_SECONDARY] as Array<Number>);
    }

    //! Apila textos centrados entre el título y el indicador de página.
    private function drawStack(dc as Dc, layout as RoundLayout, fonts as Array<FontDefinition>,
            texts as Array<String>, colors as Array<Number>) as Void {
        var gap = layout.scaled(12);
        var total = gap * (fonts.size() - 1);
        for (var i = 0; i < fonts.size(); i++) {
            total += dc.getFontHeight(fonts[i]);
        }

        var areaTop = layout.topY + dc.getFontHeight(Typography.TITLE) / 2;
        var y = (areaTop + layout.footerY - total) / 2;
        for (var i = 0; i < fonts.size(); i++) {
            var height = dc.getFontHeight(fonts[i]);
            Draw.centeredText(dc, layout.centerX, y + height / 2, fonts[i], texts[i], colors[i]);
            y += height + gap;
        }
    }

    // --- Página: componentes -------------------------------------------------

    //! Anillo en los 3 estados (cian, ámbar, rojo) con los colores de su orbe,
    //! píldora de estado y botón grande de ejemplo.
    private function drawComponents(dc as Dc, layout as RoundLayout) as Void {
        var scores = [82, 47, 21] as Array<Number>;
        var ringRadius = layout.scaled(115);
        var penWidth = layout.scaled(22);
        var ringY = layout.centerY - layout.scaled(90);
        var spacing = layout.scaled(285);
        var dotRadius = layout.scaled(10);
        var dotsY = ringY + ringRadius + penWidth / 2 + layout.scaled(35);

        for (var i = 0; i < scores.size(); i++) {
            var score = scores[i];
            var x = layout.centerX + (i - 1) * spacing;
            var color = AlertnessColors.colorForAlertness(score);

            Draw.progressRing(dc, x, ringY, ringRadius, penWidth, score, Palette.BORDER, color);
            Draw.centeredText(dc, x, ringY, Typography.BODY, score.format("%d") + "%", color);

            var orb = AlertnessColors.orbPalette(score);
            for (var j = 0; j < orb.size(); j++) {
                dc.setColor(orb[j], Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x + (j - 1) * dotRadius * 3, dotsY, dotRadius);
            }
        }

        var button = layout.buttonRect;
        var pillY = (dotsY + dotRadius + button.y) / 2;
        Draw.pill(dc, layout.centerX, pillY, _statusActive, Typography.BODY,
            Palette.ACCENT, Palette.SURFACE, Palette.BORDER_STRONG);
        Draw.largeButton(dc, button, _startGuard, Typography.BODY, Palette.ACCENT, Palette.BACKGROUND);
    }

    // --- Página: alertas -----------------------------------------------------

    //! Franjas con el fondo y el texto de cada nivel de alerta, y el botón
    //! blanco "Estoy despierto" de la alerta a pantalla completa.
    private function drawAlerts(dc as Dc, layout as RoundLayout) as Void {
        var bandHeight = layout.scaled(150);
        var gap = layout.scaled(25);
        var top = layout.topY + dc.getFontHeight(Typography.TITLE) / 2 + gap;

        for (var level = 1; level <= _alertLevels.size(); level++) {
            var width = layout.safeWidthBetween(top, top + bandHeight);
            var band = new Rect(layout.centerX - width / 2, top, width, bandHeight);

            dc.setColor(AlertnessColors.alertBackgroundColor(level), Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(band.x, band.y, band.width, band.height, bandHeight / 4);
            Draw.centeredText(dc, band.centerX(), band.centerY(), Typography.BODY,
                _alertLevels[level - 1], AlertnessColors.alertTextColor(level));

            top += bandHeight + gap;
        }

        Draw.largeButton(dc, layout.buttonRect, _imAwake, Typography.BODY, Palette.TEXT, Palette.BACKGROUND);
    }

    private function text(id as ResourceId) as String {
        return WatchUi.loadResource(id) as String;
    }
}
