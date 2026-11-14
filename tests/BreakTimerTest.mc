import Toybox.Lang;
import Toybox.Test;

//! Pruebas del descanso guiado (BreakTimer): duración de cada modo, cuenta regresiva,
//! fin único y cancelación; y el formato "M:SS" del reloj de la vista.

(:test)
function breakLastsFifteenMinutesOrThirtySecondsInDemo(logger as Logger) as Boolean {
    Test.assertEqual(BreakTimer.DURATION_MS, 15 * 60 * 1000);
    Test.assertEqual(BreakTimer.DURATION_DEMO_MS, 30 * 1000);
    var config = new DemoConfig();
    Test.assertEqualMessage(config.breakMs(), 900000, "sensor real: 15 min");
    config.setEnabled(true);
    Test.assertEqualMessage(config.breakMs(), 30000, "modo demo: 30 s");

    // En cada modo termina exactamente a su duración, ni 1 ms antes.
    var modes = [false, true] as Array<Boolean>;
    for (var i = 0; i < modes.size(); i++) {
        var duration = BreakTimer.durationMsFor(modes[i]);
        var timer = new BreakTimer();
        timer.start(1000, duration);
        Test.assertMessage(!timer.update(1000 + duration - 1), "1 ms antes sigue");
        Test.assertEqual(timer.remainingMs(1000 + duration - 1), 1);
        Test.assertMessage(timer.update(1000 + duration), "termina a los " + duration + " ms");
        Test.assert(timer.isFinished());
    }
    return true;
}

(:test)
function breakCountsDownAndEmptiesRing(logger as Logger) as Boolean {
    var timer = new BreakTimer();
    Test.assertMessage(!timer.isRunning(), "sin descanso");
    Test.assertEqual(timer.progress(0), 0.0f);
    timer.start(0, 30000);
    Test.assertEqual(timer.progress(0), 1.0f);
    Test.assertEqual(timer.progress(15000), 0.5f);
    Test.assertEqual(timer.remainingSeconds(0), 30);
    Test.assertEqualMessage(timer.remainingSeconds(29001), 1, "el último segundo marca 0:01");
    Test.assertEqual(timer.remainingSeconds(500), 30);
    Test.assertEqualMessage(timer.remainingMs(-500), 30000, "nunca más que la duración");

    Test.assertMessage(timer.update(30000), "termina");
    Test.assertMessage(!timer.update(31000), "avisa del fin una sola vez");
    Test.assertEqual(timer.progress(31000), 0.0f);
    Test.assertEqual(timer.remainingSeconds(31000), 0);
    Test.assertMessage(timer.isRunning(), "terminado espera a Reanudar");
    return true;
}

(:test)
function breakCancelStopsCountdown(logger as Logger) as Boolean {
    var timer = new BreakTimer();
    timer.start(0, 900000);
    timer.update(60000);
    timer.cancel();
    Test.assertMessage(!timer.isRunning(), "BACK lo detiene");
    Test.assertMessage(!timer.update(900000), "cancelado no termina");
    Test.assertMessage(!timer.isFinished(), "ni queda terminado");

    // Una duración no positiva usa la normal.
    timer.start(0, 0);
    Test.assertEqual(timer.durationMs(), BreakTimer.DURATION_MS);
    return true;
}

(:test)
function clockFormatsCountdown(logger as Logger) as Boolean {
    Test.assertEqual(ClockFormat.countdown(900), "15:00");
    Test.assertEqual(ClockFormat.countdown(899), "14:59");
    Test.assertEqual(ClockFormat.countdown(30), "0:30");
    Test.assertEqual(ClockFormat.countdown(5), "0:05");
    Test.assertEqual(ClockFormat.countdown(0), "0:00");
    Test.assertEqual(ClockFormat.countdown(-3), "0:00");
    return true;
}
