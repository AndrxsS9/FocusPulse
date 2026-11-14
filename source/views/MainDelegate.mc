import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Entrada de la pantalla principal.
//!
//! - Botón START/STOP (onKey, KEY_ENTER): inicia o pausa la guardia.
//! - Toque en el botón grande (su área táctil, RoundLayout.buttonTouchRect): lo mismo
//!   que START/STOP. Un toque fuera del botón no hace nada.
//! - BACK: sale de la app; si la guardia está activa, antes la detiene y guarda
//!   la actividad (ver onBack).
//! - Menú (pulsación larga de UP): menú principal (MainMenu), también en release.
//!
//! Verificado en el simulador del fr165: START y cualquier toque disparan primero el
//! comportamiento onSelect; solo si devuelve false llegan onKey (KEY_ENTER) u onTap
//! (con coordenadas). Por eso onSelect no hace nada.
class MainDelegate extends WatchUi.BehaviorDelegate {

    private var _guard as GuardController;

    //! Geometría de la pantalla, la misma que usa MainView para dibujar el botón.
    private var _layout as RoundLayout;

    function initialize(guard as GuardController) {
        BehaviorDelegate.initialize();
        _guard = guard;
        var settings = System.getDeviceSettings();
        _layout = new RoundLayout(settings.screenWidth, settings.screenHeight);
    }

    //! Comportamiento "select": en el fr165 llega tanto con START como con un toque en
    //! cualquier parte de la pantalla, y BehaviorDelegate lo despacha antes que el
    //! evento crudo. Devuelve false para que el sistema siga con onKey (START) u onTap
    //! (toque con coordenadas), que deciden por separado.
    function onSelect() as Boolean {
        return false;
    }

    //! Botón START/STOP (KEY_ENTER): inicia o pausa la guardia.
    function onKey(keyEvent as KeyEvent) as Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_ENTER) {
            _guard.toggle();
            return true;
        }
        return false;
    }

    //! Toque en la pantalla: solo actúa dentro del área táctil del botón grande. Se
    //! consume siempre, también fuera del botón, para que un toque en cualquier parte
    //! no tenga otro efecto.
    function onTap(clickEvent as ClickEvent) as Boolean {
        var point = clickEvent.getCoordinates();
        if (_layout.hitsButton(point[0], point[1])) {
            _guard.toggle();
        }
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

    //! Pulsación larga del botón de menú (UP en el fr165): abre el menú principal
    //! (modo demo, acerca de; en depuración, también el menú de depuración).
    function onMenu() as Boolean {
        MainMenu.open(_guard);
        return true;
    }
}
