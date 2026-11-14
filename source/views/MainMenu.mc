import Toybox.Lang;
import Toybox.WatchUi;

//! Menú principal de la app (Menu2). Se abre con mantener UP (onMenu) en la esfera y
//! existe también en release.
//!
//! - Modo demo (ToggleMenuItem): activa la fuente simulada y los tiempos cortos; se
//!   guarda en Storage (GuardController.setDemoMode → DemoStore).
//! - Escenario (solo con el modo demo): submenú con los 4 escenarios de la demo.
//! - Guion automático (solo con el modo demo): lo inicia (y la guardia, si estaba en
//!   pausa) o, si ya corre, lo detiene. Cierra el menú en ambos casos.
//! - Probar alerta (solo con el modo demo): submenú nivel 1 / 2 / 3; cierra los menús y
//!   abre la alerta sobre la esfera, como una alerta real.
//! - Tomar descanso (solo con la guardia activa): cierra el menú y abre el descanso
//!   guiado, igual que tocar el aviso de fatiga de la esfera.
//! - Ajustes: sensibilidad, vibración, sonido, animaciones reducidas, confirmación por
//!   IA y grabar actividad (SettingsMenu); el subtítulo es la sensibilidad.
//! - Historial: las últimas 10 guardias (HistoryMenu); el subtítulo dice cuántas hay.
//! - Modelo IA: versión, tipo y métricas del clasificador (ModelInfoView); el subtítulo
//!   es la versión de los pesos.
//! - Acerca de: nombre, versión y qué hace la app.
//! - Depuración (solo en compilaciones de depuración): el menú de depuración de siempre.
//!
//! Al cambiar el modo demo el menú se reconstruye (switchToView) para mostrar u ocultar
//! los ítems que solo existen con el modo demo activo, con el foco en el interruptor.
module MainMenu {

    const ITEM_DEMO = :demo;
    const ITEM_SCENARIO = :scenario;
    const ITEM_SCRIPT = :script;
    const ITEM_TEST_ALERT = :testAlert;
    const ITEM_BREAK = :takeBreak;
    const ITEM_SETTINGS = :settings;
    const ITEM_HISTORY = :history;
    const ITEM_MODEL = :model;
    const ITEM_ABOUT = :about;
    const ITEM_DEBUG = :debug;

    //! Abre el menú sobre la esfera.
    function open(guard as GuardController) as Void {
        WatchUi.pushView(build(guard, null), new MainMenuDelegate(guard), WatchUi.SLIDE_UP);
    }

    //! Sustituye el menú abierto por uno nuevo con los ítems del modo actual.
    function rebuild(guard as GuardController, focus as Symbol) as Void {
        WatchUi.switchToView(build(guard, focus), new MainMenuDelegate(guard),
            WatchUi.SLIDE_IMMEDIATE);
    }

    //! Menú con los ítems que tocan según el modo demo; focus es el ítem que queda
    //! seleccionado (null: el primero).
    function build(guard as GuardController, focus as Symbol?) as WatchUi.Menu2 {
        var demo = guard.isDemoMode();
        var items = [] as Array<WatchUi.MenuItem>;
        items.add(new WatchUi.ToggleMenuItem(DemoText.text(Rez.Strings.DemoTitle),
            {
                :enabled => DemoText.text(Rez.Strings.MenuDemoOn),
                :disabled => DemoText.text(Rez.Strings.MenuDemoOff)
            },
            ITEM_DEMO, demo, {}));
        if (demo) {
            items.add(new WatchUi.MenuItem(DemoText.text(Rez.Strings.MenuScenario),
                DemoText.scenarioName(guard.demoScenario()), ITEM_SCENARIO, {}));
            items.add(new WatchUi.MenuItem(DemoText.text(Rez.Strings.MenuScript),
                scriptSubLabel(guard.demoScript()), ITEM_SCRIPT, {}));
            items.add(new WatchUi.MenuItem(DemoText.text(Rez.Strings.MenuTestAlert), null,
                ITEM_TEST_ALERT, {}));
        }
        if (guard.canTakeBreak()) {
            items.add(new WatchUi.MenuItem(DemoText.text(Rez.Strings.MenuTakeBreak), null,
                ITEM_BREAK, {}));
        }
        items.add(new WatchUi.MenuItem(DemoText.text(Rez.Strings.SettingsTitle),
            settingsSubLabel(guard), ITEM_SETTINGS, {}));
        items.add(new WatchUi.MenuItem(DemoText.text(Rez.Strings.MenuHistory),
            SummaryText.historyCount(guard.history().size()), ITEM_HISTORY, {}));
        items.add(new WatchUi.MenuItem(DemoText.text(Rez.Strings.MenuModel), ClassifierWeights.VERSION,
            ITEM_MODEL, {}));
        items.add(new WatchUi.MenuItem(DemoText.text(Rez.Strings.MenuAbout), null, ITEM_ABOUT, {}));
        addDebugItem(items);

        var focusIndex = 0;
        for (var i = 0; i < items.size(); i++) {
            if (items[i].getId() == focus) {
                focusIndex = i;
            }
        }
        var menu = new WatchUi.Menu2({
            :title => DemoText.text(Rez.Strings.AppName),
            :focus => focusIndex
        });
        for (var i = 0; i < items.size(); i++) {
            menu.addItem(items[i]);
        }
        return menu;
    }

    //! Subtítulo de Ajustes: "Sensibilidad: Media".
    function settingsSubLabel(guard as GuardController) as String {
        return Lang.format(DemoText.text(Rez.Strings.SettingsSubFormat),
            [DemoText.text(Rez.Strings.SettingSensitivity),
                SettingsMenu.sensitivityName(guard.settings().sensitivity)]);
    }

    //! "Iniciar", o "Detener · paso 2/5" con el guion en marcha.
    function scriptSubLabel(script as DemoScript) as String {
        if (!script.isRunning()) {
            return DemoText.text(Rez.Strings.MenuScriptStart);
        }
        return Lang.format(DemoText.text(Rez.Strings.MenuScriptStopFormat),
            [script.stepNumber(), script.stepCount()]);
    }

    //! En depuración, el último ítem abre el menú de depuración.
    (:debug)
    function addDebugItem(items as Array<WatchUi.MenuItem>) as Void {
        items.add(new WatchUi.MenuItem(DemoText.text(Rez.Strings.DebugMenuTitle), null,
            ITEM_DEBUG, {}));
    }

    (:release)
    function addDebugItem(items as Array<WatchUi.MenuItem>) as Void {
    }
}

//! Submenú "Escenario": los escenarios de la demo, con el foco en el actual.
module ScenarioMenu {

    function open(guard as GuardController, parentItem as WatchUi.MenuItem) as Void {
        var scenarios = DemoConfig.SCENARIOS as Array<AccelScenario.Id>;
        var focus = scenarios.indexOf(guard.demoScenario());
        var menu = new WatchUi.Menu2({
            :title => DemoText.text(Rez.Strings.MenuScenario),
            :focus => focus < 0 ? 0 : focus
        });
        for (var i = 0; i < scenarios.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(DemoText.scenarioName(scenarios[i]), null,
                scenarios[i] as Number, {}));
        }
        WatchUi.pushView(menu, new ScenarioMenuDelegate(guard, parentItem), WatchUi.SLIDE_LEFT);
    }
}

//! Elige el escenario, actualiza el subtítulo del ítem del menú principal y vuelve.
class ScenarioMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _guard as GuardController;
    private var _parentItem as WatchUi.MenuItem;

    function initialize(guard as GuardController, parentItem as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _guard = guard;
        _parentItem = parentItem;
    }

    function onSelect(item as MenuItem) as Void {
        _guard.setDemoScenario(item.getId() as AccelScenario.Id);
        _parentItem.setSubLabel(DemoText.scenarioName(_guard.demoScenario()));
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

//! Submenú "Probar alerta": nivel 1, 2 y 3 con su tipo de vibración.
module TestAlertMenu {

    const LEVEL_NAMES = [Rez.Strings.AlertLevel1, Rez.Strings.AlertLevel2, Rez.Strings.AlertLevel3];
    const VIBRATION_NAMES = [Rez.Strings.AlertVibrationSoft, Rez.Strings.AlertVibrationMedium,
        Rez.Strings.AlertVibrationMax];

    function open(guard as GuardController) as Void {
        var menu = new WatchUi.Menu2({ :title => DemoText.text(Rez.Strings.MenuTestAlert) });
        var levels = LEVEL_NAMES as Array<ResourceId>;
        var vibrations = VIBRATION_NAMES as Array<ResourceId>;
        for (var i = 0; i < levels.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(DemoText.text(levels[i]),
                DemoText.text(vibrations[i]), i + 1, {}));
        }
        WatchUi.pushView(menu, new TestAlertMenuDelegate(guard), WatchUi.SLIDE_LEFT);
    }
}

//! Cierra el submenú y el menú principal y abre la alerta del nivel elegido sobre la
//! esfera: al responder "Estoy despierto" se vuelve a la esfera, como con una alerta
//! real. El motivo es el cabeceo (el texto más largo).
class TestAlertMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _guard as GuardController;

    function initialize(guard as GuardController) {
        Menu2InputDelegate.initialize();
        _guard = guard;
    }

    function onSelect(item as MenuItem) as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        _guard.triggerAlert(item.getId() as Number, DrowsinessEvent.NOD);
    }
}

//! Entrada del menú principal.
class MainMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _guard as GuardController;

    function initialize(guard as GuardController) {
        Menu2InputDelegate.initialize();
        _guard = guard;
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id == MainMenu.ITEM_DEMO) {
            // El ToggleMenuItem ya cambió de estado al tocarlo.
            _guard.setDemoMode((item as WatchUi.ToggleMenuItem).isEnabled());
            MainMenu.rebuild(_guard, MainMenu.ITEM_DEMO);
        } else if (id == MainMenu.ITEM_SCENARIO) {
            ScenarioMenu.open(_guard, item);
        } else if (id == MainMenu.ITEM_SCRIPT) {
            // Vuelve a la esfera: el guion se sigue allí.
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            if (_guard.demoScript().isRunning()) {
                _guard.cancelDemoScript();
            } else {
                _guard.startDemoScript();
            }
        } else if (id == MainMenu.ITEM_TEST_ALERT) {
            TestAlertMenu.open(_guard);
        } else if (id == MainMenu.ITEM_BREAK) {
            // El descanso se abre sobre la esfera, no sobre el menú.
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            _guard.startBreak();
        } else if (id == MainMenu.ITEM_SETTINGS) {
            SettingsMenu.open(_guard);
        } else if (id == MainMenu.ITEM_HISTORY) {
            HistoryMenu.open(_guard, item);
        } else if (id == MainMenu.ITEM_MODEL) {
            WatchUi.pushView(new ModelInfoView(), new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == MainMenu.ITEM_ABOUT) {
            WatchUi.pushView(new AboutView(), new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_LEFT);
        } else {
            openDebug(id);
        }
    }

    (:debug)
    private function openDebug(id as Object?) as Void {
        if (id == MainMenu.ITEM_DEBUG) {
            DebugMenu.open(_guard);
        }
    }

    (:release)
    private function openDebug(id as Object?) as Void {
    }
}
