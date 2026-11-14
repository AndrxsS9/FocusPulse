import Toybox.Lang;
import Toybox.Test;

//! Pruebas del botón "Estoy despierto" de la alerta (RoundLayout.alertButtonRect y
//! hitsAlertButton) con las medidas del fr165 (390×390).

(:test)
function alertButtonFitsInsideSafeCircle(logger as Logger) as Boolean {
    var layout = new RoundLayout(390, 390);
    var b = layout.alertButtonRect;
    Test.assertMessage(b.height >= RoundLayout.MIN_TOUCH, "alto " + b.height + " px ≥ 44");
    Test.assertMessage(b.width > layout.buttonRect.width,
        "más ancho que el botón de la esfera (" + b.width + " > " + layout.buttonRect.width + ")");
    // Las esquinas inferiores del tramo recto quedan dentro del círculo seguro.
    var half = b.width / 2 - b.height / 2;
    var dx = half;
    var dy = b.bottom() - b.height / 2 - layout.centerY;
    var reach = layout.contentRadius - b.height / 2;
    Test.assertMessage(dx * dx + dy * dy <= reach * reach + 2 * reach,
        "los extremos redondos no cruzan contentRadius");
    return true;
}

(:test)
function alertButtonHitIncludesMarginOnly(logger as Logger) as Boolean {
    var layout = new RoundLayout(390, 390);
    var b = layout.alertButtonRect;
    var t = layout.alertButtonTouchRect;
    Test.assert(layout.hitsAlertButton(b.centerX(), b.centerY()));
    Test.assert(layout.hitsAlertButton(b.centerX(), b.y - 3));
    Test.assert(layout.hitsAlertButton(t.right() - 1, t.bottom() - 1));
    // El título, el motivo y el borde inferior no descartan la alerta.
    Test.assert(!layout.hitsAlertButton(layout.centerX, layout.centerY));
    Test.assert(!layout.hitsAlertButton(layout.centerX, 125));
    Test.assert(!layout.hitsAlertButton(layout.centerX, t.bottom() + 1));
    return true;
}
