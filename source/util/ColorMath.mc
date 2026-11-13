import Toybox.Lang;

//! Mezcla de colores RGB (0xRRGGBB) sin dependencias de Graphics.
//!
//! El fr165 no tiene Dc.setStroke/setFill en tiempo de ejecución (verificado en el
//! simulador: "Symbol Not Found"), así que no se pueden dibujar líneas con canal alfa.
//! Las transparencias del orbe se simulan precalculando el color ya mezclado con el
//! fondo: sobre BACKGROUND el resultado es el mismo que un trazo con alfa.
module ColorMath {

    //! Color resultante de pintar color con opacidad alphaPermille (0–1000) sobre
    //! background.
    function blend(color as Number, background as Number, alphaPermille as Number) as Number {
        var a = alphaPermille < 0 ? 0 : (alphaPermille > 1000 ? 1000 : alphaPermille);
        var r = mix((color >> 16) & 0xFF, (background >> 16) & 0xFF, a);
        var g = mix((color >> 8) & 0xFF, (background >> 8) & 0xFF, a);
        var b = mix(color & 0xFF, background & 0xFF, a);
        return (r << 16) | (g << 8) | b;
    }

    //! Canal mezclado y redondeado.
    function mix(top as Number, bottom as Number, alphaPermille as Number) as Number {
        return (top * alphaPermille + bottom * (1000 - alphaPermille) + 500) / 1000;
    }
}
