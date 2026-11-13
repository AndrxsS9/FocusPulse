import Toybox.Lang;
import Toybox.Test;

//! Pruebas de RoundLayout y Rect (source/util): geometría pura, sin Dc.
//! Se comprueba el fr165 (390×390) y otra pantalla redonda para ver que
//! las medidas salen del tamaño real y no de números fijos.

//! true si el punto (px, py) queda dentro del círculo de radio r del layout.
function insideCircle(layout as RoundLayout, px as Number, py as Number, r as Number) as Boolean {
    var dx = px - layout.centerX;
    var dy = py - layout.centerY;
    return dx * dx + dy * dy <= r * r;
}

(:test)
function roundLayoutCenterAndRing(logger as Logger) as Boolean {
    var layout = new RoundLayout(390, 390);
    Test.assertEqual(layout.centerX, 195);
    Test.assertEqual(layout.centerY, 195);
    Test.assertEqual(layout.radius, 195);

    // El anillo queda dentro de la pantalla y el contenido dentro del anillo.
    Test.assert(layout.ringRadius + layout.ringWidth / 2 < layout.radius);
    Test.assert(layout.contentRadius < layout.ringInnerRadius);
    Test.assert(layout.ringWidth >= 4);
    return true;
}

(:test)
function roundLayoutScalesWithScreen(logger as Logger) as Boolean {
    var big = new RoundLayout(390, 390);
    var small = new RoundLayout(260, 260);
    Test.assert(small.ringRadius < big.ringRadius);
    Test.assert(small.buttonRect.width < big.buttonRect.width);
    Test.assertEqual(small.centerX, 130);
    return true;
}

(:test)
function roundLayoutSafeWidthNarrowsAwayFromCenter(logger as Logger) as Boolean {
    var layout = new RoundLayout(390, 390);
    var atCenter = layout.safeWidthAt(layout.centerY);
    Test.assertEqual(atCenter, 2 * layout.contentRadius);
    Test.assert(layout.safeWidthAt(layout.topY) < atCenter);
    Test.assertEqual(layout.safeWidthAt(0), 0);

    // Una caja que cruza el centro la limita su borde más lejano.
    Test.assertEqual(
        layout.safeWidthBetween(layout.centerY - 10, layout.centerY + 60),
        layout.safeWidthAt(layout.centerY + 60));
    return true;
}

(:test)
function roundLayoutZonesAreOrderedTopToBottom(logger as Logger) as Boolean {
    var layout = new RoundLayout(390, 390);
    Test.assert(layout.topY < layout.timeY);
    Test.assert(layout.timeY < layout.dateY);
    Test.assert(layout.dateY < layout.scoreY);
    Test.assert(layout.scoreY < layout.pillY);
    Test.assert(layout.pillY < layout.buttonRect.y);
    Test.assert(layout.buttonRect.bottom() < layout.footerY);
    return true;
}

(:test)
function roundLayoutButtonFitsInsideRing(logger as Logger) as Boolean {
    var sizes = [390, 260, 454] as Array<Number>;
    for (var i = 0; i < sizes.size(); i++) {
        var layout = new RoundLayout(sizes[i], sizes[i]);
        var button = layout.buttonRect;
        var r = button.height / 2;

        // Los centros de los extremos redondos + su radio no salen del área segura.
        var leftX = button.x + r;
        var rightX = button.right() - r;
        var midY = button.centerY();
        Test.assertMessage(insideCircle(layout, leftX, midY, layout.contentRadius - r + 1),
            "extremo izquierdo dentro del anillo en " + sizes[i]);
        Test.assertMessage(insideCircle(layout, rightX, midY, layout.contentRadius - r + 1),
            "extremo derecho dentro del anillo en " + sizes[i]);
        Test.assertEqual(button.centerX(), layout.centerX);
    }
    return true;
}

(:test)
function roundLayoutTouchAreasMeetMinimum(logger as Logger) as Boolean {
    var layout = new RoundLayout(260, 260);
    Test.assert(layout.buttonRect.height >= RoundLayout.MIN_TOUCH);
    Test.assert(layout.buttonTouchRect.height >= RoundLayout.MIN_TOUCH);
    Test.assert(layout.buttonTouchRect.width >= layout.buttonRect.width);

    // El área táctil contiene todo el botón visible.
    var b = layout.buttonRect;
    Test.assert(layout.buttonTouchRect.contains(b.x, b.y));
    Test.assert(layout.buttonTouchRect.contains(b.right() - 1, b.bottom() - 1));
    return true;
}

(:test)
function rectContainsUsesHalfOpenBounds(logger as Logger) as Boolean {
    var rect = new Rect(10, 20, 30, 40);
    Test.assert(rect.contains(10, 20));
    Test.assert(rect.contains(39, 59));
    Test.assert(!rect.contains(40, 30));
    Test.assert(!rect.contains(20, 60));
    Test.assert(!rect.contains(9, 30));
    return true;
}

(:test)
function rectWithMinSizeKeepsCenter(logger as Logger) as Boolean {
    var small = new Rect(100, 100, 20, 10);
    var grown = small.withMinSize(44);
    Test.assert(grown.width >= 44);
    Test.assert(grown.height >= 44);
    Test.assertEqual(grown.centerX(), small.centerX());
    Test.assertEqual(grown.centerY(), small.centerY());

    // Si ya es grande no cambia.
    var big = new Rect(0, 0, 100, 60).withMinSize(44);
    Test.assertEqual(big.width, 100);
    Test.assertEqual(big.height, 60);
    return true;
}
