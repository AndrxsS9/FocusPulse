import Toybox.Lang;
import Toybox.Test;

//! Pruebas de AlertController (source/core): apertura por evento, eventos ignorados con
//! la alerta activa, tiempo de respuesta y cierre sin respuesta al pausar.

(:test)
function alertOpensAtLevelOneOnDetectorEvents(logger as Logger) as Boolean {
    var nod = new AlertController();
    Test.assertMessage(nod.onEvent(DrowsinessEvent.NOD, 6000), "un cabeceo abre la alerta");
    Test.assert(nod.isActive());
    Test.assertEqual(nod.level(), 1);
    Test.assertEqual(nod.reason(), DrowsinessEvent.NOD);
    Test.assertEqual(nod.startMs(), 6000);

    var inactivity = new AlertController();
    Test.assertMessage(inactivity.onEvent(DrowsinessEvent.INACTIVITY, 8000),
        "una inactividad abre la alerta");
    Test.assertEqual(inactivity.level(), 1);
    Test.assertEqual(inactivity.reason(), DrowsinessEvent.INACTIVITY);
    return true;
}

(:test)
function alertIgnoresNoneEvent(logger as Logger) as Boolean {
    var alerts = new AlertController();
    Test.assertMessage(!alerts.onEvent(DrowsinessEvent.NONE, 1000), "NONE no abre nada");
    Test.assert(!alerts.isActive());
    Test.assertEqual(alerts.lastOutcome(), AlertOutcome.NONE);
    return true;
}

(:test)
function alertIgnoresEventsWhileActive(logger as Logger) as Boolean {
    var alerts = new AlertController();
    alerts.onEvent(DrowsinessEvent.NOD, 6000);
    Test.assertMessage(!alerts.onEvent(DrowsinessEvent.INACTIVITY, 16000),
        "otra inactividad con la alerta abierta se ignora");
    Test.assertMessage(!alerts.trigger(3, DrowsinessEvent.NOD, 17000),
        "un trigger con la alerta abierta también");
    Test.assertEqual(alerts.reason(), DrowsinessEvent.NOD);
    Test.assertEqual(alerts.startMs(), 6000);
    Test.assertEqual(alerts.level(), 1);
    return true;
}

(:test)
function alertDismissReturnsResponseTime(logger as Logger) as Boolean {
    var alerts = new AlertController();
    alerts.onEvent(DrowsinessEvent.INACTIVITY, 8000);
    Test.assertEqual(alerts.elapsedMs(9500), 1500);

    var response = alerts.dismiss(10350) as Number;
    Test.assertEqualMessage(response, 2350, "respuesta = descarte − inicio");
    Test.assert(!alerts.isActive());
    Test.assertEqual(alerts.lastOutcome(), AlertOutcome.DISMISSED);
    Test.assertEqual(alerts.lastResponseMs() as Number, 2350);
    Test.assertEqual(alerts.elapsedMs(11000), 0);

    Test.assertMessage(alerts.dismiss(12000) == null, "sin alerta activa no hay respuesta");
    Test.assertMessage(alerts.onEvent(DrowsinessEvent.NOD, 20000),
        "tras descartar, un evento nuevo vuelve a abrir la alerta");
    Test.assertEqual(alerts.startMs(), 20000);
    return true;
}

(:test)
function alertDismissNeverReturnsNegativeTime(logger as Logger) as Boolean {
    var alerts = new AlertController();
    alerts.onEvent(DrowsinessEvent.NOD, 5000);
    Test.assertEqual(alerts.dismiss(4000) as Number, 0);
    return true;
}

(:test)
function alertCancelClosesWithoutResponse(logger as Logger) as Boolean {
    var alerts = new AlertController();
    alerts.onEvent(DrowsinessEvent.NOD, 6000);
    alerts.dismiss(7000);
    alerts.onEvent(DrowsinessEvent.INACTIVITY, 20000);

    Test.assertMessage(alerts.cancel(), "pausar cierra la alerta activa");
    Test.assert(!alerts.isActive());
    Test.assertEqual(alerts.lastOutcome(), AlertOutcome.CANCELLED);
    Test.assertMessage(alerts.lastResponseMs() == null, "una alerta cancelada no tiene respuesta");
    Test.assertMessage(alerts.dismiss(21000) == null, "ya no se puede descartar");
    Test.assertMessage(!alerts.cancel(), "cancelar sin alerta no hace nada");
    return true;
}

(:test)
function alertTriggerClampsLevel(logger as Logger) as Boolean {
    var high = new AlertController();
    high.trigger(7, DrowsinessEvent.NOD, 0);
    Test.assertEqual(high.level(), 3);
    var low = new AlertController();
    low.trigger(0, DrowsinessEvent.INACTIVITY, 0);
    Test.assertEqual(low.level(), 1);
    var medium = new AlertController();
    medium.trigger(2, DrowsinessEvent.NOD, 0);
    Test.assertEqual(medium.level(), 2);
    return true;
}

// --- Escalamiento ---------------------------------------------------------------

//! Sensor real: 1 → 2 a los 10 s y 2 → 3 a los 10 s siguientes, ni un ms antes.
(:test)
function alertEscalatesEveryTenSecondsWithRealSensor(logger as Logger) as Boolean {
    var alerts = new AlertController();
    Test.assertEqual(alerts.escalationMs(), AlertController.ESCALATION_MS);
    Test.assertEqual(AlertController.ESCALATION_MS, 10000);
    alerts.onEvent(DrowsinessEvent.NOD, 5000);
    Test.assertEqual(alerts.msToNextLevel(5000), 10000);

    Test.assertMessage(!alerts.update(14999), "1 ms antes de los 10 s sigue en el nivel 1");
    Test.assertEqual(alerts.level(), 1);
    Test.assertMessage(alerts.update(15000), "a los 10 s sube");
    Test.assertEqual(alerts.level(), 2);
    Test.assertEqual(alerts.levelStartMs(), 15000);
    Test.assertEqual(alerts.levelElapsedMs(15400), 400);
    Test.assertMessage(!alerts.update(15000), "el mismo instante no vuelve a subir");

    Test.assertMessage(!alerts.update(24999), "nivel 2 hasta los 20 s");
    Test.assertMessage(alerts.update(25000), "a los 20 s, nivel 3");
    Test.assertEqual(alerts.level(), 3);
    Test.assertEqual(alerts.startLevel(), 1);
    Test.assertEqual(alerts.startMs(), 5000);
    return true;
}

//! Modo demo: cada 6 s (6 y 12 s), igual que DemoConfig.alertEscalationMs().
(:test)
function alertEscalatesEverySixSecondsInDemo(logger as Logger) as Boolean {
    var config = new DemoConfig();
    Test.assertEqual(config.alertEscalationMs(), 10000);
    config.setEnabled(true);
    Test.assertEqual(config.alertEscalationMs(), 6000);
    Test.assertEqual(AlertController.escalationMsFor(true), AlertController.ESCALATION_DEMO_MS);

    var alerts = new AlertController();
    alerts.setEscalationMs(config.alertEscalationMs());
    alerts.onEvent(DrowsinessEvent.INACTIVITY, 0);
    var levels = [] as Array<Number>;
    // Lotes de 1 s durante 20 s: anota en qué segundo llega cada nivel.
    for (var t = 1000; t <= 20000; t += 1000) {
        if (alerts.update(t)) {
            levels.add(t);
        }
    }
    Test.assertEqualMessage(levels.size(), 2, "dos subidas: " + levels);
    Test.assertEqual(levels[0], 6000);
    Test.assertEqual(levels[1], 12000);
    Test.assertEqual(alerts.level(), 3);
    return true;
}

//! El nivel 3 se mantiene hasta la respuesta: ni sube más ni cambia de inicio.
(:test)
function alertLevelThreeHoldsUntilAnswered(logger as Logger) as Boolean {
    var alerts = new AlertController();
    alerts.onEvent(DrowsinessEvent.NOD, 0);
    alerts.update(20000);
    Test.assertEqual(alerts.level(), 3);
    Test.assertEqual(alerts.msToNextLevel(20000), -1);
    for (var t = 21000; t <= 600000; t += 1000) {
        Test.assertMessage(!alerts.update(t), "el nivel 3 no sube");
    }
    Test.assertEqual(alerts.level(), 3);
    Test.assertEqual(alerts.levelStartMs(), 20000);
    Test.assertEqualMessage(alerts.dismiss(600000) as Number, 600000,
        "la respuesta cuenta desde que se abrió la alerta");
    Test.assertEqualMessage(alerts.level(), 3, "tras responder queda el nivel máximo");

    // Una alerta de prueba que abre en el 3 tampoco sube.
    var test = new AlertController();
    test.trigger(3, DrowsinessEvent.NOD, 0);
    Test.assertMessage(!test.update(60000), "abre en el 3 y se queda");
    return true;
}

//! Responder detiene el escalamiento; la siguiente alerta empieza otra vez en el 1.
(:test)
function alertEscalationStopsWhenAnswered(logger as Logger) as Boolean {
    var alerts = new AlertController();
    alerts.onEvent(DrowsinessEvent.NOD, 0);
    alerts.update(10000);
    Test.assertEqual(alerts.dismiss(13000) as Number, 13000);
    Test.assertMessage(!alerts.update(40000), "sin alerta no hay escalamiento");
    Test.assertEqual(alerts.level(), 2);
    Test.assertEqual(alerts.msToNextLevel(40000), -1);
    Test.assertEqual(alerts.levelElapsedMs(40000), 0);

    Test.assertMessage(alerts.onEvent(DrowsinessEvent.INACTIVITY, 50000), "nueva alerta");
    Test.assertEqualMessage(alerts.level(), 1, "vuelve a empezar en el 1");
    Test.assertMessage(!alerts.update(59999), "su escalamiento cuenta desde su inicio");
    Test.assertMessage(alerts.update(60000), "sube a los 10 s de abrirse");

    // Cancelar (pausa) también lo detiene.
    alerts.cancel();
    Test.assertMessage(!alerts.update(90000), "cancelada no sube");
    return true;
}

//! Si update llega tarde sube todos los niveles pendientes, y una alerta de nivel 2
//! llega al 3 tras un solo intervalo.
(:test)
function alertEscalationCatchesUpAndStartsFromTriggerLevel(logger as Logger) as Boolean {
    var alerts = new AlertController();
    alerts.onEvent(DrowsinessEvent.NOD, 0);
    Test.assertMessage(alerts.update(25000), "25 s sin update: sube");
    Test.assertEqualMessage(alerts.level(), 3, "de una vez al 3");
    Test.assertEqualMessage(alerts.levelStartMs(), 20000, "el nivel 3 empezó a los 20 s");

    var medium = new AlertController();
    medium.trigger(2, DrowsinessEvent.INACTIVITY, 1000);
    Test.assertEqual(medium.startLevel(), 2);
    Test.assertMessage(medium.update(11000), "nivel 2 → 3 a los 10 s");
    Test.assertEqual(medium.level(), 3);

    // Un tiempo de escalamiento no positivo se ignora.
    medium.setEscalationMs(0);
    Test.assertEqual(medium.escalationMs(), AlertController.ESCALATION_MS);
    return true;
}
