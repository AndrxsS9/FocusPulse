import Toybox.Lang;
import Toybox.Test;

//! Pruebas de FatiguePredictor: cada regla por separado, sus límites y la combinación.
//! Los tiempos son ms desde el inicio de la guardia; MIN = 1 minuto.

(:debug)
const FATIGUE_MIN = 60000;

//! Episodio respondido en el nivel 1 a los startMs, con su tiempo de respuesta.
(:debug)
function fatigueAnswered(log as AlertLog, startMs as Number, responseMs as Number) as Void {
    log.add(new AlertRecord(DrowsinessEvent.NOD, 1, startMs, responseMs));
}

(:test)
function fatigueWindowsPerMode(logger as Logger) as Boolean {
    Test.assertEqual(FatiguePredictor.windowMsFor(false), 30 * FATIGUE_MIN);
    Test.assertEqual(FatiguePredictor.windowMsFor(true), 5 * FATIGUE_MIN);
    var config = new DemoConfig();
    Test.assertEqual(config.fatigueWindowMs(), 30 * FATIGUE_MIN);
    config.setEnabled(true);
    Test.assertEqual(config.fatigueWindowMs(), 5 * FATIGUE_MIN);
    return true;
}

//! Regla 1: 0 → Bajo, 1–2 → Moderado, 3 o más → Alto.
(:test)
function fatigueRuleOneCountsRecentEpisodes(logger as Logger) as Boolean {
    Test.assertEqual(FatiguePredictor.levelForCount(0), FatigueLevel.LOW);
    Test.assertEqual(FatiguePredictor.levelForCount(1), FatigueLevel.MODERATE);
    Test.assertEqual(FatiguePredictor.levelForCount(2), FatigueLevel.MODERATE);
    Test.assertEqual(FatiguePredictor.levelForCount(3), FatigueLevel.HIGH);
    Test.assertEqual(FatiguePredictor.levelForCount(9), FatigueLevel.HIGH);

    var window = FatiguePredictor.WINDOW_MS;
    var log = new AlertLog();
    var now = 60 * FATIGUE_MIN;
    Test.assertEqualMessage(FatiguePredictor.assess(log, now, window, 0), FatigueLevel.LOW,
        "sin episodios: Bajo");
    // Respuestas iguales: la regla 2 no interviene.
    fatigueAnswered(log, 40 * FATIGUE_MIN, 2000);
    Test.assertEqual(FatiguePredictor.assess(log, now, window, 0), FatigueLevel.MODERATE);
    fatigueAnswered(log, 45 * FATIGUE_MIN, 2000);
    Test.assertEqual(FatiguePredictor.assess(log, now, window, 0), FatigueLevel.MODERATE);
    fatigueAnswered(log, 50 * FATIGUE_MIN, 2000);
    Test.assertEqualMessage(FatiguePredictor.assess(log, now, window, 0), FatigueLevel.HIGH,
        "3 en 30 min: Alto");
    return true;
}

//! Regla 1, límites de la ventana: justo 30 min cuenta, 30 min + 1 ms no; lo mismo con
//! la ventana de 5 min del modo demo.
(:test)
function fatigueRuleOneWindowEdges(logger as Logger) as Boolean {
    var log = new AlertLog();
    fatigueAnswered(log, 10 * FATIGUE_MIN, 1500);
    var window = FatiguePredictor.WINDOW_MS;
    Test.assertEqual(FatiguePredictor.recentEpisodes(log, 40 * FATIGUE_MIN, window, 0), 1);
    Test.assertEqual(FatiguePredictor.recentEpisodes(log, 40 * FATIGUE_MIN + 1, window, 0), 0);
    Test.assertEqualMessage(FatiguePredictor.assess(log, 40 * FATIGUE_MIN + 1, window, 0),
        FatigueLevel.LOW, "el episodio salió de la ventana: Bajo otra vez");

    var demo = FatiguePredictor.WINDOW_DEMO_MS;
    Test.assertEqual(FatiguePredictor.recentEpisodes(log, 15 * FATIGUE_MIN, demo, 0), 1);
    Test.assertEqual(FatiguePredictor.recentEpisodes(log, 15 * FATIGUE_MIN + 1, demo, 0), 0);

    // Un episodio posterior a nowMs (no debería pasar) no cuenta.
    Test.assertEqual(FatiguePredictor.recentEpisodes(log, 10 * FATIGUE_MIN - 1, window, 0), 0);

    // Demo: tres episodios en 1 min dan Alto, y a los 5 min del primero baja.
    var demoLog = new AlertLog();
    fatigueAnswered(demoLog, 10000, 3000);
    fatigueAnswered(demoLog, 30000, 3000);
    fatigueAnswered(demoLog, 50000, 3000);
    Test.assertEqual(FatiguePredictor.assess(demoLog, 60000, demo, 0), FatigueLevel.HIGH);
    Test.assertEqualMessage(FatiguePredictor.assess(demoLog, 310001, demo, 0),
        FatigueLevel.MODERATE, "quedan 2 en la ventana");
    return true;
}

//! Regla 2: tres respuestas en aumento estricto, con 1 s o más entre la primera y la
//! última, suben un nivel.
(:test)
function fatigueRuleTwoDetectsSlowerResponses(logger as Logger) as Boolean {
    var slowing = new AlertLog();
    fatigueAnswered(slowing, 1 * FATIGUE_MIN, 1000);
    fatigueAnswered(slowing, 2 * FATIGUE_MIN, 1500);
    fatigueAnswered(slowing, 3 * FATIGUE_MIN, 2000);
    Test.assertMessage(FatiguePredictor.isSlowing(slowing, 0), "1,0 → 1,5 → 2,0 s");

    var almost = new AlertLog();
    fatigueAnswered(almost, 1 * FATIGUE_MIN, 1000);
    fatigueAnswered(almost, 2 * FATIGUE_MIN, 1500);
    fatigueAnswered(almost, 3 * FATIGUE_MIN, 1999);
    Test.assertMessage(!FatiguePredictor.isSlowing(almost, 0), "999 ms más: no basta");

    var flat = new AlertLog();
    fatigueAnswered(flat, 1 * FATIGUE_MIN, 1000);
    fatigueAnswered(flat, 2 * FATIGUE_MIN, 3000);
    fatigueAnswered(flat, 3 * FATIGUE_MIN, 3000);
    Test.assertMessage(!FatiguePredictor.isSlowing(flat, 0), "dos iguales no es aumento");

    var down = new AlertLog();
    fatigueAnswered(down, 1 * FATIGUE_MIN, 1000);
    fatigueAnswered(down, 2 * FATIGUE_MIN, 4000);
    fatigueAnswered(down, 3 * FATIGUE_MIN, 3000);
    Test.assertMessage(!FatiguePredictor.isSlowing(down, 0), "la última más rápida");

    var two = new AlertLog();
    fatigueAnswered(two, 1 * FATIGUE_MIN, 1000);
    fatigueAnswered(two, 2 * FATIGUE_MIN, 5000);
    Test.assertMessage(!FatiguePredictor.isSlowing(two, 0), "hacen falta 3 respuestas");

    // Solo cuentan las 3 últimas: una rápida antes no importa.
    var longer = new AlertLog();
    fatigueAnswered(longer, 1 * FATIGUE_MIN, 9000);
    fatigueAnswered(longer, 2 * FATIGUE_MIN, 1000);
    fatigueAnswered(longer, 3 * FATIGUE_MIN, 2000);
    fatigueAnswered(longer, 4 * FATIGUE_MIN, 3000);
    Test.assertMessage(FatiguePredictor.isSlowing(longer, 0), "las 3 últimas suben");

    // Efecto: sube un nivel. Con la ventana de 30 min ya en Alto (3 episodios); con
    // una ventana que solo ve el último, de Moderado a Alto; sin ninguno, de Bajo a
    // Moderado.
    var window = FatiguePredictor.WINDOW_MS;
    Test.assertEqual(FatiguePredictor.assess(slowing, 4 * FATIGUE_MIN, window, 0), FatigueLevel.HIGH);
    Test.assertEqualMessage(FatiguePredictor.assess(slowing, 4 * FATIGUE_MIN, FATIGUE_MIN, 0),
        FatigueLevel.HIGH, "1 reciente (Moderado) + tendencia = Alto");
    Test.assertEqualMessage(FatiguePredictor.assess(slowing, 60 * FATIGUE_MIN, window, 0),
        FatigueLevel.MODERATE, "ninguno reciente (Bajo) + tendencia = Moderado");
    Test.assertEqual(FatiguePredictor.assess(almost, 4 * FATIGUE_MIN, FATIGUE_MIN, 0),
        FatigueLevel.MODERATE);
    return true;
}

//! Regla 2: las alertas sin respuesta no entran en la tendencia.
(:test)
function fatigueRuleTwoSkipsUnansweredAlerts(logger as Logger) as Boolean {
    var log = new AlertLog();
    fatigueAnswered(log, 1 * FATIGUE_MIN, 1000);
    fatigueAnswered(log, 2 * FATIGUE_MIN, 2000);
    log.add(new AlertRecord(DrowsinessEvent.INACTIVITY, 2, 3 * FATIGUE_MIN, null));
    Test.assertMessage(!FatiguePredictor.isSlowing(log, 0), "solo hay 2 respuestas");
    fatigueAnswered(log, 4 * FATIGUE_MIN, 3000);
    Test.assertMessage(FatiguePredictor.isSlowing(log, 0), "1 → 2 → 3 s, sin contar la de en medio");
    return true;
}

//! Regla 3: haber llegado al nivel 3 deja la fatiga al menos en Moderado, aunque la
//! alerta quede fuera de la ventana; no baja un Alto.
(:test)
function fatigueRuleThreeMaxAlertLevel(logger as Logger) as Boolean {
    var window = FatiguePredictor.WINDOW_MS;
    var log = new AlertLog();
    log.add(new AlertRecord(DrowsinessEvent.NOD, 2, 1 * FATIGUE_MIN, 15000));
    Test.assertMessage(!FatiguePredictor.reachedMaxLevel(log, 0), "nivel 2 no basta");
    Test.assertEqual(FatiguePredictor.assess(log, 120 * FATIGUE_MIN, window, 0), FatigueLevel.LOW);

    log.add(new AlertRecord(DrowsinessEvent.NOD, 3, 2 * FATIGUE_MIN, null));
    Test.assertMessage(FatiguePredictor.reachedMaxLevel(log, 0), "llegó al 3 (sin respuesta)");
    Test.assertEqualMessage(FatiguePredictor.assess(log, 120 * FATIGUE_MIN, window, 0),
        FatigueLevel.MODERATE, "fuera de la ventana pero llegó al 3: Moderado");

    var high = new AlertLog();
    fatigueAnswered(high, 1 * FATIGUE_MIN, 2000);
    fatigueAnswered(high, 2 * FATIGUE_MIN, 2000);
    high.add(new AlertRecord(DrowsinessEvent.NOD, 3, 3 * FATIGUE_MIN, 21000));
    Test.assertEqualMessage(FatiguePredictor.assess(high, 4 * FATIGUE_MIN, window, 0),
        FatigueLevel.HIGH, "la regla 3 nunca baja el nivel");
    return true;
}

//! Un descanso completo (sinceMs) reinicia las tres reglas.
(:test)
function fatigueRestartsAfterCompletedBreak(logger as Logger) as Boolean {
    var demo = FatiguePredictor.WINDOW_DEMO_MS;
    var log = new AlertLog();
    fatigueAnswered(log, 10000, 1000);
    fatigueAnswered(log, 30000, 2000);
    log.add(new AlertRecord(DrowsinessEvent.INACTIVITY, 3, 50000, 21000));
    Test.assertEqual(FatiguePredictor.assess(log, 80000, demo, 0), FatigueLevel.HIGH);

    // Descanso de 30 s que termina a los 110 s.
    Test.assertEqualMessage(FatiguePredictor.assess(log, 110000, demo, 110000),
        FatigueLevel.LOW, "tras el descanso: Bajo");
    Test.assertMessage(!FatiguePredictor.isSlowing(log, 110000), "sin tendencia anterior");
    Test.assertMessage(!FatiguePredictor.reachedMaxLevel(log, 110000), "sin nivel 3 anterior");

    fatigueAnswered(log, 120000, 1500);
    Test.assertEqualMessage(FatiguePredictor.assess(log, 125000, demo, 110000),
        FatigueLevel.MODERATE, "un episodio nuevo cuenta");
    return true;
}
