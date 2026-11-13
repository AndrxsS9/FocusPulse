import Toybox.Lang;
import Toybox.Test;

//! Pruebas del hit-testing del botón grande de la esfera (RoundLayout.hitsButton), con
//! las coordenadas del fr165 (390×390). Las coordenadas reales de onTap se midieron en
//! el simulador: un toque en el centro del botón llega como (196, 308).

(:test)
function guardButtonHitInsideButton(logger as Logger) as Boolean {
    var layout = new RoundLayout(390, 390);
    var b = layout.buttonRect;
    Test.assert(layout.hitsButton(b.centerX(), b.centerY()));
    Test.assert(layout.hitsButton(196, 308));
    Test.assert(layout.hitsButton(b.x, b.y));
    Test.assert(layout.hitsButton(b.right() - 1, b.bottom() - 1));
    return true;
}

(:test)
function guardButtonHitIncludesTouchMargin(logger as Logger) as Boolean {
    var layout = new RoundLayout(390, 390);
    var b = layout.buttonRect;
    var t = layout.buttonTouchRect;

    // Fuera del botón dibujado pero dentro del margen táctil.
    Test.assert(t.y < b.y);
    Test.assert(layout.hitsButton(b.centerX(), b.y - 3));
    Test.assert(layout.hitsButton(b.x - 3, b.centerY()));
    Test.assert(layout.hitsButton(t.x, t.y));
    Test.assert(layout.hitsButton(t.right() - 1, t.bottom() - 1));
    return true;
}

(:test)
function guardButtonMissOutsideTouchArea(logger as Logger) as Boolean {
    var layout = new RoundLayout(390, 390);
    var t = layout.buttonTouchRect;

    // Zonas de la esfera que no son el botón.
    Test.assert(!layout.hitsButton(layout.centerX, layout.centerY));   // centro
    Test.assert(!layout.hitsButton(196, 166));                         // hora (medido)
    Test.assert(!layout.hitsButton(layout.centerX, layout.topY));      // batería
    Test.assert(!layout.hitsButton(layout.centerX, layout.scoreY));    // porcentaje

    // Justo fuera del área táctil (bordes derecho e inferior excluidos).
    Test.assert(!layout.hitsButton(t.x - 1, t.centerY()));
    Test.assert(!layout.hitsButton(t.right(), t.centerY()));
    Test.assert(!layout.hitsButton(t.centerX(), t.y - 1));
    Test.assert(!layout.hitsButton(t.centerX(), t.bottom()));
    return true;
}

(:test)
function guardButtonTouchAreaDoesNotCoverStatusPillCenter(logger as Logger) as Boolean {
    // La píldora no es interactiva: tocar su centro no debe iniciar la guardia.
    var layout = new RoundLayout(390, 390);
    Test.assert(!layout.hitsButton(layout.centerX, layout.pillY));
    return true;
}
