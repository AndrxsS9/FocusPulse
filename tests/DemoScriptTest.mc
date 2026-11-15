import Toybox.Lang;
import Toybox.Test;

//! Pruebas del guion automático (DemoScript): orden de los pasos, tiempos, espera a la
//! alerta, el paso final sin respuesta hasta el nivel 3, cancelación y el recorrido
//! completo con el detector y el escalamiento.

(:test)
function demoScriptStepsInOrder(logger as Logger) as Boolean {
    var script = new DemoScript();
    Test.assertEqual(script.state(), DemoScriptState.IDLE);
    Test.assertEqual(script.stepNumber(), 0);
    Test.assertEqualMessage(script.scenario(), AccelScenario.NORMAL, "sin guion: normal");

    var scenarios = [AccelScenario.NORMAL, AccelScenario.TYPING, AccelScenario.NOD,
        AccelScenario.NORMAL, AccelScenario.INACTIVITY, AccelScenario.INACTIVITY]
        as Array<AccelScenario.Id>;
    var waits = [false, false, true, false, true, true] as Array<Boolean>;
    Test.assertEqual(script.stepCount(), scenarios.size());

    script.start(0);
    var now = 0;
    for (var i = 0; i < scenarios.size(); i++) {
        Test.assertEqualMessage(script.stepNumber(), i + 1, "paso " + (i + 1));
        Test.assertEqual(script.scenario(), scenarios[i]);
        Test.assertEqual(script.isWaitingForAlert(), waits[i]);
        // Pasa el paso: por tiempo, con una alerta respondida o, el último, con la alerta
        // sin responder 4 s en el nivel 3.
        if (script.isEscalationStep()) {
            script.onAlertOpened();
            script.onAlertLevel(3, now);
            now += DemoScript.MAX_LEVEL_HOLD_MS;
            Test.assertMessage(script.update(now, true), "termina con la alerta abierta");
        } else if (waits[i]) {
            script.onAlertOpened();
            Test.assertMessage(script.onAlertDismissed(now), "la respuesta termina la espera");
        } else {
            now += DemoScript.durationMs(i);
            Test.assertMessage(script.update(now, false), "termina a su tiempo");
        }
    }
    Test.assertMessage(script.isFinished(), "fin tras el paso 6");
    Test.assertEqual(script.stepNumber(), 0);
    Test.assertEqualMessage(script.scenario(), AccelScenario.NORMAL, "al terminar: normal");
    return true;
}

(:test)
function demoScriptTimedStepsLastExactly(logger as Logger) as Boolean {
    Test.assertEqual(DemoScript.durationMs(0), 10000);
    Test.assertEqual(DemoScript.durationMs(1), 10000);
    Test.assertEqual(DemoScript.durationMs(3), 8000);

    var script = new DemoScript();
    script.start(5000);
    // Lotes de 1 s: el paso 1 dura 10 lotes.
    for (var t = 6000; t < 15000; t += 1000) {
        Test.assertMessage(!script.update(t, false), "paso 1 sigue a los " + (t - 5000) + " ms");
    }
    Test.assertEqual(script.remainingMs(), 1000);
    Test.assertMessage(script.update(15000, false), "cambia justo a los 10 s");
    Test.assertEqual(script.stepNumber(), 2);
    Test.assertEqual(script.remainingMs(), 10000);

    // Un update con el mismo instante o hacia atrás no cuenta tiempo.
    Test.assertMessage(!script.update(15000, false), "dt = 0");
    Test.assertMessage(!script.update(14000, false), "dt < 0");
    Test.assertEqual(script.remainingMs(), 10000);
    return true;
}

(:test)
function demoScriptFreezesWhileAlertIsOpen(logger as Logger) as Boolean {
    var script = new DemoScript();
    script.start(0);
    script.update(4000, false);
    // 20 s con una alerta abierta (p. ej. una de prueba): no cuentan.
    for (var t = 5000; t <= 24000; t += 1000) {
        Test.assertMessage(!script.update(t, true), "congelado con la alerta");
    }
    Test.assertEqual(script.stepNumber(), 1);
    // Tras cerrarla, el primer lote no suma el tiempo de la alerta.
    script.update(25000, false);
    Test.assertEqualMessage(script.remainingMs(), 5000, "4 s antes + 1 s después");

    // Una alerta en un paso con duración no adelanta el guion al responderla.
    script.onAlertOpened();
    Test.assertMessage(!script.onAlertDismissed(25500), "solo los pasos de espera");
    Test.assertEqual(script.stepNumber(), 1);
    return true;
}

(:test)
function demoScriptWaitsForAnsweredAlert(logger as Logger) as Boolean {
    var script = new DemoScript();
    script.start(0);
    script.update(10000, false);
    script.update(20000, false);
    Test.assertEqual(script.stepNumber(), 3);
    Test.assertMessage(script.isWaitingForAlert(), "paso 3 espera el cabeceo");
    Test.assertEqual(script.remainingMs(), 0);

    // Sin alerta no avanza nunca, por mucho tiempo que pase.
    for (var t = 21000; t <= 600000; t += 1000) {
        script.update(t, false);
    }
    Test.assertEqual(script.stepNumber(), 3);
    Test.assertMessage(!script.onAlertDismissed(600000), "respuesta sin alerta: nada");

    // Alerta abierta y sin respuesta: sigue esperando.
    script.onAlertOpened();
    Test.assertMessage(script.isAlertPending(), "alerta abierta, falta la respuesta");
    for (var t = 601000; t <= 900000; t += 1000) {
        Test.assertMessage(!script.update(t, true), "no avanza solo");
    }
    Test.assertEqual(script.stepNumber(), 3);

    // "Estoy despierto": pasa al paso 4 (normal, 8 s) desde ese instante.
    Test.assertMessage(script.onAlertDismissed(900500), "la respuesta avanza");
    Test.assertEqual(script.stepNumber(), 4);
    Test.assertEqual(script.scenario(), AccelScenario.NORMAL);
    Test.assertMessage(!script.isAlertPending(), "la alerta del paso anterior no cuenta");
    Test.assertMessage(!script.update(908499, false), "aún no");
    Test.assertMessage(script.update(908500, false), "8 s después de responder");
    Test.assertEqual(script.scenario(), AccelScenario.INACTIVITY);
    Test.assertMessage(!script.onAlertDismissed(909000), "paso 5 sin su propia alerta");
    return true;
}

(:test)
function demoScriptCancels(logger as Logger) as Boolean {
    var script = new DemoScript();
    Test.assertMessage(!script.cancel(), "cancelar sin guion devuelve false");

    script.start(0);
    script.update(10000, false);
    script.update(20000, false);
    script.onAlertOpened();
    Test.assertMessage(script.cancel(), "cancelar en marcha devuelve true");
    Test.assertEqual(script.state(), DemoScriptState.IDLE);
    Test.assertEqual(script.stepNumber(), 0);
    Test.assertEqual(script.scenario(), AccelScenario.NORMAL);
    Test.assertMessage(!script.update(30000, false), "cancelado no avanza");
    Test.assertMessage(!script.onAlertDismissed(30000), "ni con una respuesta");

    // Se puede volver a empezar desde el paso 1.
    script.start(40000);
    Test.assertEqual(script.stepNumber(), 1);
    Test.assertEqual(script.remainingMs(), 10000);
    Test.assertMessage(!script.isAlertPending(), "sin alerta pendiente del guion anterior");
    return true;
}

//! Recorrido completo con el detector, en el orden de GuardController.onBatch: cada
//! lote pasa por el detector y la confirmación del modelo (activada, como por defecto); un
//! evento confirmado abre la alerta (AlertController) y se avisa al
//! guion; la alerta escala con los tiempos del modo demo; "Estoy despierto" llega 3 s
//! después de abrirse, salvo en el último paso, que la deja sin respuesta. Comprueba
//! que cada alerta cae en su paso, con el motivo correcto, y que el guion termina con
//! la última alerta abierta en el nivel 3.
(:test)
function demoScriptRunsFullDemoWithDetector(logger as Logger) as Boolean {
    var rig = new DetectorRig(AccelScenario.NORMAL, 20261113, true);
    var alerts = new AlertController();
    alerts.setEscalationMs(AlertController.ESCALATION_DEMO_MS);
    var script = new DemoScript();
    script.start(rig.timeMs);
    var reasons = [] as Array<DrowsinessEvent.Id>;
    var steps = [] as Array<Number>;

    for (var i = 0; i < 180 && !script.isFinished(); i++) {
        rig.step();
        var event = rig.alertEvent;
        if (event != DrowsinessEvent.NONE && alerts.onEvent(event, rig.timeMs)) {
            reasons.add(event);
            steps.add(script.stepNumber());
            script.onAlertOpened();
        }
        if (alerts.update(rig.timeMs)) {
            script.onAlertLevel(alerts.level(), rig.timeMs);
        }
        if (script.update(rig.timeMs, alerts.isActive())) {
            rig.source.setScenario(script.scenario());
        }
        // El presentador responde a los 3 s, salvo en el paso sin respuesta.
        if (alerts.isActive() && script.isRunning() && !script.isEscalationStep()
                && rig.timeMs - alerts.startMs() >= 3000) {
            alerts.dismiss(rig.timeMs);
            if (script.onAlertDismissed(rig.timeMs)) {
                rig.source.setScenario(script.scenario());
            }
        }
    }
    logger.debug("guion completo en " + rig.timeMs + " ms; alertas en los pasos " + steps);

    Test.assertMessage(script.isFinished(), "el guion termina en menos de 3 minutos");
    Test.assertEqualMessage(reasons.size(), 3, "una alerta por paso de espera, ninguna más");
    Test.assertEqual(reasons[0], DrowsinessEvent.NOD);
    Test.assertEqual(steps[0], 3);
    Test.assertEqual(reasons[1], DrowsinessEvent.INACTIVITY);
    Test.assertEqual(steps[1], 5);
    Test.assertEqual(reasons[2], DrowsinessEvent.INACTIVITY);
    Test.assertEqual(steps[2], 6);
    Test.assertMessage(alerts.isActive(), "la última alerta sigue sin respuesta");
    Test.assertEqualMessage(alerts.level(), 3, "llegó al nivel 3");
    Test.assertEqualMessage(rig.timeMs - alerts.startMs(), 16000,
        "6 + 6 s hasta el nivel 3 y 4 s en él");
    return true;
}

//! Paso 6: espera su alerta, ignora un nivel 3 anterior a ella y termina 4 s después de
//! que su alerta llega al nivel 3, aunque siga abierta. Responder antes también termina.
(:test)
function demoScriptEscalationStepEndsAtLevelThree(logger as Logger) as Boolean {
    var script = demoScriptAtLastStep();
    Test.assertEqual(script.stepNumber(), 6);
    Test.assertMessage(script.isEscalationStep(), "último paso: sin respuesta");
    Test.assertMessage(script.isWaitingForAlert(), "espera su alerta");
    Test.assertEqual(script.scenario(), AccelScenario.INACTIVITY);
    Test.assertEqual(script.remainingMs(), 0);

    // Un nivel 3 antes de que se abra su alerta no cuenta.
    script.onAlertLevel(3, 41000);
    Test.assertMessage(!script.update(60000, true), "sin su alerta no termina");

    script.onAlertOpened();
    script.onAlertLevel(2, 66000);
    Test.assertMessage(!script.update(80000, true), "el nivel 2 no basta");
    script.onAlertLevel(3, 82000);
    Test.assertMessage(!script.update(85999, true), "aún no pasaron 4 s en el nivel 3");
    Test.assertMessage(script.update(86000, true), "4 s en el nivel 3: termina");
    Test.assertMessage(script.isFinished(), "guion completo");

    // Si el presentador responde antes de llegar al 3, también termina.
    var answered = demoScriptAtLastStep();
    answered.onAlertOpened();
    Test.assertMessage(answered.onAlertDismissed(55000), "respuesta en el paso 6");
    Test.assert(answered.isFinished());
    return true;
}

//! Guion recorrido hasta el comienzo del paso 6 (a los 40 s).
(:debug)
function demoScriptAtLastStep() as DemoScript {
    var script = new DemoScript();
    script.start(0);
    script.update(10000, false);
    script.update(20000, false);
    script.onAlertOpened();
    script.onAlertDismissed(25000);
    script.update(33000, false);
    script.onAlertOpened();
    script.onAlertDismissed(40000);
    return script;
}
