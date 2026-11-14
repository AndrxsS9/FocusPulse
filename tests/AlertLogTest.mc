import Toybox.Lang;
import Toybox.Test;

//! Pruebas de AlertLog y de AlertnessScore.raiseTo (lo que pasa al descartar una alerta).

(:test)
function alertLogKeepsRecordsInOrder(logger as Logger) as Boolean {
    var log = new AlertLog();
    Test.assertEqual(log.size(), 0);
    Test.assertMessage(log.last() == null, "vacío: sin última alerta");
    Test.assertEqual(log.averageResponseMs(), 0);

    log.add(new AlertRecord(DrowsinessEvent.NOD, 1, 6000, 1200));
    log.add(new AlertRecord(DrowsinessEvent.INACTIVITY, 1, 20000, 2800));
    Test.assertEqual(log.size(), 2);
    Test.assertEqual(log.get(0).reason, DrowsinessEvent.NOD);
    Test.assertEqual((log.last() as AlertRecord).responseMs as Number, 2800);
    Test.assertEqual(log.averageResponseMs(), 2000);

    log.clear();
    Test.assertEqual(log.size(), 0);
    return true;
}

(:test)
function alertLogDropsOldestWhenFull(logger as Logger) as Boolean {
    var log = new AlertLog();
    for (var i = 0; i < AlertLog.CAPACITY + 5; i++) {
        log.add(new AlertRecord(DrowsinessEvent.INACTIVITY, 1, i * 1000, i));
    }
    Test.assertEqual(log.size(), AlertLog.CAPACITY);
    Test.assertEqualMessage(log.get(0).responseMs as Number, 5, "se descartaron las 5 más antiguas");
    Test.assertEqual((log.last() as AlertRecord).responseMs as Number, AlertLog.CAPACITY + 4);
    return true;
}

(:test)
function alertnessScoreRaisesToFloorOnly(logger as Logger) as Boolean {
    var score = new AlertnessScore();
    score.reset();
    // Inerte durante 30 s: baja a la banda roja.
    var inert = [0.0f, 0.0f, 0.0f, 1.0f] as Array<Float>;
    for (var i = 0; i < 30; i++) {
        score.update(inert, 1.0f);
    }
    Test.assertMessage(score.value() < 35, "antes de la alerta: " + score.value());
    Test.assertEqual(score.raiseTo(70.0f), 70);
    // Si ya estaba por encima, no lo baja.
    var high = new AlertnessScore();
    high.reset();
    Test.assertEqual(high.raiseTo(70.0f), 88);
    // Nunca pasa de 100.
    Test.assertEqual(high.raiseTo(150.0f), 100);
    return true;
}

//! Cada alerta guarda el nivel más alto que alcanzó; el registro da el máximo.
(:test)
function alertLogKeepsMaxLevelReached(logger as Logger) as Boolean {
    var log = new AlertLog();
    Test.assertEqual(log.maxLevel(), 0);
    var alerts = new AlertController();
    alerts.onEvent(DrowsinessEvent.NOD, 0);
    alerts.update(10000);
    var response = alerts.dismiss(12500) as Number;
    log.add(new AlertRecord(alerts.reason(), alerts.level(), alerts.startMs(), response));
    log.add(new AlertRecord(DrowsinessEvent.INACTIVITY, 1, 30000, 900));
    Test.assertEqualMessage(log.get(0).maxLevel, 2, "respondida en el nivel 2");
    Test.assertEqual(log.get(0).responseMs as Number, 12500);
    Test.assertEqual(log.maxLevel(), 2);
    return true;
}
