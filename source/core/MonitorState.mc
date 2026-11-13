import Toybox.Lang;

//! Estado de la sesión de monitoreo (activo / en pausa).
//!
//! Lógica pura: no depende de WatchUi ni de Graphics, para poder probarse
//! con Toybox.Test y reutilizarse desde el modo demo.
class MonitorState {

    private var _active as Boolean = false;

    //! La sesión siempre arranca en pausa.
    function initialize() {
    }

    //! true si el monitoreo está activo.
    function isActive() as Boolean {
        return _active;
    }

    //! Activa el monitoreo.
    function start() as Void {
        _active = true;
    }

    //! Pone el monitoreo en pausa.
    function pause() as Void {
        _active = false;
    }

    //! Alterna entre activo y en pausa y devuelve el nuevo estado.
    function toggle() as Boolean {
        _active = !_active;
        return _active;
    }
}
