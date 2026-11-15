import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Guía de estilo: pantalla oculta de depuración para revisar el sistema de
//! diseño en el simulador (y mostrarlo en la sustentación).
//!
//! Páginas: paleta base, paleta de acentos, tipografía numérica, tipografía de
//! texto, textos reales largos (acentos, ñ, ¡, · y ajuste de línea), componentes
//! (anillo en 3 estados, orbe, píldora, botón) y alertas por nivel.
//!
//! Se abre con pulsación larga del botón de menú desde la pantalla principal
//! (MainDelegate.onMenu). La anotación (:debug) la excluye de las compilaciones
//! release (scripts/export.ps1), así que nunca llega a la tienda.
(:debug)
class StyleGuideView extends WatchUi.View {

    const PAGE_PALETTE_BASE = 0;
    const PAGE_PALETTE_ACCENTS = 1;
    const PAGE_TYPE_NUMBERS = 2;
    const PAGE_TYPE_TEXT = 3;
    const PAGE_TEXTS = 4;
    const PAGE_COMPONENTS = 5;
    const PAGE_ALERTS = 6;
    const PAGE_COUNT = 7;

    //! Máximo de líneas de cada texto de ejemplo al ajustarlo al ancho.
    const MAX_LINES = 3;

    //! Puntaje de ejemplo para el rol "número".
    const SAMPLE_SCORE = 72;

    private var _page as Number = PAGE_PALETTE_BASE;
    private var _layout as RoundLayout?;

    // Textos cargados en onLayout.
    private var _titles as Array<String> = [] as Array<String>;
    private var _roleTime as String = "";
    private var _roleNumber as String = "";
    private var _roleTitle as String = "";
    private var _roleBody as String = "";
    private var _roleLabel as String = "";
    private var _statusActive as String = "";
    private var _startGuard as String = "";
    private var _imAwake as String = "";
    private var _alertLevels as Array<String> = [] as Array<String>;
    private var _wakeUp as String = "";
    private var _causeNod as String = "";
    private var _microsleeps as String = "";

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _layout = new RoundLayout(dc.getWidth(), dc.getHeight());

        var palette = text(Rez.Strings.StyleGuidePalette);
        var typography = text(Rez.Strings.StyleGuideTypography);
        _titles = [
            palette,
            palette,
            typography,
            typography,
            text(Rez.Strings.StyleGuideTexts),
            text(Rez.Strings.StyleGuideComponents),
            text(Rez.Strings.StyleGuideAlerts)
        ] as Array<String>;

        _roleTime = text(Rez.Strings.TypeRoleTime);
        _roleNumber = text(Rez.Strings.TypeRoleNumber);
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

        _wakeUp = text(Rez.Strings.AlertWakeUp);
        _causeNod = text(Rez.Strings.AlertCauseNod);
        _microsleeps = text(Rez.Strings.FatigueRepeatedMicrosleeps);
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
        // El título va cerca del borde, donde la pantalla es estrecha: si no cabe
        // (p. ej. "Componentes" en el fr165), se reduce la fuente.
        var titleWidth = 2 * layout.halfChord(layout.topY, layout.radius - layout.scaled(30));
        var titleFont = Draw.fittingFont(dc, _titles[_page], titleWidth, Typography.title);
        Draw.centeredText(dc, layout.centerX, layout.topY, titleFont, _titles[_page], Palette.TEXT);

        if (_page == PAGE_PALETTE_BASE) {
            // Superficies y textos.
            drawPalette(dc, layout,
                [Palette.BACKGROUND, Palette.SURFACE,
                 Palette.BORDER, Palette.BORDER_STRONG, Palette.TEXT_SECONDARY,
                 Palette.TEXT, Palette.WHITE] as Array<Number>,
                [2, 3, 2] as Array<Number>);
        } else if (_page == PAGE_PALETTE_ACCENTS) {
            // Acentos y estados: cian/violeta, ámbar/naranjas y rojos.
            drawPalette(dc, layout,
                [Palette.ACCENT, Palette.ACCENT_LIGHT, Palette.VIOLET,
                 Palette.AMBER, Palette.ORANGE, Palette.ORANGE_DEEP,
                 Palette.RED, Palette.RED_INTENSE] as Array<Number>,
                [3, 3, 2] as Array<Number>);
        } else if (_page == PAGE_TYPE_NUMBERS) {
            drawNumberTypography(dc, layout);
        } else if (_page == PAGE_TYPE_TEXT) {
            drawTextTypography(dc, layout);
        } else if (_page == PAGE_TEXTS) {
            drawStack(dc, layout,
                [Typography.alertTitle, Typography.body, Typography.label] as Array<FontType>,
                [_wakeUp, _causeNod, _microsleeps] as Array<String>,
                [Palette.ORANGE, Palette.TEXT, Palette.TEXT_SECONDARY] as Array<Number>);
        } else if (_page == PAGE_COMPONENTS) {
            drawComponents(dc, layout);
        } else {
            drawAlerts(dc, layout);
        }

        Draw.pageDots(dc, layout.centerX, layout.footerY, PAGE_COUNT, _page,
            layout.scaled(10), Palette.ACCENT, Palette.BORDER_STRONG);
    }

    // --- Página: paleta ------------------------------------------------------

    //! Muestras de color con su valor hexadecimal. rows indica cuántas muestras
    //! van en cada fila (filas cortas arriba y abajo por la pantalla redonda).
    //! La separación entre columnas sale del ancho real de las etiquetas para que
    //! nunca se solapen.
    private function drawPalette(dc as Dc, layout as RoundLayout, colors as Array<Number>,
            rows as Array<Number>) as Void {
        var labels = [] as Array<String>;
        var labelWidth = 0;
        for (var i = 0; i < colors.size(); i++) {
            var label = colors[i].format("%06X");
            labels.add(label);
            var width = dc.getTextWidthInPixels(label, Typography.label);
            if (width > labelWidth) {
                labelWidth = width;
            }
        }

        var swatchRadius = layout.scaled(60);
        var labelHeight = dc.getFontHeight(Typography.label);
        var unitHeight = 2 * swatchRadius + labelHeight;
        var widest = labelWidth > 2 * swatchRadius ? labelWidth : 2 * swatchRadius;
        var columnSpacing = widest + layout.scaled(30);
        var rowSpacing = unitHeight + layout.scaled(15);
        var areaCenter = (titleBottom(dc, layout) + layout.footerY) / 2;
        var firstRowY = areaCenter - (rows.size() - 1) * rowSpacing / 2;

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

                Draw.centeredText(dc, x, labelY, Typography.label, labels[index],
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
            [Typography.label, Typography.clock, Typography.label, Typography.number] as Array<FontType>,
            [_roleTime, time, _roleNumber, SAMPLE_SCORE.format("%d") + "%"] as Array<String>,
            [Palette.TEXT_SECONDARY, Palette.TEXT, Palette.TEXT_SECONDARY, Palette.ACCENT] as Array<Number>);
    }

    //! Roles de texto: cada nombre de rol escrito con su propia fuente. El de la alerta
    //! muestra "¡DESPIERTA!": su fuente solo trae esas letras (Typography.alertTitle).
    private function drawTextTypography(dc as Dc, layout as RoundLayout) as Void {
        drawStack(dc, layout,
            [Typography.alertTitle, Typography.title, Typography.body, Typography.label] as Array<FontType>,
            [_wakeUp, _roleTitle, _roleBody, _roleLabel] as Array<String>,
            [Palette.TEXT, Palette.TEXT, Palette.TEXT, Palette.TEXT_SECONDARY] as Array<Number>);
    }

    //! Apila textos centrados entre el título y el indicador de página.
    //! - Una sola palabra (sin espacios) nunca se parte: si no cabe se reduce la
    //!   fuente con Draw.fittingFont.
    //! - Una frase que no cabe en una línea se parte con fitTextToArea, hasta
    //!   MAX_LINES líneas, dentro del ancho seguro de la zona central.
    private function drawStack(dc as Dc, layout as RoundLayout, fonts as Array<FontType>,
            texts as Array<String>, colors as Array<Number>) as Void {
        var gap = layout.scaled(12);
        var width = layout.safeWidthAt(layout.centerY + layout.scaled(150));
        var shownFonts = [] as Array<FontType>;
        var shownTexts = [] as Array<String>;
        var heights = [] as Array<Number>;
        var total = gap * (fonts.size() - 1);
        for (var i = 0; i < fonts.size(); i++) {
            var font = fonts[i];
            var shown = texts[i];
            if (shown.find(" ") == null) {
                font = Draw.fittingFont(dc, shown, width, font);
            } else {
                // fitTextToArea devuelve null si no logra ajustar el texto, y
                // necesita algo más que MAX_LINES alturas de fuente (interlineado)
                // para devolver MAX_LINES líneas.
                var lineHeight = dc.getFontHeight(font);
                var fitted = Graphics.fitTextToArea(shown, font, width,
                    lineHeight * MAX_LINES + lineHeight / 2, true);
                if (fitted != null) {
                    shown = fitted;
                }
            }
            var height = dc.getFontHeight(font) * lineCount(shown);
            shownFonts.add(font);
            shownTexts.add(shown);
            heights.add(height);
            total += height;
        }

        var areaTop = titleBottom(dc, layout) + gap;
        var y = (areaTop + layout.footerY - total) / 2;
        for (var i = 0; i < fonts.size(); i++) {
            Draw.centeredText(dc, layout.centerX, y + heights[i] / 2, shownFonts[i], shownTexts[i], colors[i]);
            y += heights[i] + gap;
        }
    }

    //! Número de líneas de un texto (saltos de línea + 1).
    private function lineCount(value as String) as Number {
        var lines = 1;
        var chars = value.toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            if (chars[i] == '\n') {
                lines++;
            }
        }
        return lines;
    }

    // --- Página: componentes -------------------------------------------------

    //! Anillo en los 3 estados (cian, ámbar, rojo) con los colores de su orbe,
    //! píldora de estado y botón grande de ejemplo.
    //!
    //! Se coloca de abajo hacia arriba a partir del botón, usando las alturas
    //! reales de las fuentes, para que nada se solape.
    private function drawComponents(dc as Dc, layout as RoundLayout) as Void {
        var scores = [82, 47, 21] as Array<Number>;
        var gap = layout.scaled(30);
        var ringRadius = layout.scaled(105);
        var penWidth = layout.scaled(22);
        var spacing = layout.scaled(285);
        var dotRadius = layout.scaled(10);

        var button = layout.buttonRect;
        var pillHeight = layout.pillHeight;
        var pillY = button.y - gap - pillHeight / 2;
        var dotsY = pillY - pillHeight / 2 - gap - dotRadius;
        var ringY = dotsY - dotRadius - gap - ringRadius - penWidth / 2;

        for (var i = 0; i < scores.size(); i++) {
            var score = scores[i];
            var x = layout.centerX + (i - 1) * spacing;
            var color = AlertnessColors.colorForAlertness(score);

            Draw.progressRing(dc, x, ringY, ringRadius, penWidth, score, Palette.BORDER, color);
            Draw.centeredText(dc, x, ringY, Typography.label, score.format("%d") + "%", color);

            var orb = AlertnessColors.orbPalette(score);
            for (var j = 0; j < orb.size(); j++) {
                dc.setColor(orb[j], Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x + (j - 1) * dotRadius * 3, dotsY, dotRadius);
            }
        }

        Draw.statusPill(dc, layout.centerX, pillY, pillHeight, layout.pillPadding, _statusActive,
            Typography.labelStrong, Palette.ACCENT_LIGHT, Palette.PILL_ACTIVE, Palette.ACCENT_LIGHT,
            -1.0f);
        Draw.largeButton(dc, button, _startGuard, Typography.button, Palette.ACCENT, Palette.BACKGROUND);
    }

    // --- Página: alertas -----------------------------------------------------

    //! Franjas con el fondo y el texto de cada nivel de alerta, y el botón
    //! blanco "Estoy despierto" de la alerta a pantalla completa.
    //! Las franjas se reparten con huecos iguales entre el título y el botón.
    private function drawAlerts(dc as Dc, layout as RoundLayout) as Void {
        var count = _alertLevels.size();
        var areaTop = titleBottom(dc, layout);
        var available = layout.buttonRect.y - areaTop;
        var bandHeight = dc.getFontHeight(Typography.body) + layout.scaled(30);
        var gap = (available - count * bandHeight) / (count + 1);
        var top = areaTop + gap;

        for (var level = 1; level <= count; level++) {
            var width = layout.safeWidthBetween(top, top + bandHeight);
            var band = new Rect(layout.centerX - width / 2, top, width, bandHeight);

            dc.setColor(AlertnessColors.alertBackgroundColor(level), Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(band.x, band.y, band.width, band.height, bandHeight / 4);
            Draw.centeredText(dc, band.centerX(), band.centerY(), Typography.body,
                _alertLevels[level - 1], AlertnessColors.alertTextColor(level));

            top += bandHeight + gap;
        }

        Draw.largeButton(dc, layout.buttonRect, _imAwake, Typography.alertButton, Palette.TEXT, Palette.BACKGROUND);
    }

    //! Borde inferior del título de la página.
    private function titleBottom(dc as Dc, layout as RoundLayout) as Number {
        return layout.topY + dc.getFontHeight(Typography.title) / 2;
    }

    private function text(id as ResourceId) as String {
        return WatchUi.loadResource(id) as String;
    }
}
