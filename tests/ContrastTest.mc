import Toybox.Lang;
import Toybox.Test;

//! Contraste WCAG ≥ 4,5:1 de los textos importantes fuera de la alerta (la alerta lo
//! comprueba en AlertVisualsTest, en todo el ciclo del pulso). Pares tal como se dibujan
//! en la esfera, las píldoras, los avisos, el botón y las pantallas de información.

(:test)
function textPairsReachMinimumContrast(logger as Logger) as Boolean {
    // [texto, fondo]
    var pairs = [
        [Palette.TEXT, Palette.BACKGROUND],              // hora, valores
        [Palette.TEXT_SECONDARY, Palette.BACKGROUND],    // fecha, "ALERTA", batería, etiquetas
        [Palette.TEXT_SECONDARY, Palette.SURFACE],       // píldora "Monitoreo en pausa"
        [Palette.ACCENT, Palette.BACKGROUND],            // "DEMO · …", títulos
        [Palette.ACCENT, Palette.SURFACE],               // píldora "Guardia activa"
        [Palette.AMBER, Palette.SURFACE],                // "Sin datos del sensor", aviso de fatiga
        [Palette.AMBER, Palette.BACKGROUND],             // fatiga Moderado en el resumen
        [Palette.TEXT, Palette.SURFACE],                 // "Pausar guardia", avisos
        [Palette.BACKGROUND, Palette.ACCENT],            // "Iniciar guardia"
        [Palette.RED, Palette.BACKGROUND]                // batería baja
    ] as Array<Array<Number>>;
    var lowest = 100.0f;
    for (var i = 0; i < pairs.size(); i++) {
        var ratio = Contrast.ratio(pairs[i][0], pairs[i][1]);
        Test.assertMessage(ratio >= 4.5f, "par " + i + ": " + ratio.format("%.2f"));
        if (ratio < lowest) {
            lowest = ratio;
        }
    }
    logger.debug("contraste mínimo de los textos: " + lowest.format("%.2f") + ":1");
    return true;
}

//! El porcentaje de alerta se pinta del color de su banda: todas las bandas se leen.
(:test)
function alertnessColorsReadOnBackground(logger as Logger) as Boolean {
    for (var score = 0; score <= 100; score += 5) {
        var ratio = Contrast.ratio(AlertnessColors.colorForAlertness(score), Palette.BACKGROUND);
        Test.assertMessage(ratio >= 4.5f, "puntaje " + score + ": " + ratio.format("%.2f"));
    }
    return true;
}
