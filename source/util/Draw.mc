import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

//! Utilidades de dibujo compartidas por las vistas.
//!
//! Reglas AMOLED (docs/DISENO.md): fondo casi negro en áreas grandes, rellenos
//! claros solo en controles pequeños o en la alerta a pantalla completa.
module Draw {

    //! Justificación centrada en ambos ejes para drawText.
    const JUSTIFY_CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

    //! Activa el suavizado si el dispositivo lo soporta (API 3.2+).
    function enableAntiAlias(dc as Dc) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
    }

    //! Limpia la pantalla con un color de fondo (normalmente Palette.BACKGROUND).
    function clear(dc as Dc, color as Number) as Void {
        dc.setColor(color, color);
        dc.clear();
    }

    //! Texto centrado horizontal y verticalmente en (x, y).
    function centeredText(dc as Dc, x as Number, y as Number, font as FontType,
            text as String, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text, JUSTIFY_CENTER);
    }

    //! Ancho de text con tracking píxeles de espaciado entre letras (trackedText).
    function trackedWidth(dc as Dc, text as String, font as FontType, tracking as Number) as Number {
        var chars = text.toCharArray();
        var width = 0;
        for (var i = 0; i < chars.size(); i++) {
            width += dc.getTextWidthInPixels(chars[i].toString(), font);
        }
        return chars.size() > 1 ? width + tracking * (chars.size() - 1) : width;
    }

    //! Texto con espaciado entre letras (letter-spacing del diseño web): lo dibuja letra
    //! a letra desde x (borde izquierdo), con y según justify (TEXT_JUSTIFY_VCENTER o
    //! arriba). Para rótulos cortos en mayúsculas ("ALERTA").
    function trackedText(dc as Dc, x as Number, y as Number, font as FontType, text as String,
            tracking as Number, justify as Number) as Void {
        var chars = text.toCharArray();
        var left = x;
        for (var i = 0; i < chars.size(); i++) {
            var glyph = chars[i].toString();
            dc.drawText(left, y, font, glyph, Graphics.TEXT_JUSTIFY_LEFT | justify);
            left += dc.getTextWidthInPixels(glyph, font) + tracking;
        }
    }

    //! Anillo de progreso: pista completa en trackColor y avance en color,
    //! empezando a las 12 en punto y en sentido horario, con extremos redondos.
    //!
    //! radius es el radio de la línea central del trazo (como en drawArc) y
    //! percent va de 0 a 100 (se recorta).
    function progressRing(dc as Dc, cx as Number, cy as Number, radius as Number,
            penWidth as Number, percent as Number, trackColor as Number, color as Number) as Void {
        dc.setPenWidth(penWidth);
        dc.setColor(trackColor, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, radius);

        var clamped = percent < 0 ? 0 : (percent > 100 ? 100 : percent);
        var sweep = 360 * clamped / 100;
        if (sweep > 0) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            if (sweep >= 360) {
                dc.drawCircle(cx, cy, radius);
            } else {
                // drawArc: 0° = 3 en punto, ángulos crecen en sentido antihorario.
                var start = 90;
                var finish = (450 - sweep) % 360;
                dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, start, finish);
                roundCap(dc, cx, cy, radius, start, penWidth);
                roundCap(dc, cx, cy, radius, finish, penWidth);
            }
        }
        dc.setPenWidth(1);
    }

    //! Píldora de estado centrada en (cx, cy): relleno oscuro, borde y texto de
    //! color. Devuelve el rectángulo ocupado (útil para hit-testing).
    function pill(dc as Dc, cx as Number, cy as Number, text as String, font as FontType,
            textColor as Number, fillColor as Number, borderColor as Number) as Rect {
        var height = pillHeight(dc, font);
        var width = dc.getTextWidthInPixels(text, font) + height;
        var rect = new Rect(cx - width / 2, cy - height / 2, width, height);
        var corner = height / 2;

        dc.setColor(fillColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(rect.x, rect.y, rect.width, rect.height, corner);
        dc.setPenWidth(2);
        dc.setColor(borderColor, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(rect.x, rect.y, rect.width, rect.height, corner);
        dc.setPenWidth(1);

        centeredText(dc, cx, cy, font, text, textColor);
        return rect;
    }

    //! Píldora de estado con un punto opcional a la izquierda del texto (p. ej. la
    //! guardia activa). Mismo alto que pill(); el punto mide un tercio del alto y va en
    //! dotColor (sin punto si es null). Devuelve el rectángulo ocupado.
    //!
    //! ping (0–1) anima el punto con un "ping" (GuardVisuals): un círculo detrás del punto
    //! que crece de 1× a 2,6× y se desvanece de 0,8 a 0. Con ping < 0 no hay ping.
    function statusPill(dc as Dc, cx as Number, cy as Number, text as String, font as FontType,
            textColor as Number, fillColor as Number, borderColor as Number,
            dotColor as Number?, ping as Float) as Rect {
        if (dotColor == null) {
            return pill(dc, cx, cy, text, font, textColor, fillColor, borderColor);
        }
        var height = pillHeight(dc, font);
        var dotRadius = height / 6;
        var gap = height / 4;
        var textWidth = dc.getTextWidthInPixels(text, font);
        var contentWidth = 2 * dotRadius + gap + textWidth;
        var width = contentWidth + height;
        var rect = new Rect(cx - width / 2, cy - height / 2, width, height);
        var corner = height / 2;

        dc.setColor(fillColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(rect.x, rect.y, rect.width, rect.height, corner);
        dc.setPenWidth(2);
        dc.setColor(borderColor, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(rect.x, rect.y, rect.width, rect.height, corner);
        dc.setPenWidth(1);

        var left = cx - contentWidth / 2;
        var dotX = left + dotRadius;
        if (ping >= 0.0f && ping <= 1.0f) {
            dc.setColor(ColorMath.blend(dotColor, fillColor, GuardVisuals.pingAlpha(ping)),
                Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(dotX, cy, dotRadius * GuardVisuals.pingScale(ping));
        }
        dc.setColor(dotColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(dotX, cy, dotRadius);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + 2 * dotRadius + gap, cy, font, text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        return rect;
    }

    //! Alto de una píldora con texto en font (para colocarla antes de dibujarla).
    function pillHeight(dc as Dc, font as FontType) as Number {
        var fontHeight = dc.getFontHeight(font);
        return fontHeight + fontHeight / 3;
    }

    //! Fuente más grande, desde preferred hacia abajo (Typography.smaller), con la que
    //! text cabe en maxWidth píxeles. Si ni la más pequeña cabe, devuelve esa.
    function fittingFont(dc as Dc, text as String, maxWidth as Number,
            preferred as FontType) as FontType {
        var font = preferred;
        while (dc.getTextWidthInPixels(text, font) > maxWidth) {
            var next = Typography.smaller(font);
            if (next == null) {
                break;
            }
            font = next;
        }
        return font;
    }

    //! Botón grande con extremos redondos dentro de rect, con el texto centrado.
    //! Si el texto no cabe con font, se usa la fuente más grande que sí quepa
    //! (fittingFont). El área táctil no es rect sino una mayor
    //! (RoundLayout.buttonTouchRect).
    function largeButton(dc as Dc, rect as Rect, text as String, font as FontType,
            fillColor as Number, textColor as Number) as Void {
        dc.setColor(fillColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(rect.x, rect.y, rect.width, rect.height, rect.height / 2);
        var fitted = fittingFont(dc, text, rect.width - rect.height / 2, font);
        centeredText(dc, rect.centerX(), rect.centerY(), fitted, text, textColor);
    }

    //! Ícono de batería dentro de rect (cuerpo + borne a la derecha), con el relleno
    //! proporcional a percent (0–100). El borne ocupa la última octava parte del ancho.
    function battery(dc as Dc, rect as Rect, percent as Number, color as Number) as Void {
        var nubWidth = rect.width / 8;
        var bodyWidth = rect.width - nubWidth;
        var pen = rect.height / 7 + 1;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pen);
        dc.drawRoundedRectangle(rect.x, rect.y, bodyWidth, rect.height, pen);
        dc.setPenWidth(1);
        var nubHeight = rect.height / 2;
        dc.fillRectangle(rect.x + bodyWidth, rect.y + (rect.height - nubHeight) / 2, nubWidth, nubHeight);

        var clamped = percent < 0 ? 0 : (percent > 100 ? 100 : percent);
        var inset = pen + 1;
        var fillMax = bodyWidth - 2 * inset;
        var fill = fillMax * clamped / 100;
        if (fill > 0) {
            dc.fillRectangle(rect.x + inset, rect.y + inset, fill, rect.height - 2 * inset);
        }
    }

    //! Indicador de página: count puntos centrados en (cx, cy); el actual en color.
    function pageDots(dc as Dc, cx as Number, cy as Number, count as Number, current as Number,
            dotRadius as Number, color as Number, inactiveColor as Number) as Void {
        var spacing = dotRadius * 4;
        var x = cx - (count - 1) * spacing / 2;
        for (var i = 0; i < count; i++) {
            dc.setColor(i == current ? color : inactiveColor, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + i * spacing, cy, dotRadius);
        }
    }

    //! Punto redondo en el ángulo dado (grados de drawArc) para rematar un arco.
    function roundCap(dc as Dc, cx as Number, cy as Number, radius as Number,
            degrees as Number, penWidth as Number) as Void {
        var radians = Math.toRadians(degrees);
        var x = cx + (radius * Math.cos(radians)).toNumber();
        var y = cy - (radius * Math.sin(radians)).toNumber();
        dc.fillCircle(x, y, penWidth / 2);
    }
}
