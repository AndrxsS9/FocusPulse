import Toybox.Lang;
import Toybox.Test;

//! Pruebas de VibePatterns (source/core): los patrones caben en una llamada a
//! Attention.vibrate, todas las duraciones son positivas, cada ráfaga cabe en su periodo
//! y los niveles se distinguen sin intensidad.

(:test)
function vibePatternsFitInOneVibrateCall(logger as Logger) as Boolean {
    for (var level = 1; level <= 3; level++) {
        var segments = VibePatterns.segments(level);
        Test.assertMessage(segments.size() >= 1, "nivel " + level + ": al menos un tramo");
        Test.assertMessage(segments.size() <= VibePatterns.MAX_SEGMENTS,
            "nivel " + level + ": " + segments.size() + " tramos (máx. 8)");
        Test.assertMessage(segments.size() % 2 == 1,
            "nivel " + level + ": empieza y termina encendido");
        var total = 0;
        for (var i = 0; i < segments.size(); i++) {
            Test.assertMessage(segments[i] > 0, "nivel " + level + ": tramo " + i + " > 0 ms");
            total += segments[i];
        }
        Test.assertEqual(total, VibePatterns.burstMs(level));
        Test.assertMessage(total < VibePatterns.periodMs(level),
            "nivel " + level + ": la ráfaga (" + total + " ms) cabe en su periodo");
    }
    return true;
}

(:test)
function vibePatternsMatchSpecification(logger as Logger) as Boolean {
    Test.assertEqual(VibePatterns.segments(1).toString(), [150, 150, 150].toString());
    Test.assertEqual(VibePatterns.periodMs(1), 3000);
    Test.assertEqual(VibePatterns.segments(2).toString(), [300, 200, 300, 200, 300].toString());
    Test.assertEqual(VibePatterns.periodMs(2), 2000);
    Test.assertEqual(VibePatterns.segments(3).toString(),
        [800, 200, 800, 200, 800, 200, 800].toString());
    // Nivel 3 casi continuo: entre ráfagas queda la misma pausa que entre pulsos.
    Test.assertEqual(VibePatterns.periodMs(3) - VibePatterns.burstMs(3), VibePatterns.MAX_GAP_MS);
    return true;
}

(:test)
function vibePatternsEscalateWithoutIntensity(logger as Logger) as Boolean {
    // Fracción del tiempo con el motor encendido: crece con el nivel.
    var previous = 0;
    for (var level = 1; level <= 3; level++) {
        var onMs = VibePatterns.pulses(level) * VibePatterns.pulseMs(level);
        var dutyPermille = onMs * 1000 / VibePatterns.periodMs(level);
        Test.assertMessage(dutyPermille > previous,
            "nivel " + level + ": " + dutyPermille + " ‰ encendido, más que el anterior");
        previous = dutyPermille;
    }
    Test.assertMessage(previous >= 750, "el nivel 3 vibra al menos el 75 % del tiempo");
    return true;
}

(:test)
function vibePatternsOnAtFollowsSegments(logger as Logger) as Boolean {
    // Nivel 1: 0–150 encendido, 150–300 apagado, 300–450 encendido, resto apagado.
    Test.assert(VibePatterns.isOnAt(1, 0));
    Test.assert(VibePatterns.isOnAt(1, 149));
    Test.assert(!VibePatterns.isOnAt(1, 150));
    Test.assert(VibePatterns.isOnAt(1, 300));
    Test.assert(!VibePatterns.isOnAt(1, 450));
    Test.assert(!VibePatterns.isOnAt(1, 2999));
    Test.assertMessage(VibePatterns.isOnAt(1, 3000), "se repite cada 3 s");
    Test.assert(!VibePatterns.isOnAt(1, -10));
    // Nivel 3: apagado solo en las pausas de 200 ms.
    Test.assert(VibePatterns.isOnAt(3, 799));
    Test.assert(!VibePatterns.isOnAt(3, 850));
    Test.assert(VibePatterns.isOnAt(3, 1000));
    Test.assert(!VibePatterns.isOnAt(3, 3900));
    Test.assert(VibePatterns.isOnAt(3, 4000));
    return true;
}

(:test)
function vibePatternsClampLevel(logger as Logger) as Boolean {
    Test.assertEqual(VibePatterns.periodMs(0), VibePatterns.SOFT_PERIOD_MS);
    Test.assertEqual(VibePatterns.periodMs(9), VibePatterns.MAX_PERIOD_MS);
    Test.assertEqual(VibePatterns.segments(9).size(), VibePatterns.segments(3).size());
    return true;
}
