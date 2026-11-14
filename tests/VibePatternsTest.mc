import Toybox.Lang;
import Toybox.Test;

//! Pruebas de VibePatterns (source/core): los patrones caben en una llamada a
//! Attention.vibrate, todas las duraciones son positivas, cada ráfaga cabe en su periodo
//! y tanto los niveles de la alerta como el ajuste de vibración se distinguen sin
//! intensidad.

(:test)
function vibePatternsFitInOneVibrateCall(logger as Logger) as Boolean {
    var settings = [VibrationLevel.SOFT, VibrationLevel.NORMAL, VibrationLevel.STRONG] as Array<VibrationLevel.Id>;
    for (var v = 0; v < settings.size(); v++) {
        for (var level = 1; level <= 3; level++) {
            var name = "ajuste " + (settings[v] as Number) + ", nivel " + level;
            var segments = VibePatterns.segments(level, settings[v]);
            Test.assertMessage(segments.size() >= 1, name + ": al menos un tramo");
            Test.assertMessage(segments.size() <= VibePatterns.MAX_SEGMENTS,
                name + ": " + segments.size() + " tramos (máx. 8)");
            Test.assertMessage(segments.size() % 2 == 1, name + ": empieza y termina encendido");
            var total = 0;
            for (var i = 0; i < segments.size(); i++) {
                Test.assertMessage(segments[i] > 0, name + ": tramo " + i + " > 0 ms");
                total += segments[i];
            }
            Test.assertEqual(total, VibePatterns.burstMs(level, settings[v]));
            Test.assertMessage(total < VibePatterns.periodMs(level),
                name + ": la ráfaga (" + total + " ms) cabe en su periodo");
        }
    }
    return true;
}

(:test)
function vibePatternsMatchSpecification(logger as Logger) as Boolean {
    var normal = VibrationLevel.NORMAL;
    // Normal: los patrones de la fase 7, sin cambios.
    Test.assertEqual(VibePatterns.segments(1, normal).toString(), [150, 150, 150].toString());
    Test.assertEqual(VibePatterns.periodMs(1), 3000);
    Test.assertEqual(VibePatterns.segments(2, normal).toString(), [300, 200, 300, 200, 300].toString());
    Test.assertEqual(VibePatterns.periodMs(2), 2000);
    Test.assertEqual(VibePatterns.segments(3, normal).toString(),
        [800, 200, 800, 200, 800, 200, 800].toString());
    // Nivel 3 casi continuo: entre ráfagas queda la misma pausa que entre pulsos.
    Test.assertEqual(VibePatterns.periodMs(3) - VibePatterns.burstMs(3, normal),
        VibePatterns.gapMs(3, normal));
    // Suave y Fuerte.
    Test.assertEqual(VibePatterns.segments(1, VibrationLevel.SOFT).toString(), [150].toString());
    Test.assertEqual(VibePatterns.segments(3, VibrationLevel.SOFT).toString(),
        [600, 250, 600, 250, 600].toString());
    Test.assertEqual(VibePatterns.segments(1, VibrationLevel.STRONG).toString(),
        [200, 150, 200, 150, 200].toString());
    Test.assertEqual(VibePatterns.segments(3, VibrationLevel.STRONG).toString(),
        [900, 100, 900, 100, 900, 100, 900].toString());
    // Apagada: los tiempos de Normal (los siguen la luz y el tono).
    Test.assertEqual(VibePatterns.segments(2, VibrationLevel.OFF).toString(),
        VibePatterns.segments(2, normal).toString());
    return true;
}

(:test)
function vibePatternsEscalateWithoutIntensity(logger as Logger) as Boolean {
    var settings = [VibrationLevel.SOFT, VibrationLevel.NORMAL, VibrationLevel.STRONG] as Array<VibrationLevel.Id>;
    for (var v = 0; v < settings.size(); v++) {
        // Fracción del tiempo con el motor encendido: crece con el nivel.
        var previous = 0;
        for (var level = 1; level <= 3; level++) {
            var onMs = VibePatterns.pulses(level, settings[v]) * VibePatterns.pulseMs(level, settings[v]);
            var dutyPermille = onMs * 1000 / VibePatterns.periodMs(level);
            Test.assertMessage(dutyPermille > previous, "ajuste " + (settings[v] as Number) + ", nivel "
                + level + ": " + dutyPermille + " ‰ encendido, más que el anterior");
            previous = dutyPermille;
        }
    }
    var normalOn = VibePatterns.pulses(3, VibrationLevel.NORMAL) * VibePatterns.pulseMs(3, VibrationLevel.NORMAL);
    Test.assertMessage(normalOn * 1000 / VibePatterns.periodMs(3) >= 750,
        "con Normal el nivel 3 vibra al menos el 75 % del tiempo");
    return true;
}

(:test)
function vibePatternsSettingChangesOnTime(logger as Logger) as Boolean {
    // En cada nivel, Suave < Normal < Fuerte en tiempo encendido por ráfaga.
    var settings = [VibrationLevel.SOFT, VibrationLevel.NORMAL, VibrationLevel.STRONG] as Array<VibrationLevel.Id>;
    for (var level = 1; level <= 3; level++) {
        var previous = 0;
        for (var v = 0; v < settings.size(); v++) {
            var onMs = VibePatterns.pulses(level, settings[v]) * VibePatterns.pulseMs(level, settings[v]);
            Test.assertMessage(onMs > previous, "nivel " + level + ", ajuste " + (settings[v] as Number)
                + ": " + onMs + " ms encendido, más que el ajuste anterior");
            previous = onMs;
        }
    }
    return true;
}

(:test)
function vibePatternsOnAtFollowsSegments(logger as Logger) as Boolean {
    var normal = VibrationLevel.NORMAL;
    // Nivel 1: 0–150 encendido, 150–300 apagado, 300–450 encendido, resto apagado.
    Test.assert(VibePatterns.isOnAt(1, normal, 0));
    Test.assert(VibePatterns.isOnAt(1, normal, 149));
    Test.assert(!VibePatterns.isOnAt(1, normal, 150));
    Test.assert(VibePatterns.isOnAt(1, normal, 300));
    Test.assert(!VibePatterns.isOnAt(1, normal, 450));
    Test.assert(!VibePatterns.isOnAt(1, normal, 2999));
    Test.assertMessage(VibePatterns.isOnAt(1, normal, 3000), "se repite cada 3 s");
    Test.assert(!VibePatterns.isOnAt(1, normal, -10));
    // Nivel 3: apagado solo en las pausas de 200 ms.
    Test.assert(VibePatterns.isOnAt(3, normal, 799));
    Test.assert(!VibePatterns.isOnAt(3, normal, 850));
    Test.assert(VibePatterns.isOnAt(3, normal, 1000));
    Test.assert(!VibePatterns.isOnAt(3, normal, 3900));
    Test.assert(VibePatterns.isOnAt(3, normal, 4000));
    // Suave, nivel 1: un solo pulso.
    Test.assert(VibePatterns.isOnAt(1, VibrationLevel.SOFT, 100));
    Test.assert(!VibePatterns.isOnAt(1, VibrationLevel.SOFT, 300));
    return true;
}

(:test)
function vibePatternsClampLevel(logger as Logger) as Boolean {
    Test.assertEqual(VibePatterns.periodMs(0), VibePatterns.periodMs(1));
    Test.assertEqual(VibePatterns.periodMs(9), VibePatterns.periodMs(3));
    Test.assertEqual(VibePatterns.segments(9, VibrationLevel.STRONG).size(),
        VibePatterns.segments(3, VibrationLevel.STRONG).size());
    return true;
}
