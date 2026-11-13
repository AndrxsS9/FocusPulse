import Toybox.Lang;

//! Rectángulo en píxeles de pantalla. Se usa para dibujar controles y para
//! comprobar si un toque (onTap) cae dentro de su área táctil.
//!
//! Sin dependencias de WatchUi ni Graphics, para poder probarlo.
class Rect {

    var x as Number;
    var y as Number;
    var width as Number;
    var height as Number;

    function initialize(left as Number, top as Number, w as Number, h as Number) {
        x = left;
        y = top;
        width = w;
        height = h;
    }

    function right() as Number {
        return x + width;
    }

    function bottom() as Number {
        return y + height;
    }

    function centerX() as Number {
        return x + width / 2;
    }

    function centerY() as Number {
        return y + height / 2;
    }

    //! true si el punto está dentro (borde izquierdo/superior incluido,
    //! derecho/inferior excluido).
    function contains(px as Number, py as Number) as Boolean {
        return px >= x && px < x + width && py >= y && py < y + height;
    }

    //! Rectángulo nuevo agrandado dx px a cada lado y dy px arriba y abajo.
    function inflate(dx as Number, dy as Number) as Rect {
        return new Rect(x - dx, y - dy, width + 2 * dx, height + 2 * dy);
    }

    //! Rectángulo nuevo con el mismo centro y al menos minSize px de ancho y alto.
    //! Sirve para garantizar áreas táctiles mínimas (ver docs/DISENO.md).
    function withMinSize(minSize as Number) as Rect {
        var dx = 0;
        var dy = 0;
        if (width < minSize) {
            dx = (minSize - width + 1) / 2;
        }
        if (height < minSize) {
            dy = (minSize - height + 1) / 2;
        }
        return inflate(dx, dy);
    }
}
