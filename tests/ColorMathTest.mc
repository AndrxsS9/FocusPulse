import Toybox.Lang;
import Toybox.Test;

//! Pruebas de ColorMath.blend (source/util): extremos, punto medio y recorte.

(:test)
function colorBlendExtremesReturnEachColor(logger as Logger) as Boolean {
    Test.assertEqual(ColorMath.blend(Palette.ACCENT, Palette.BACKGROUND, 1000), Palette.ACCENT);
    Test.assertEqual(ColorMath.blend(Palette.ACCENT, Palette.BACKGROUND, 0), Palette.BACKGROUND);
    return true;
}

(:test)
function colorBlendMixesEachChannel(logger as Logger) as Boolean {
    // 50 % de blanco sobre negro: 0x80 por canal (127,5 redondeado).
    Test.assertEqual(ColorMath.blend(0xFFFFFF, 0x000000, 500), 0x808080);
    // Canales independientes: 60 % de 0x4CC9F0 sobre 0x07090C.
    // r = 0x4C·0,6 + 0x07·0,4 = 48,4 → 0x30; g = 0xC9·0,6 + 0x09·0,4 = 124,2 → 0x7C;
    // b = 0xF0·0,6 + 0x0C·0,4 = 148,8 → 0x95.
    Test.assertEqual(ColorMath.blend(Palette.ACCENT, Palette.BACKGROUND, 600), 0x307C95);
    return true;
}

(:test)
function colorBlendClampsAlpha(logger as Logger) as Boolean {
    Test.assertEqual(ColorMath.blend(Palette.RED, Palette.BACKGROUND, 1500), Palette.RED);
    Test.assertEqual(ColorMath.blend(Palette.RED, Palette.BACKGROUND, -20), Palette.BACKGROUND);
    return true;
}
