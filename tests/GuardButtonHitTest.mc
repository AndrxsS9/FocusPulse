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

//! Zona del menú (batería y hora): grande, de lado a lado, por encima de la fecha y sin
//! tocar el botón grande ni el aviso de fatiga.
(:test)
function menuZoneCoversBatteryAndTime(logger as Logger) as Boolean {
    var layout = new RoundLayout(390, 390);
    var zone = layout.menuZoneRect;
    Test.assert(layout.hitsMenuZone(layout.centerX, layout.topY));      // batería
    Test.assert(layout.hitsMenuZone(layout.centerX, layout.timeY));     // hora
    Test.assert(layout.hitsMenuZone(110, layout.timeY));                // cifras de la izquierda
    Test.assert(layout.hitsMenuZone(280, layout.timeY));                // cifras de la derecha
    Test.assert(layout.hitsMenuZone(layout.centerX, 141));              // pie de las cifras
    Test.assertMessage(zone.width >= 300 && zone.height >= 3 * RoundLayout.MIN_TOUCH,
        "objetivo táctil grande");
    return true;
}

(:test)
function menuZoneMissesDateButtonAndBanner(logger as Logger) as Boolean {
    var layout = new RoundLayout(390, 390);
    Test.assert(!layout.hitsMenuZone(layout.centerX, layout.dateY));    // fecha
    Test.assert(!layout.hitsMenuZone(layout.centerX, layout.scoreY));   // porcentaje
    Test.assert(!layout.hitsMenuZone(layout.centerX, layout.centerY));  // centro
    var b = layout.buttonTouchRect;
    Test.assert(!layout.hitsMenuZone(b.centerX(), b.centerY()));        // botón grande
    var f = layout.fatigueBannerRect;
    Test.assert(!layout.hitsMenuZone(f.centerX(), f.centerY()));        // aviso de fatiga
    // Tocar la hora nunca inicia la guardia.
    Test.assert(!layout.hitsButton(layout.centerX, layout.timeY));
    Test.assert(layout.menuZoneRect.bottom() < b.y);
    return true;
}

//! Clics medidos en el simulador sobre los rótulos del bisel: llegan como toques en las
//! esquinas del cuadrado, fuera del círculo, y no abren el menú.
(:test)
function menuZoneIgnoresBezelLabels(logger as Logger) as Boolean {
    var layout = new RoundLayout(390, 390);
    Test.assertMessage(!layout.hitsMenuZone(14, 70), "rótulo LIGHT");
    Test.assertMessage(!layout.hitsMenuZone(375, 68), "rótulo START");
    Test.assert(!layout.isOnScreen(0, 0));
    Test.assert(layout.isOnScreen(layout.centerX, layout.topY));
    return true;
}

(:test)
function menuZoneScalesWithScreen(logger as Logger) as Boolean {
    var small = new RoundLayout(218, 218);
    Test.assert(small.hitsMenuZone(small.centerX, small.timeY));
    Test.assert(!small.hitsMenuZone(small.centerX, small.dateY));
    Test.assert(small.menuZoneRect.bottom() < small.buttonTouchRect.y);
    return true;
}
