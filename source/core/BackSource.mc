import Toybox.Lang;

//! Distingue el botón BACK del gesto "deslizar a la derecha" en la esfera.
//!
//! En el fr165 los dos llegan al delegado como el mismo comportamiento onBack
//! (simulator.json del SDK 9.3.0: `swipeRight` → `onBack`), pero el botón, además,
//! genera los eventos crudos de tecla KEY_ESC (onKeyPressed / onKeyReleased) y el gesto
//! no. Medido en el simulador con la traza de entrada (InputTrace):
//!
//!     botón BACK o Esc:   tecla pulsada ESC → onBack → onKey ESC → tecla soltada ESC
//!     deslizar derecha:   onBack → deslizamiento derecha
//!
//! Quien recibe las teclas llama a keyEvent(); en onBack, isFromKey() dice si hubo una
//! tecla BACK hace menos de KEY_WINDOW_MS. Se usa una ventana de tiempo, y no solo
//! "tecla pulsada ahora", para no depender de si un reloj concreto entrega onBack antes
//! o después de soltar el botón.
//!
//! Lógica pura: recibe el tiempo como parámetro (ms de System.getTimer()).
class BackSource {

    //! Tiempo máximo entre la tecla BACK y onBack para atribuirlo al botón (ms).
    static const KEY_WINDOW_MS = 1000;

    //! Momento de la última tecla BACK (pulsada o soltada); null: ninguna todavía.
    private var _lastKeyMs as Number? = null;

    function initialize() {
    }

    //! Registra un evento de la tecla BACK (KEY_ESC) en nowMs.
    function keyEvent(nowMs as Number) as Void {
        _lastKeyMs = nowMs;
    }

    //! true si el onBack que llega en nowMs viene del botón; false si es un gesto.
    function isFromKey(nowMs as Number) as Boolean {
        var last = _lastKeyMs;
        if (last == null) {
            return false;
        }
        var elapsed = nowMs - last;
        return elapsed >= 0 && elapsed <= KEY_WINDOW_MS;
    }
}
