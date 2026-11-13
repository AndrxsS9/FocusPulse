import Toybox.Lang;
import Toybox.Test;

//! Pruebas de FrameStats (source/util): cuadros por segundo y tiempo de dibujo con
//! tiempos inventados.

//! Dibuja frames cuadros cada periodMs ms, cada uno de drawMs ms, desde startMs.
//! Devuelve cuántas ventanas se cerraron.
function feedFrames(stats as FrameStats, frames as Number, periodMs as Number, drawMs as Number,
        startMs as Number) as Number {
    var closed = 0;
    for (var i = 0; i < frames; i++) {
        var t = startMs + i * periodMs;
        if (stats.frame(t, t + drawMs)) {
            closed += 1;
        }
    }
    return closed;
}

(:test)
function frameStatsWaitsForAFullWindow(logger as Logger) as Boolean {
    var stats = new FrameStats();
    // 4,9 s de cuadros: aún no se cierra la ventana de 5 s.
    Test.assertEqual(feedFrames(stats, 59, 83, 5, 1000), 0);
    Test.assertEqual(stats.frames, 0);
    return true;
}

(:test)
function frameStatsMeasuresTwelveFramesPerSecond(logger as Logger) as Boolean {
    var stats = new FrameStats();
    // Un cuadro cada 83 ms durante algo más de 5 s.
    Test.assertEqual(feedFrames(stats, 62, 83, 6, 0), 1);
    logger.debug("fps=" + stats.fps + " cuadros=" + stats.frames);
    Test.assertEqual(stats.frames, 62);
    // 62 cuadros entre t = 0 y el final del último (61 × 83 + 6 = 5069 ms): 12,23 por s.
    Test.assert(nearlyEqual(stats.fps, 62 * 1000.0f / 5069, 0.01f));
    Test.assert(nearlyEqual(stats.drawAvgMs, 6.0f, 0.001f));
    Test.assertEqual(stats.drawMaxMs, 6);
    return true;
}

(:test)
function frameStatsTracksAverageAndMaxDrawTime(logger as Logger) as Boolean {
    var stats = new FrameStats();
    var t = 0;
    var closed = false;
    var draws = [4, 16, 4, 0] as Array<Number>;
    var i = 0;
    while (!closed) {
        closed = stats.frame(t, t + draws[i % 4]);
        t += 1000;
        i += 1;
    }
    // 6 cuadros (t = 0 … 5000): 4, 16, 4, 0, 4, 16 → media 7,33; máximo 16.
    Test.assertEqual(stats.frames, 6);
    Test.assert(nearlyEqual(stats.drawAvgMs, 44.0f / 6, 0.01f));
    Test.assertEqual(stats.drawMaxMs, 16);
    return true;
}

(:test)
function frameStatsStartsANewWindowAfterReset(logger as Logger) as Boolean {
    var stats = new FrameStats();
    feedFrames(stats, 30, 83, 5, 0);
    stats.reset();
    // Tras reset la ventana empieza en el siguiente cuadro, no en el primero de antes.
    Test.assertEqual(feedFrames(stats, 6, 1000, 30, 10000), 1);
    Test.assertEqual(stats.frames, 6);
    Test.assertEqual(stats.drawMaxMs, 30);
    return true;
}
