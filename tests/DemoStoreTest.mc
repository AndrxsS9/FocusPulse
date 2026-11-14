import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

//! Pruebas de DemoStore con el Application.Storage real del simulador. Deja el valor
//! guardado como estaba antes de la prueba.

(:test)
function demoStoreSavesAndLoadsConfig(logger as Logger) as Boolean {
    var previous = Application.Storage.getValue(DemoStore.KEY);
    try {
        var config = new DemoConfig();
        config.setEnabled(true);
        config.setScenario(AccelScenario.NOD);
        DemoStore.save(config);
        var loaded = DemoStore.load();
        Test.assertMessage(loaded.isEnabled(), "modo demo guardado");
        Test.assertEqual(loaded.scenario(), AccelScenario.NOD);

        Application.Storage.deleteValue(DemoStore.KEY);
        var empty = DemoStore.load();
        Test.assertMessage(!empty.isEnabled(), "sin datos guardados: sin modo demo");
        Test.assertEqual(empty.scenario(), AccelScenario.NORMAL);

        Application.Storage.setValue(DemoStore.KEY, "corrupto");
        Test.assertMessage(!DemoStore.load().isEnabled(), "dato corrupto: valores por defecto");
    } finally {
        if (previous == null) {
            Application.Storage.deleteValue(DemoStore.KEY);
        } else {
            Application.Storage.setValue(DemoStore.KEY, previous as Application.Storage.ValueType);
        }
    }
    return true;
}
