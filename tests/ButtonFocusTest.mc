import Toybox.Lang;
import Toybox.Test;

//! Pruebas de ButtonFocus (source/core) y de la medida del botón grande de la esfera.

(:test)
function buttonFocusLastsAfterAPress(logger as Logger) as Boolean {
    var focus = new ButtonFocus();
    Test.assert(!focus.isHighlighted(0));
    Test.assert(!focus.isHighlighted(100000));

    focus.press(5000);
    Test.assert(focus.isHighlighted(5000));
    Test.assert(focus.isHighlighted(5000 + ButtonFocus.HIGHLIGHT_MS - 1));
    Test.assert(!focus.isHighlighted(5000 + ButtonFocus.HIGHLIGHT_MS));
    // Un instante anterior a la pulsación no cuenta.
    Test.assert(!focus.isHighlighted(4999));

    // Una pulsación nueva vuelve a empezar la cuenta.
    focus.press(6000);
    Test.assert(focus.isHighlighted(6000 + ButtonFocus.HIGHLIGHT_MS - 1));
    focus.clear();
    Test.assert(!focus.isHighlighted(6001));
    return true;
}

(:test)
function buttonFocusSurvivesTimerWrap(logger as Logger) as Boolean {
    // System.getTimer() da la vuelta: la resta sigue dando el tiempo transcurrido.
    var focus = new ButtonFocus();
    var nearMax = 0x7FFFFFFF - 200;
    focus.press(nearMax);
    Test.assert(focus.isHighlighted(nearMax + 100));
    Test.assert(focus.isHighlighted(nearMax + 1000));
    return true;
}

(:test)
function guardButtonIsTheWebSize(logger as Logger) as Boolean {
    // Diseño web: 220×60 con radio 30 (la vista usa alto / 2).
    var layout = new RoundLayout(390, 390);
    Test.assertEqual(layout.buttonRect.width, 220);
    Test.assertEqual(layout.buttonRect.height, 60);
    Test.assertEqual(layout.buttonRect.height / 2, 30);
    // Debajo de la píldora (40 px de alto) y del aviso de fatiga.
    Test.assert(layout.pillY + 20 < layout.buttonRect.y);
    Test.assert(layout.fatigueBannerRect.bottom() <= layout.buttonRect.y);
    return true;
}
