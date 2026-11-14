import Toybox.Lang;
import Toybox.WatchUi;

//! Menú principal de la app (Menu2). Se abre con mantener UP (onMenu) en la esfera y
//! existe también en release.
//!
//! - Modo demo (ToggleMenuItem): activa la fuente simulada y los tiempos cortos; se
//!   guarda en Storage (GuardController.setDemoMode → DemoStore).
//! - Acerca de: nombre, versión y qué hace la app.
//! - Depuración (solo en compilaciones de depuración): el menú de depuración de siempre.
//!
//! Al cambiar el modo demo el menú se reconstruye (switchToView) para mostrar u ocultar
//! los ítems que solo existen con el modo demo activo, con el foco en el interruptor.
module MainMenu {

    const ITEM_DEMO = :demo;
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
