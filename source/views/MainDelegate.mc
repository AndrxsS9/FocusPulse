import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Entrada de la pantalla principal.
//!
//! - Botón START/STOP (onKey, KEY_ENTER): inicia o pausa la guardia. Como el toque en
//!   el botón, le da el foco (ButtonFocus) para que la esfera dibuje su borde cian.
//! - Toque en el botón grande (su área táctil, RoundLayout.buttonTouchRect): lo mismo
//!   que START/STOP. Con la fatiga en Alto, un toque en el aviso "Micro-sueños
//!   repetidos" abre el descanso guiado. Un toque en otra parte no hace nada.
//! - BACK: sale de la app; si la guardia está activa, antes la detiene y guarda
//!   la actividad (ver onBack).
//! - Menú (pulsación larga de UP): menú principal (MainMenu), también en release.
//! - UP y DOWN: enfocan el botón grande (borde cian durante 1,5 s, ButtonFocus).
//! - DOWN, con el modo demo activo y la guardia en marcha: además, siguiente escenario,
//!   con un aviso breve en la esfera. En otro caso DOWN no se consume.
//!
//! Verificado en el simulador del fr165: START y cualquier toque disparan primero el
//! comportamiento onSelect; solo si devuelve false llegan onKey (KEY_ENTER) u onTap
//! (con coordenadas). Por eso onSelect no hace nada.
class MainDelegate extends WatchUi.BehaviorDelegate {

    private var _guard as GuardController;

    //! Foco del botón grande: START y un toque en él lo marcan (borde cian en la esfera).
    private var _focus as ButtonFocus;

    //! Geometría de la pantalla, la misma que usa MainView para dibujar el botón.
    private var _layout as RoundLayout;

    function initialize(guard as GuardController, focus as ButtonFocus) {
        BehaviorDelegate.initialize();
        _guard = guard;
        _focus = focus;
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
            _focus.press(System.getTimer());
            _guard.toggle();
            return true;
        }
        return false;
    }

    //! Toque en la pantalla: el botón grande (su área táctil) inicia o pausa la
    //! guardia; el aviso de fatiga, si se ve, abre el descanso guiado. Se consume
    //! siempre, también fuera de ambos, para que un toque en cualquier parte no tenga
    //! otro efecto.
    function onTap(clickEvent as ClickEvent) as Boolean {
        var point = clickEvent.getCoordinates();
        if (_layout.hitsButton(point[0], point[1])) {
            _focus.press(System.getTimer());
            _guard.toggle();
        } else if (_guard.showsFatigueWarning() && _layout.hitsFatigueBanner(point[0], point[1])) {
            _guard.startBreak();
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

    //! DOWN (nextPage): enfoca el botón grande y, con el modo demo durante la guardia,
    //! pasa al siguiente escenario.
    function onNextPage() as Boolean {
        _focus.focus(System.getTimer());
        WatchUi.requestUpdate();
        return _guard.cycleDemoScenario();
    }

    //! UP (previousPage): enfoca el botón grande (ButtonFocus), el único control de la
    //! esfera.
    function onPreviousPage() as Boolean {
        _focus.focus(System.getTimer());
        WatchUi.requestUpdate();
        return true;
    }

    //! Pulsación larga del botón de menú (UP en el fr165): abre el menú principal
    //! (modo demo, acerca de; en depuración, también el menú de depuración).
    function onMenu() as Boolean {
        MainMenu.open(_guard);
        return true;
    }
}
