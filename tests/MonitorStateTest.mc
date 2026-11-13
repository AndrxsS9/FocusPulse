import Toybox.Lang;
import Toybox.Test;

//! Pruebas unitarias de MonitorState (source/core).
//!
//! Solo se compilan con la opción -t (scripts/test.ps1). Cada prueba devuelve
//! true si pasa; los Test.assert* lanzan una excepción si fallan.

(:test)
function monitorStateStartsPaused(logger as Logger) as Boolean {
    var state = new MonitorState();
    Test.assertMessage(!state.isActive(), "La sesión debe iniciar en pausa");
    return true;
}

(:test)
function monitorStateToggleAlternates(logger as Logger) as Boolean {
    var state = new MonitorState();

    Test.assertEqualMessage(state.toggle(), true, "El primer toggle debe activar");
    Test.assert(state.isActive());

    Test.assertEqualMessage(state.toggle(), false, "El segundo toggle debe pausar");
    Test.assert(!state.isActive());

    return true;
}

(:test)
function monitorStateStartAndPauseAreIdempotent(logger as Logger) as Boolean {
    var state = new MonitorState();

    state.start();
    state.start();
    Test.assert(state.isActive());

    state.pause();
    state.pause();
    Test.assert(!state.isActive());

    logger.debug("start()/pause() repetidos no cambian el resultado");
    return true;
}
