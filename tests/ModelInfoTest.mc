import Toybox.Lang;
import Toybox.Test;

//! Pruebas de la pantalla "Modelo IA": formato de las métricas. El texto depende del
//! idioma del simulador ("93,3%" en español, "93.3%" en inglés); desde la 1.2.0 va sin
//! espacio en los dos, porque se dibuja en JetBrains Mono (solo cifras, "%", "," y ".").

(:debug)
function percentIs(text as String, whole as String, tenth as String) as Boolean {
    return text.equals(whole + "," + tenth + "%") || text.equals(whole + "." + tenth + "%");
}

(:test)
function modelInfoShowsPercentWithOneDecimal(logger as Logger) as Boolean {
    Test.assert(percentIs(ModelInfoView.percent(0.93317866f), "93", "3"));
    Test.assert(percentIs(ModelInfoView.percent(0.25f), "25", "0"));
    Test.assert(percentIs(ModelInfoView.percent(0.0356f), "3", "6"));
    Test.assert(percentIs(ModelInfoView.percent(0.0f), "0", "0"));
    Test.assert(percentIs(ModelInfoView.percent(1.0f), "100", "0"));
    Test.assert(Typography.isNumeric(ModelInfoView.percent(0.93317866f)));
    logger.debug("exactitud " + ModelInfoView.percent(ClassifierWeights.TEST_ACCURACY) + ", falsos cabeceos "
        + ModelInfoView.percent(ClassifierWeights.FALSE_NOD_RATE));
    return true;
}
