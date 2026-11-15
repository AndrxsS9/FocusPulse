import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

//! Pruebas del resumen de guardia (GuardSummary), del historial (SessionHistory) y de
//! HistoryStore con el Application.Storage real del simulador.

//! Resumen de prueba: guardia que empezó en dateSec, de 2 min, con `episodes` episodios.
(:debug)
function historySummary(dateSec as Number, episodes as Number) as GuardSummary {
    return new GuardSummary(dateSec, 120000, episodes, 2500, 2, FatigueLevel.MODERATE, false);
}

//! Regla: no se muestra con menos de 1 min y sin episodios; sí en cualquier otro caso.
(:test)
function guardSummaryShowsAfterOneMinuteOrAnEpisode(logger as Logger) as Boolean {
    Test.assertEqual(GuardSummary.MIN_DURATION_MS, 60000);
    Test.assertMessage(!GuardSummary.shouldShow(0, 0), "recién iniciada y pausada");
    Test.assertMessage(!GuardSummary.shouldShow(59999, 0), "59,999 s sin episodios: no");
    Test.assertMessage(GuardSummary.shouldShow(60000, 0), "1 min justo: sí");
    Test.assertMessage(GuardSummary.shouldShow(5000, 1), "5 s con un episodio: sí");
    Test.assertMessage(GuardSummary.shouldShow(3600000, 4), "larga con episodios: sí");
    return true;
}

//! El resumen sale de los episodios: media solo de las respondidas, nivel máximo.
(:test)
function guardSummaryComesFromEpisodes(logger as Logger) as Boolean {
    var log = new AlertLog();
    log.add(new AlertRecord(DrowsinessEvent.NOD, 1, 10000, 2000));
    log.add(new AlertRecord(DrowsinessEvent.INACTIVITY, 2, 40000, 7000));
    log.add(new AlertRecord(DrowsinessEvent.INACTIVITY, 3, 80000, null));
    var summary = GuardSummary.fromEpisodes(1763100000, 95000, log, FatigueLevel.HIGH, true);
    Test.assertEqual(summary.episodes, 3);
    Test.assertEqualMessage(summary.avgResponseMs as Number, 4500, "media de 2 y 7 s");
    Test.assertEqual(summary.maxLevel, 3);
    Test.assertEqual(summary.fatigue, FatigueLevel.HIGH);
    Test.assert(summary.demo);
    Test.assert(summary.isWorthShowing());

    var empty = GuardSummary.fromEpisodes(1763100000, 30000, new AlertLog(), FatigueLevel.LOW, false);
    Test.assertMessage(empty.avgResponseMs == null, "sin respuestas no hay media");
    Test.assertEqual(empty.maxLevel, 0);
    Test.assertMessage(!empty.isWorthShowing(), "30 s sin episodios");
    return true;
}

//! Guardar y leer: el resumen y el historial pasan por el formato de Storage sin cambiar.
(:test)
function sessionHistoryRoundTripsThroughStorageFormat(logger as Logger) as Boolean {
    var history = new SessionHistory();
    history.add(new GuardSummary(1763100000, 754000, 3, null, 3, FatigueLevel.HIGH, true));
    history.add(historySummary(1763200000, 1));
    var loaded = SessionHistory.fromStorage(history.toStorage());
    Test.assertEqual(loaded.size(), 2);
    Test.assertEqualMessage(loaded.get(0).dateSec, 1763200000, "la más reciente primero");
    var old = loaded.get(1);
    Test.assertEqual(old.durationMs, 754000);
    Test.assertEqual(old.episodes, 3);
    Test.assertMessage(old.avgResponseMs == null, "sin media se conserva como null");
    Test.assertEqual(old.maxLevel, 3);
    Test.assertEqual(old.fatigue, FatigueLevel.HIGH);
    Test.assert(old.demo);
    Test.assertEqual(loaded.get(0).avgResponseMs as Number, 2500);
    return true;
}

//! Límite de 10: la undécima desplaza a la más antigua; orden de reciente a antigua.
(:test)
function sessionHistoryKeepsLastTenNewestFirst(logger as Logger) as Boolean {
    Test.assertEqual(SessionHistory.CAPACITY, 10);
    var history = new SessionHistory();
    Test.assert(history.isEmpty());
    for (var i = 1; i <= 13; i++) {
        history.add(historySummary(i, i));
        var expected = i < 10 ? i : 10;
        Test.assertEqualMessage(history.size(), expected, "tras " + i + " guardias");
    }
    Test.assertEqualMessage(history.get(0).dateSec, 13, "la última, primero");
    Test.assertEqualMessage(history.get(9).dateSec, 4, "se perdieron la 1, 2 y 3");
    for (var i = 1; i < history.size(); i++) {
        Test.assertMessage(history.get(i - 1).dateSec > history.get(i).dateSec, "orden en " + i);
    }
    // Leídas de Storage, más de 10 se recortan a las 10 primeras (más recientes).
    var data = history.toStorage();
    var items = data.get(SessionHistory.KEY_ITEMS) as Array<Array<Number or Boolean> >;
    items.add(historySummary(1, 1).toStorage());
    items.add(historySummary(2, 1).toStorage());
    var loaded = SessionHistory.fromStorage(data);
    Test.assertEqual(loaded.size(), 10);
    Test.assertEqual(loaded.get(0).dateSec, 13);
    Test.assertEqual(loaded.get(9).dateSec, 4);
    return true;
}

//! Datos corruptos o de otra versión: historial vacío; un resumen dañado se salta.
(:test)
function sessionHistoryHandlesCorruptAndOtherVersionData(logger as Logger) as Boolean {
    Test.assert(SessionHistory.fromStorage(null).isEmpty());
    Test.assert(SessionHistory.fromStorage("historial").isEmpty());
    Test.assert(SessionHistory.fromStorage([1, 2, 3]).isEmpty());
    Test.assertMessage(SessionHistory.fromStorage({ "v" => 2, "items" => [] }).isEmpty(),
        "otra versión");
    Test.assertMessage(SessionHistory.fromStorage({ "items" => [historySummary(1, 1).toStorage()] })
        .isEmpty(), "sin versión");
    Test.assertMessage(SessionHistory.fromStorage({ "v" => 1, "items" => "x" }).isEmpty(),
        "items no es una lista");

    var good = historySummary(5, 2).toStorage();
    var mixed = {
        "v" => 1,
        "items" => [
            good,
            [1, 2, 3],                                  // tamaño equivocado
            [1, 60000, 1, 900, 4, 1, false],            // nivel 4
            [1, 60000, 1, 900, 1, 3, false],            // fatiga 3
            [1, -5, 1, 900, 1, 1, false],               // duración negativa
            [1, 60000, 1, 900, 1, 1, "no"],             // demo no booleano
            [1, 60000, "1", 900, 1, 1, false],          // episodios como texto
            null,
            [7, 60000, 0, -1, 0, 0, true]               // válida
        ]
    };
    var loaded = SessionHistory.fromStorage(mixed);
    Test.assertEqualMessage(loaded.size(), 2, "solo las dos válidas");
    Test.assertEqual(loaded.get(0).dateSec, 5);
    Test.assertEqual(loaded.get(1).dateSec, 7);
    Test.assert(GuardSummary.fromStorage(good) != null);
    return true;
}

(:test)
function sessionHistoryClears(logger as Logger) as Boolean {
    var history = new SessionHistory();
    history.add(historySummary(1, 1));
    history.add(historySummary(2, 1));
    history.clear();
    Test.assert(history.isEmpty());
    Test.assertEqual(SessionHistory.fromStorage(history.toStorage()).size(), 0);
    history.add(historySummary(3, 1));
    Test.assertEqualMessage(history.size(), 1, "se puede volver a llenar");
    return true;
}

//! HistoryStore con el Storage real: guardar, leer, dato corrupto y borrar. Deja el
//! valor guardado como estaba antes de la prueba.
(:test)
function historyStoreSavesLoadsAndClears(logger as Logger) as Boolean {
    var previous = Application.Storage.getValue(HistoryStore.KEY);
    try {
        var history = new SessionHistory();
        history.add(historySummary(1763100000, 2));
        history.add(historySummary(1763200000, 0));
        HistoryStore.save(history);
        var loaded = HistoryStore.load();
        Test.assertEqual(loaded.size(), 2);
        Test.assertEqual(loaded.get(0).dateSec, 1763200000);

        Application.Storage.setValue(HistoryStore.KEY, "corrupto");
        Test.assertMessage(HistoryStore.load().isEmpty(), "dato corrupto: vacío");

        HistoryStore.save(history);
        HistoryStore.clear();
        Test.assertMessage(Application.Storage.getValue(HistoryStore.KEY) == null, "borrado");
        Test.assertMessage(HistoryStore.load().isEmpty(), "tras borrar: vacío");
    } finally {
        if (previous == null) {
            Application.Storage.deleteValue(HistoryStore.KEY);
        } else {
            Application.Storage.setValue(HistoryStore.KEY, previous as Application.Storage.ValueType);
        }
    }
    return true;
}
