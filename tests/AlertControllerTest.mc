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
