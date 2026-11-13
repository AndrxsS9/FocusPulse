import Toybox.Lang;
import Toybox.WatchUi;

//! Entrada de la pantalla principal.
//!
//! - Botón START/STOP (comportamiento "select"): inicia o pausa la guardia.
//! - Toque en la pantalla: hace lo mismo que START/STOP.
//! - BACK: sale de la app; si la guardia está activa, antes la detiene y guarda
//!   la actividad (ver onBack).
//! - Menú (pulsación larga de UP), solo en depuración: menú de depuración.
class MainDelegate extends WatchUi.BehaviorDelegate {

    private var _guard as GuardController;

    function initialize(guard as GuardController) {
        BehaviorDelegate.initialize();
        _guard = guard;
    }

    //! Botón START/STOP.
    function onSelect() as Boolean {
        _guard.toggle();
        return true;
    }

    //! Toque en la pantalla. Se consume aquí para que no se dispare
    //! también onSelect en dispositivos que mapean el toque a "select".
    function onTap(clickEvent as ClickEvent) as Boolean {
        _guard.toggle();
        return true;
    }

    //! BACK: si la guardia está activa, la detiene y guarda la actividad antes de que
    //! la app empiece a cerrarse. Devuelve false para que BACK siga saliendo de la app.
    function onBack() as Boolean {
        if (_guard.isActive()) {
            _guard.shutdown();
        }
        return false;
    }

    //! Pulsación larga del botón de menú (UP en el fr165): abre el menú de
    //! depuración (fuente de datos, guía de estilo). Solo existe en compilaciones de
    //! depuración; en release (scripts/export.ps1, -r) la anotación (:debug) la
    //! excluye y el botón conserva su comportamiento por defecto.
    (:debug)
    function onMenu() as Boolean {
        DebugMenu.open(_guard);
        return true;
    }
}
