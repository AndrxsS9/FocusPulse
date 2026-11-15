import Toybox.Lang;

//! Foco del botón grande de la esfera ("Iniciar guardia" / "Pausar guardia").
//!
//! El botón grande es el único control de la esfera. Se enfoca de dos maneras:
//! - al pulsarlo (START o un toque sobre él): así se ve qué hizo la pulsación aunque el
//!   texto cambie;
//! - con las teclas de navegación UP y DOWN, que en un reloj de botones hacen el papel
//!   del foco de teclado.
//! En ambos casos queda enfocado durante HIGHLIGHT_MS, y la vista dibuja entonces el
//! borde cian del diseño web (guardia-activa-1.png).
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

    //! Se pulsó una tecla de navegación (UP o DOWN) en nowMs: el foco va al botón.
    function focus(nowMs as Number) as Void {
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
