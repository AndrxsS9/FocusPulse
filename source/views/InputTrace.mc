import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Traza de cada evento de entrada que llega a los delegados (solo en depuración).
//!
//! En la consola de `scripts\run.ps1` (sin -Release) cada evento sale como
//!
//!     ENTRADA esfera: tecla pulsada UP (13) a los 15230 ms
//!     ENTRADA esfera: comportamiento nextPage a los 15412 ms
//!     ENTRADA esfera: toque (195, 80) a los 18001 ms
//!
//! Sirve para saber qué genera de verdad cada botón dibujado, cada tecla del teclado del
//! PC y cada gesto del ratón en el simulador (docs/GUIA_DEMO.md, "Si los botones no
//! responden"). En release estas funciones están vacías: no escriben nada ni crean
//! textos.
module InputTrace {

    //! Comportamiento de BehaviorDelegate (onSelect, onMenu, onBack, nextPage…).
    (:debug)
    function behavior(view as String, name as String) as Void {
        write(view, "comportamiento " + name);
    }

    //! Evento de tecla: phase es "pulsada" (onKeyPressed), "soltada" (onKeyReleased) o
    //! "onKey".
    (:debug)
    function key(view as String, phase as String, keyEvent as WatchUi.KeyEvent) as Void {
        var code = keyEvent.getKey();
        write(view, "tecla " + phase + " " + keyName(code) + " (" + (code as Number) + ")");
    }

    //! Toque, pulsación larga (hold) o fin de una pulsación (release), con coordenadas.
    (:debug)
    function click(view as String, kind as String, clickEvent as WatchUi.ClickEvent) as Void {
        var point = clickEvent.getCoordinates();
        write(view, kind + " (" + point[0] + ", " + point[1] + ")");
    }

    //! Deslizamiento con su dirección.
    (:debug)
    function swipe(view as String, swipeEvent as WatchUi.SwipeEvent) as Void {
        write(view, "deslizamiento " + swipeName(swipeEvent.getDirection()));
    }

    (:debug)
    function write(view as String, text as String) as Void {
        System.println("ENTRADA " + view + ": " + text + " a los " + System.getTimer() + " ms");
    }

    (:debug)
    function keyName(code as WatchUi.Key) as String {
        switch (code) {
            case WatchUi.KEY_ENTER:
                return "ENTER";
            case WatchUi.KEY_ESC:
                return "ESC";
            case WatchUi.KEY_UP:
                return "UP";
            case WatchUi.KEY_DOWN:
                return "DOWN";
            case WatchUi.KEY_MENU:
                return "MENU";
            case WatchUi.KEY_LIGHT:
                return "LIGHT";
            case WatchUi.KEY_START:
                return "START";
            case WatchUi.KEY_LAP:
                return "LAP";
            default:
                return "otra";
        }
    }

    (:debug)
    function swipeName(direction as WatchUi.SwipeDirection) as String {
        switch (direction) {
            case WatchUi.SWIPE_LEFT:
                return "izquierda";
            case WatchUi.SWIPE_RIGHT:
                return "derecha";
            case WatchUi.SWIPE_UP:
                return "arriba";
            default:
                return "abajo";
        }
    }

    (:release)
    function behavior(view as String, name as String) as Void {
    }

    (:release)
    function key(view as String, phase as String, keyEvent as WatchUi.KeyEvent) as Void {
    }

    (:release)
    function click(view as String, kind as String, clickEvent as WatchUi.ClickEvent) as Void {
    }

    (:release)
    function swipe(view as String, swipeEvent as WatchUi.SwipeEvent) as Void {
    }
}
