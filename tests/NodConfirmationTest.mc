import Toybox.Lang;
import Toybox.Test;

//! Pruebas de NodConfirmation (source/core): la confirmación del cabeceo por el modelo,
//! sola y en la cadena completa del reloj (DetectorRig) con la fuente simulada.

(:test)
function nodConfirmationWaitsAndChecksNormal(logger as Logger) as Boolean {
    var c = new NodConfirmation();
    Test.assertMessage(c.isEnabled(), "activada por defecto");
    // CABECEO: se retiene 2 lotes; el modelo ya no ve Normal → se confirma.
    Test.assertEqual(c.update(DrowsinessEvent.NOD, 0.9f), DrowsinessEvent.NONE);
    Test.assertMessage(c.isPending(), "pendiente tras el evento");
    Test.assertEqual(c.update(DrowsinessEvent.NONE, 0.5f), DrowsinessEvent.NONE);
    Test.assertEqual(c.update(DrowsinessEvent.NONE, 0.10f), DrowsinessEvent.NOD);
    Test.assertMessage(!c.isPending(), "decidido");
    Test.assertEqual(c.confirmedCount(), 1);

    // Si Normal sigue dominando (≥ 0,35) se descarta.
    c.update(DrowsinessEvent.NOD, 0.4f);
    c.update(DrowsinessEvent.NONE, 0.4f);
    Test.assertEqual(c.update(DrowsinessEvent.NONE, NodConfirmation.NORMAL_MAX), DrowsinessEvent.NONE);
    Test.assertEqual(c.rejectedCount(), 1);
    Test.assertEqual(c.lastNormal(), NodConfirmation.NORMAL_MAX);
    // Después no queda nada pendiente.
    Test.assertEqual(c.update(DrowsinessEvent.NONE, 0.0f), DrowsinessEvent.NONE);

    // La inactividad pasa en el acto, sin el modelo.
    Test.assertEqual(c.update(DrowsinessEvent.INACTIVITY, 1.0f), DrowsinessEvent.INACTIVITY);

    c.reset();
    Test.assertEqual(c.confirmedCount(), 0);
    Test.assertEqual(c.rejectedCount(), 0);
    return true;
}

(:test)
function nodConfirmationDisabledPassesNodsThrough(logger as Logger) as Boolean {
    var c = new NodConfirmation();
    c.setEnabled(false);
    Test.assertEqual(c.update(DrowsinessEvent.NOD, 0.99f), DrowsinessEvent.NOD);
    // Desactivarla con un cabeceo pendiente lo deja salir en el lote siguiente.
    c.setEnabled(true);
    c.update(DrowsinessEvent.NOD, 0.9f);
    c.setEnabled(false);
    Test.assertEqual(c.update(DrowsinessEvent.NONE, 0.9f), DrowsinessEvent.NOD);
    Test.assertMessage(!c.isPending(), "nada pendiente");
    return true;
}

(:test)
function nodConfirmationAlertsOnRealNod(logger as Logger) as Boolean {
    // Cabeceo simulado: el detector lo ve a los 6 s y, 2 s después, el brazo dormido ya
    // es Inerte para el modelo: la alerta llega a los 8 s.
    for (var seed = 1; seed <= 5; seed++) {
        var rig = new DetectorRig(AccelScenario.NOD, seed, true);
        rig.run(20);
        Test.assertEqualMessage(rig.nods, 1, "semilla " + seed + ": un cabeceo del detector");
        Test.assertEqualMessage(rig.alertNods, 1, "semilla " + seed + ": el modelo lo confirma");
        Test.assertEqual(rig.firstNodMs as Number, 6000);
        Test.assertEqual(rig.firstAlertNodMs as Number,
            6000 + NodConfirmation.DELAY_BATCHES * 1000);
        Test.assertMessage(rig.confirmation.lastNormal() < NodConfirmation.NORMAL_MAX,
            "p(Normal) " + rig.confirmation.lastNormal().format("%.2f"));
    }
    return true;
}

(:test)
function nodConfirmationRejectsGlanceAfterTyping(logger as Logger) as Boolean {
    // Mirar la hora justo después de teclear: el detector lo toma por cabeceo (la
    // sacudida del tecleo deja abierta la caída candidata, el brazo sostenido está quieto
    // y la muñeca giró 80°), pero el modelo sigue viendo Normal: no hay alerta.
    for (var seed = 1; seed <= 5; seed++) {
        var rig = DetectorRig.glanceAfterTyping(seed);
        rig.run(10);
        Test.assertEqualMessage(rig.nods, 1, "semilla " + seed + ": la regla da un cabeceo");
        Test.assertEqualMessage(rig.alertNods, 0, "semilla " + seed + ": sin alerta");
        Test.assertEqual(rig.confirmation.rejectedCount(), 1);
        logger.debug("semilla " + seed + ": p(Normal) " + rig.confirmation.lastNormal().format("%.2f"));
    }
    return true;
}

(:test)
function nodConfirmationOffKeepsPreviousBehavior(logger as Logger) as Boolean {
    // Con el ajuste desactivado: la alerta sale con el evento del detector, como antes,
    // también al mirar la hora tras teclear.
    var nod = new DetectorRig(AccelScenario.NOD, 3, true);
    nod.confirmation.setEnabled(false);
    nod.run(20);
    Test.assertEqual(nod.alertNods, 1);
    Test.assertEqual(nod.firstAlertNodMs as Number, 6000);

    var glance = DetectorRig.glanceAfterTyping(3);
    glance.confirmation.setEnabled(false);
    glance.run(10);
    Test.assertEqualMessage(glance.alertNods, 1, "sin confirmación, mirar la hora da alerta");
    Test.assertEqual(glance.alertNods, glance.nods);
    return true;
}

(:test)
function nodConfirmationLeavesInactivityAlone(logger as Logger) as Boolean {
    var rig = new DetectorRig(AccelScenario.INACTIVITY, 9, true);
    rig.run(20);
    Test.assertEqual(rig.firstInactivityMs as Number, 8000);
    Test.assertEqual(rig.alertNods, 0);
    Test.assertEqual(rig.confirmation.confirmedCount() + rig.confirmation.rejectedCount(), 0);
    return true;
}
