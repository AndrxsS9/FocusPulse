import Toybox.Lang;
import Toybox.Test;

//! Pruebas del desplazamiento anti quemado (PixelShift) y de RoundLayout.shiftTo.

//! Cada posición a 2 px como mucho por eje (dentro de ±3 px), todas distintas, con
//! media (0, 0), y entre posiciones seguidas, también al cerrar el ciclo, 2 px como
//! mucho por eje.
(:test)
function pixelShiftPatternIsSmallBalancedAndCyclic(logger as Logger) as Boolean {
    Test.assertEqual((PixelShift.XS as Array<Number>).size(), PixelShift.STEPS);
    Test.assertEqual((PixelShift.YS as Array<Number>).size(), PixelShift.STEPS);
    var sumX = 0;
    var sumY = 0;
    for (var i = 0; i < PixelShift.STEPS; i++) {
        var x = PixelShift.offsetX(i);
        var y = PixelShift.offsetY(i);
        Test.assertMessage(x >= -2 && x <= 2 && y >= -2 && y <= 2, "posición " + i + " dentro de ±2 px");
        sumX += x;
        sumY += y;
        var next = (i + 1) % PixelShift.STEPS;
        var dx = PixelShift.offsetX(next) - x;
        var dy = PixelShift.offsetY(next) - y;
        Test.assertMessage(dx >= -2 && dx <= 2 && dy >= -2 && dy <= 2, "salto " + i + " → " + next + " de 2 px como mucho");
        Test.assertMessage(dx != 0 || dy != 0, "cada minuto cambia de posición");
        for (var j = 0; j < i; j++) {
            Test.assertMessage(PixelShift.offsetX(j) != x || PixelShift.offsetY(j) != y, "posiciones distintas");
        }
    }
    Test.assertEqual(sumX, 0);
    Test.assertEqual(sumY, 0);
    Test.assertEqual(PixelShift.offsetX(0), 0);
    Test.assertEqual(PixelShift.offsetY(0), 0);
    return true;
}

//! Una posición por minuto: cambia al pasar de minuto y el ciclo se repite cada
//! STEPS minutos.
(:test)
function pixelShiftChangesEveryMinute(logger as Logger) as Boolean {
    var base = 1763200800;  // 2025-11-15 10:00:00 UTC, múltiplo de 60
    var first = PixelShift.stepAt(base);
    Test.assertEqual(PixelShift.stepAt(base + 59), first);
    Test.assertEqual(PixelShift.stepAt(base + 60), (first + 1) % PixelShift.STEPS);
    Test.assertEqual(PixelShift.stepAt(base + 60 * PixelShift.STEPS), first);
    for (var m = 0; m < 2 * PixelShift.STEPS; m++) {
        var step = PixelShift.stepAt(base + 60 * m);
        Test.assert(step >= 0 && step < PixelShift.STEPS);
    }
    return true;
}

//! shiftTo mueve todo el diseño junto: las zonas y los rectángulos se desplazan lo
//! mismo, el anillo sigue dentro de la pantalla en la peor posición y shiftTo(0, 0)
//! deja el diseño como estaba.
(:test)
function roundLayoutShiftMovesEverythingTogether(logger as Logger) as Boolean {
    var plain = new RoundLayout(390, 390);
    var layout = new RoundLayout(390, 390);
    layout.shiftTo(2, -2);
    Test.assertEqual(layout.centerX, plain.centerX + 2);
    Test.assertEqual(layout.centerY, plain.centerY - 2);
    Test.assertEqual(layout.timeY, plain.timeY - 2);
    Test.assertEqual(layout.pillY, plain.pillY - 2);
    Test.assertEqual(layout.buttonRect.x, plain.buttonRect.x + 2);
    Test.assertEqual(layout.buttonRect.y, plain.buttonRect.y - 2);
    Test.assertEqual(layout.fatigueBannerRect.y, plain.fatigueBannerRect.y - 2);
    // El texto se mide contra el círculo desplazado: mismo ancho seguro.
    Test.assertEqual(layout.safeWidthAt(layout.dateY), plain.safeWidthAt(plain.dateY));

    // Peor caso (2, 2): el borde exterior del anillo queda dentro de la pantalla.
    layout.shiftTo(2, 2);
    Test.assertEqual(layout.buttonRect.y, plain.buttonRect.y + 2);
    // El centro se aleja 2,8 px del de la pantalla: con 3 px de margen basta.
    var outer = layout.ringRadius + layout.ringWidth / 2;
    Test.assertMessage(outer + 3 < plain.radius, "anillo de " + outer + " px dentro de " + plain.radius);

    layout.shiftTo(0, 0);
    Test.assertEqual(layout.centerX, plain.centerX);
    Test.assertEqual(layout.timeY, plain.timeY);
    Test.assertEqual(layout.buttonTouchRect.x, plain.buttonTouchRect.x);
    Test.assertEqual(layout.alertButtonRect.y, plain.alertButtonRect.y);
    return true;
}
