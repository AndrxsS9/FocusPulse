import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! Menú de depuración (solo en compilaciones de depuración): se abre con pulsación
//! larga de UP en la pantalla principal.
//!
//! - Telemetría en vivo (TelemetryDebugView).
//! - Fuente de datos: sensor real o simulada con un escenario (selector temporal hasta
//!   que la fase del modo demo tenga su propia pantalla).
//! - Guía de estilo.
(:debug)
module DebugMenu {

    const ITEM_TELEMETRY = :telemetry;
    const ITEM_SOURCE = :source;
    const ITEM_STYLE_GUIDE = :styleGuide;

    function open(guard as GuardController) as Void {
        var menu = new WatchUi.Menu2({ :title => text(Rez.Strings.DebugMenuTitle) });
        menu.addItem(new WatchUi.MenuItem(text(Rez.Strings.DebugTelemetry), null,
            ITEM_TELEMETRY, {}));
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
        if (id == DebugMenu.ITEM_TELEMETRY) {
            WatchUi.pushView(new TelemetryDebugView(_guard), new TelemetryDebugDelegate(_guard),
                WatchUi.SLIDE_UP);
        } else if (id == DebugMenu.ITEM_SOURCE) {
            DebugSource.openSelector(_guard, item);
        } else if (id == DebugMenu.ITEM_STYLE_GUIDE) {
            var view = new StyleGuideView();
            WatchUi.pushView(view, new StyleGuideDelegate(view), WatchUi.SLIDE_UP);
        }
    }
}

//! Selector de la fuente del acelerómetro y su persistencia entre arranques.
//!
//! La elección se guarda en Application.Storage para que, en el simulador, el modo
//! demo siga activo al volver a abrir la app. Solo existe en depuración: en release la
//! guardia siempre usa el sensor real.
(:debug)
module DebugSource {

    //! Identificador del ítem "Sensor real" (los escenarios usan su AccelScenario.Id).
    const REAL = -1;

    const KEY_DEMO = "debugDemoSource";
    const KEY_SCENARIO = "debugDemoScenario";

    //! Texto de la fuente actual: "Sensor real" o el nombre del escenario.
    function label(guard as GuardController) as String {
        return guard.isDemoSource() ? scenarioLabel(guard.demoScenario()) : DebugMenu.text(Rez.Strings.DebugSourceReal);
    }

    function scenarioLabel(scenario as AccelScenario.Id) as String {
        switch (scenario) {
            case AccelScenario.TYPING:
                return DebugMenu.text(Rez.Strings.DemoActiveTyping);
            case AccelScenario.NOD:
                return DebugMenu.text(Rez.Strings.DemoSimulateNod);
            case AccelScenario.INACTIVITY:
                return DebugMenu.text(Rez.Strings.DemoProlongedInactivity);
            case AccelScenario.MANUAL:
                return DebugMenu.text(Rez.Strings.DemoManual);
            default:
                return DebugMenu.text(Rez.Strings.DemoNormalMovement);
        }
    }

    //! Abre la lista de fuentes; parentItem es el ítem del menú anterior, cuyo
    //! subtítulo se actualiza al elegir.
    function openSelector(guard as GuardController, parentItem as MenuItem) as Void {
        var menu = new WatchUi.Menu2({ :title => DebugMenu.text(Rez.Strings.DebugSource) });
        var simulated = DebugMenu.text(Rez.Strings.DebugSimulated);
        menu.addItem(new WatchUi.MenuItem(DebugMenu.text(Rez.Strings.DebugSourceReal), null, REAL, {}));
        for (var i = 0; i < AccelScenario.COUNT; i++) {
            menu.addItem(new WatchUi.MenuItem(scenarioLabel(i as AccelScenario.Id), simulated, i, {}));
        }
        WatchUi.pushView(menu, new DebugSourceDelegate(guard, parentItem), WatchUi.SLIDE_LEFT);
    }

    //! Aplica una elección del selector (REAL o un AccelScenario.Id) y la guarda.
    function select(guard as GuardController, choice as Number) as Void {
        var demo = choice != REAL;
        var scenario = (demo ? choice : guard.demoScenario()) as AccelScenario.Id;
        guard.selectSource(demo, scenario);
        try {
            Application.Storage.setValue(KEY_DEMO, demo);
            Application.Storage.setValue(KEY_SCENARIO, scenario as Number);
        } catch (e instanceof Lang.Exception) {
            // Sin almacenamiento la elección dura hasta cerrar la app.
        }
    }

    //! Recupera la elección guardada, si la hay.
    function restore(guard as GuardController) as Void {
        var demo = Application.Storage.getValue(KEY_DEMO);
        var scenario = Application.Storage.getValue(KEY_SCENARIO);
        if (demo instanceof Boolean && scenario instanceof Number
                && scenario >= 0 && scenario < AccelScenario.COUNT) {
            guard.selectSource(demo, scenario as AccelScenario.Id);
        }
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
