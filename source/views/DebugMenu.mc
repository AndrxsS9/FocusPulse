import Toybox.Lang;
import Toybox.WatchUi;

//! Menú de depuración (solo en compilaciones de depuración): se abre con pulsación
//! larga de UP en la pantalla principal.
//!
//! - Telemetría en vivo (TelemetryDebugView).
//! - Detector en vivo (DetectorDebugView): estado, probabilidades, línea base y eventos.
//! - Probar alerta nivel 1 / 2 / 3: abre la alerta a pantalla completa con vibración
//!   (el escalamiento automático entre niveles es de la fase siguiente).
//! - Fuente de datos: sensor real o simulada con un escenario, incluido el manual
//!   (X/Y/Z fijos), que el menú principal no ofrece. Cambia la misma configuración que
//!   el modo demo del menú principal (DemoConfig).
//! - Guía de estilo.
(:debug)
module DebugMenu {

    const ITEM_TELEMETRY = :telemetry;
    const ITEM_DETECTOR = :detector;
    const ITEM_SOURCE = :source;
    const ITEM_STYLE_GUIDE = :styleGuide;

    //! "Probar alerta nivel 1 / 2 / 3", en orden de nivel.
    const ALERT_ITEMS = [:alert1, :alert2, :alert3];

    //! Nivel de alerta (1–3) de un ítem del menú, o 0 si no es uno de prueba de alerta.
    function alertLevelOf(id as Object?) as Number {
        var items = ALERT_ITEMS as Array<Symbol>;
        for (var i = 0; i < items.size(); i++) {
            if (items[i] == id) {
                return i + 1;
            }
        }
        return 0;
    }

    function open(guard as GuardController) as Void {
        var menu = new WatchUi.Menu2({ :title => text(Rez.Strings.DebugMenuTitle) });
        menu.addItem(new WatchUi.MenuItem(text(Rez.Strings.DebugTelemetry), null,
            ITEM_TELEMETRY, {}));
        menu.addItem(new WatchUi.MenuItem(text(Rez.Strings.DebugDetector), null,
            ITEM_DETECTOR, {}));
        var alertFormat = text(Rez.Strings.DebugTestAlertFormat);
        var alertItems = ALERT_ITEMS as Array<Symbol>;
        for (var level = 1; level <= alertItems.size(); level++) {
            menu.addItem(new WatchUi.MenuItem(Lang.format(alertFormat, [level]), null,
                alertItems[level - 1], {}));
        }
        menu.addItem(new WatchUi.MenuItem(text(Rez.Strings.DebugSource),
            DebugSource.label(guard), ITEM_SOURCE, {}));
        menu.addItem(new WatchUi.MenuItem(text(Rez.Strings.DebugStyleGuide), null,
            ITEM_STYLE_GUIDE, {}));
        WatchUi.pushView(menu, new DebugMenuDelegate(guard), WatchUi.SLIDE_UP);
    }

    function text(id as ResourceId) as String {
        return WatchUi.loadResource(id) as String;
    }
}

//! Entrada del menú de depuración.
(:debug)
class DebugMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _guard as GuardController;

    function initialize(guard as GuardController) {
        Menu2InputDelegate.initialize();
        _guard = guard;
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        var alertLevel = DebugMenu.alertLevelOf(id);
        if (alertLevel > 0) {
            // Cierra el menú y abre la alerta sobre la esfera: al descartarla se vuelve
            // a la esfera, como con una alerta real. Motivo: cabeceo (el texto más largo).
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            _guard.triggerAlert(alertLevel, DrowsinessEvent.NOD);
        } else if (id == DebugMenu.ITEM_TELEMETRY) {
            WatchUi.pushView(new TelemetryDebugView(_guard), new TelemetryDebugDelegate(_guard),
                WatchUi.SLIDE_UP);
        } else if (id == DebugMenu.ITEM_DETECTOR) {
            WatchUi.pushView(new DetectorDebugView(_guard), new TelemetryDebugDelegate(_guard),
                WatchUi.SLIDE_UP);
        } else if (id == DebugMenu.ITEM_SOURCE) {
            DebugSource.openSelector(_guard, item);
        } else if (id == DebugMenu.ITEM_STYLE_GUIDE) {
            var view = new StyleGuideView();
            WatchUi.pushView(view, new StyleGuideDelegate(view), WatchUi.SLIDE_UP);
        }
    }
}

//! Selector de la fuente del acelerómetro (solo en depuración). Elegir un escenario
//! activa el modo demo y "Sensor real" lo desactiva; GuardController lo guarda en
//! Storage, así que la elección sigue al volver a abrir la app.
(:debug)
module DebugSource {

    //! Identificador del ítem "Sensor real" (los escenarios usan su AccelScenario.Id).
    const REAL = -1;

    //! Texto de la fuente actual: "Sensor real" o el nombre del escenario.
    function label(guard as GuardController) as String {
        return guard.isDemoMode() ? DemoText.scenarioName(guard.demoScenario())
            : DebugMenu.text(Rez.Strings.DebugSourceReal);
    }

    //! Abre la lista de fuentes; parentItem es el ítem del menú anterior, cuyo
    //! subtítulo se actualiza al elegir.
    function openSelector(guard as GuardController, parentItem as MenuItem) as Void {
        var menu = new WatchUi.Menu2({ :title => DebugMenu.text(Rez.Strings.DebugSource) });
        var simulated = DebugMenu.text(Rez.Strings.DebugSimulated);
        menu.addItem(new WatchUi.MenuItem(DebugMenu.text(Rez.Strings.DebugSourceReal), null, REAL, {}));
        for (var i = 0; i < AccelScenario.COUNT; i++) {
            menu.addItem(new WatchUi.MenuItem(DemoText.scenarioName(i as AccelScenario.Id), simulated,
                i, {}));
        }
        WatchUi.pushView(menu, new DebugSourceDelegate(guard, parentItem), WatchUi.SLIDE_LEFT);
    }

    //! Aplica una elección del selector (REAL o un AccelScenario.Id).
    function select(guard as GuardController, choice as Number) as Void {
        if (choice == REAL) {
            guard.setDemoMode(false);
            return;
        }
        guard.setDemoScenario(choice as AccelScenario.Id);
        guard.setDemoMode(true);
    }
}

//! Entrada del selector de fuente: elige y vuelve al menú de depuración.
(:debug)
class DebugSourceDelegate extends WatchUi.Menu2InputDelegate {

    private var _guard as GuardController;
    private var _parentItem as MenuItem;

    function initialize(guard as GuardController, parentItem as MenuItem) {
        Menu2InputDelegate.initialize();
        _guard = guard;
        _parentItem = parentItem;
    }

    function onSelect(item as MenuItem) as Void {
        DebugSource.select(_guard, item.getId() as Number);
        _parentItem.setSubLabel(DebugSource.label(_guard));
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
