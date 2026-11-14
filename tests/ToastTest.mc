import Toybox.Lang;
import Toybox.Test;

//! Pruebas del aviso breve (Toast) y del atajo DOWN del modo demo (DemoConfig).

(:test)
function toastIsVisibleForItsDuration(logger as Logger) as Boolean {
    var toast = new Toast();
    Test.assertMessage(!toast.isVisible(0), "sin aviso al empezar");

    toast.show(ToastKind.SCENARIO, AccelScenario.TYPING as Number, 10000);
    Test.assertMessage(!toast.isVisible(9999), "no se ve antes de mostrarlo");
    Test.assertMessage(toast.isVisible(10000), "se ve al mostrarlo");
    Test.assertMessage(toast.isVisible(10000 + Toast.DURATION_MS - 1), "se ve hasta el final");
    Test.assertMessage(!toast.isVisible(10000 + Toast.DURATION_MS), "desaparece a los 1,5 s");
    Test.assertEqual(Toast.DURATION_MS, 1500);
    Test.assertEqual(toast.kind(), ToastKind.SCENARIO);
    Test.assertEqual(toast.value(), AccelScenario.TYPING as Number);
    return true;
}

(:test)
function toastReplacedRestartsTimer(logger as Logger) as Boolean {
    var toast = new Toast();
    toast.show(ToastKind.SCENARIO, AccelScenario.TYPING as Number, 0);
    toast.show(ToastKind.SCENARIO, AccelScenario.NOD as Number, 1000);
    Test.assertEqual(toast.value(), AccelScenario.NOD as Number);
    Test.assertMessage(toast.isVisible(2000), "el nuevo cuenta desde su propio inicio");
    Test.assertMessage(!toast.isVisible(2500), "y dura lo mismo");

    toast.show(ToastKind.SCENARIO, AccelScenario.NOD as Number, 3000);
    toast.hide();
    Test.assertMessage(!toast.isVisible(3100), "hide() lo quita antes de tiempo");
    return true;
}

(:test)
function downButtonOnlyCyclesInDemoGuard(logger as Logger) as Boolean {
    var config = new DemoConfig();
    Test.assertMessage(!config.handlesDownButton(true), "sin modo demo, DOWN no cambia nada");
    config.setEnabled(true);
    Test.assertMessage(!config.handlesDownButton(false), "guardia en pausa: DOWN no cambia nada");
    Test.assertMessage(config.handlesDownButton(true), "modo demo y guardia activa: cambia");
    return true;
}

//! Cuatro pulsaciones de DOWN con 1 s entre ellas: recorren los cuatro escenarios y
//! cada aviso muestra el escenario nuevo durante 1,5 s, reemplazando al anterior.
(:test)
function downButtonCyclesScenariosWithToast(logger as Logger) as Boolean {
    var config = new DemoConfig();
    config.setEnabled(true);
    var toast = new Toast();
    var expected = [AccelScenario.TYPING, AccelScenario.NOD, AccelScenario.INACTIVITY,
        AccelScenario.NORMAL] as Array<AccelScenario.Id>;
    for (var i = 0; i < expected.size(); i++) {
        var nowMs = 1000 * (i + 1);
        Test.assertMessage(config.handlesDownButton(true), "DOWN atendido");
        toast.show(ToastKind.SCENARIO, config.nextScenario() as Number, nowMs);
        Test.assertEqual(config.scenario(), expected[i]);
        Test.assertEqual(toast.value(), expected[i] as Number);
        Test.assertMessage(toast.isVisible(nowMs + 999), "aviso visible hasta la siguiente pulsación");
    }
    Test.assertMessage(!toast.isVisible(4000 + Toast.DURATION_MS), "el último aviso se apaga solo");
    return true;
}
