import Toybox.Lang;

//! Foco del botón grande de la esfera ("Iniciar guardia" / "Pausar guardia").
//!
//! La esfera no tiene foco de teclado propio: el botón grande es su único control y
//! START o un toque sobre él lo "pulsan". Tras cada pulsación el botón se considera
//! enfocado durante HIGHLIGHT_MS, y la vista dibuja entonces el borde cian del diseño
//! web (guardia-activa-1.png). Así se ve qué hizo la pulsación aunque el texto cambie.
//!
//! Lógica pura: el tiempo entra como parámetro (ms de System.getTimer()).
class ButtonFocus {

    //! Tiempo que el botón se ve enfocado tras una pulsación (ms).
    static const HIGHLIGHT_MS = 1500;

    //! Momento de la última pulsación (null: nunca se pulsó o se quitó el foco).
    private var _pressedAt as Number? = null;

    function initialize() {
    }

    //! Se pulsó el botón (START o un toque en su área táctil) en nowMs.
    function press(nowMs as Number) as Void {
        _pressedAt = nowMs;
    }

    //! Quita el foco (p. ej. al salir de la esfera).
    function clear() as Void {
        _pressedAt = null;
    }

    //! true si el botón se ve enfocado en nowMs: desde la pulsación y durante
    //! HIGHLIGHT_MS. Resta con desbordamiento como System.getTimer().
    function isHighlighted(nowMs as Number) as Boolean {
        var pressedAt = _pressedAt;
        if (pressedAt == null) {
            return false;
        }
        var elapsed = nowMs - pressedAt;
        return elapsed >= 0 && elapsed < HIGHLIGHT_MS;
    }
}
