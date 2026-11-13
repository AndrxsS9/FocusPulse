import Toybox.Lang;
import Toybox.WatchUi;

//! Entrada de la pantalla principal.
//!
//! - Botón START/STOP (comportamiento "select"): activa o pausa el monitoreo.
//! - Toque en la pantalla: hace lo mismo que START/STOP.
//! - BACK conserva el comportamiento por defecto (salir de la app).
//! - Menú (pulsación larga de UP), solo en depuración: guía de estilo.
class MainDelegate extends WatchUi.BehaviorDelegate {

    private var _state as MonitorState;

    function initialize(state as MonitorState) {
        BehaviorDelegate.initialize();
        _state = state;
    }

    //! Botón START/STOP.
    function onSelect() as Boolean {
        return toggleMonitoring();
    }

    //! Toque en la pantalla. Se consume aquí para que no se dispare
    //! también onSelect en dispositivos que mapean el toque a "select".
    function onTap(clickEvent as ClickEvent) as Boolean {
        return toggleMonitoring();
    }

    //! Pulsación larga del botón de menú (UP en el fr165): abre la guía de
    //! estilo oculta. Solo existe en compilaciones de depuración; en release
    //! (scripts/export.ps1, -r) la anotación (:debug) la excluye y el botón
    //! conserva su comportamiento por defecto.
    (:debug)
    function onMenu() as Boolean {
        var view = new StyleGuideView();
        WatchUi.pushView(view, new StyleGuideDelegate(view), WatchUi.SLIDE_UP);
        return true;
    }

    private function toggleMonitoring() as Boolean {
        _state.toggle();
        WatchUi.requestUpdate();
        return true;
    }
}
