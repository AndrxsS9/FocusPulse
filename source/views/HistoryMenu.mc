import Toybox.Lang;
import Toybox.WatchUi;

//! Submenú "Historial" del menú principal (Menu2): las últimas 10 guardias, de la más
//! reciente a la más antigua.
//!
//! - Cada guardia: "14 nov · 10:32" con "1 min 32 s · 3 episodios" debajo. Al elegirla
//!   se abre su detalle: la vista del resumen (SummaryView) con la fecha como título.
//! - Al final, "Borrar historial": pide confirmación (WatchUi.Confirmation) y, si se
//!   acepta, vacía el historial y deja la lista con "Aún no hay guardias".
//! - Sin guardias, un solo ítem "Aún no hay guardias" que no hace nada.
module HistoryMenu {

    const ITEM_EMPTY = :historyEmpty;
    const ITEM_CLEAR = :historyClear;

    //! parentItem: el ítem "Historial" del menú principal, para actualizar su subtítulo.
    function open(guard as GuardController, parentItem as WatchUi.MenuItem) as Void {
        var menu = new WatchUi.Menu2({ :title => DemoText.text(Rez.Strings.MenuHistory) });
        fill(menu, guard.history());
        WatchUi.pushView(menu, new HistoryMenuDelegate(guard, menu, parentItem),
            WatchUi.SLIDE_LEFT);
    }

    //! Ítems de la lista; el id de cada guardia es su índice en el historial.
    function fill(menu as WatchUi.Menu2, history as SessionHistory) as Void {
        if (history.isEmpty()) {
            menu.addItem(new WatchUi.MenuItem(DemoText.text(Rez.Strings.HistoryEmpty), null,
                ITEM_EMPTY, {}));
            return;
        }
        for (var i = 0; i < history.size(); i++) {
            var summary = history.get(i);
            menu.addItem(new WatchUi.MenuItem(SummaryText.date(summary.dateSec),
                SummaryText.historyLine(summary), i, {}));
        }
        menu.addItem(new WatchUi.MenuItem(DemoText.text(Rez.Strings.HistoryClear), null,
            ITEM_CLEAR, {}));
    }

    //! Deja la lista vacía tras borrar el historial.
    function clearItems(menu as WatchUi.Menu2) as Void {
        while (menu.getItem(0) != null) {
            menu.deleteItem(0);
        }
        menu.addItem(new WatchUi.MenuItem(DemoText.text(Rez.Strings.HistoryEmpty), null,
            ITEM_EMPTY, {}));
    }
}

//! Entrada de la lista del historial.
class HistoryMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _guard as GuardController;
    private var _menu as WatchUi.Menu2;
    private var _parentItem as WatchUi.MenuItem;

    function initialize(guard as GuardController, menu as WatchUi.Menu2,
            parentItem as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _guard = guard;
        _menu = menu;
        _parentItem = parentItem;
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id == HistoryMenu.ITEM_CLEAR) {
            WatchUi.pushView(
                new WatchUi.Confirmation(DemoText.text(Rez.Strings.HistoryClearConfirm)),
                new HistoryClearDelegate(_guard, _menu, _parentItem), WatchUi.SLIDE_IMMEDIATE);
            return;
        }
        if (!(id instanceof Number)) {
            // "Aún no hay guardias".
            return;
        }
        var history = _guard.history();
        var index = id as Number;
        if (index < history.size()) {
            var summary = history.get(index);
            WatchUi.pushView(new SummaryView(summary, SummaryText.date(summary.dateSec)),
                new SummaryDelegate(), WatchUi.SLIDE_LEFT);
        }
    }
}

//! Respuesta a "¿Borrar el historial?". La confirmación se cierra sola después; con "sí"
//! se vacía el historial y la lista que queda debajo pasa a "Aún no hay guardias".
class HistoryClearDelegate extends WatchUi.ConfirmationDelegate {

    private var _guard as GuardController;
    private var _menu as WatchUi.Menu2;
    private var _parentItem as WatchUi.MenuItem;

    function initialize(guard as GuardController, menu as WatchUi.Menu2,
            parentItem as WatchUi.MenuItem) {
        ConfirmationDelegate.initialize();
        _guard = guard;
        _menu = menu;
        _parentItem = parentItem;
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            _guard.clearHistory();
            HistoryMenu.clearItems(_menu);
            _parentItem.setSubLabel(SummaryText.historyCount(0));
        }
        return true;
    }
}
