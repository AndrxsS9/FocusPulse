import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;

//! Escala de fuentes de Typography.smaller (la usa Draw.fittingFont). Las pruebas no
//! llaman a Typography.load(), así que los roles son las fuentes del sistema; aquí se
//! prueba la bajada de las fuentes del sistema y que la escala siempre termina.
(:test)
function typographySystemFontsStepDownToXtiny(logger as Logger) as Boolean {
    Test.assertMessage(Typography.smaller(Graphics.FONT_LARGE) == Graphics.FONT_MEDIUM, "LARGE");
    Test.assertMessage(Typography.smaller(Graphics.FONT_SMALL) == Graphics.FONT_TINY, "SMALL");
    Test.assertMessage(Typography.smaller(Graphics.FONT_TINY) == Graphics.FONT_XTINY, "TINY");
    Test.assertMessage(Typography.smaller(Graphics.FONT_XTINY) == null, "XTINY es la última");
    return true;
}

(:test)
function typographyNumberFontsDoNotStepDown(logger as Logger) as Boolean {
    // Las fuentes numéricas no tienen letras: nunca se bajan a una de texto.
    Test.assertMessage(Typography.smaller(Graphics.FONT_NUMBER_MEDIUM) == null, "hora");
    Test.assertMessage(Typography.smaller(Graphics.FONT_NUMBER_MILD) == null, "número");
    return true;
}

(:test)
function typographyScaleAlwaysEnds(logger as Logger) as Boolean {
    // Desde cualquier rol, la escala llega a null en pocos pasos (fittingFont no se
    // queda en un bucle).
    var roles = [Typography.clock, Typography.alertTitle, Typography.title, Typography.body,
        Typography.label, Typography.button, Typography.alertButton, Typography.number,
        Typography.numberSmall] as Array<FontType>;
    for (var i = 0; i < roles.size(); i++) {
        var font = roles[i] as FontType?;
        var steps = 0;
        while (font != null && steps < 10) {
            font = Typography.smaller(font);
            steps++;
        }
        Test.assertMessage(font == null, "el rol " + i + " termina");
    }
    return true;
}
