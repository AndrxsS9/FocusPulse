import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Entrada de la pantalla principal. Todo se puede hacer con botones **o** solo con
//! toques (en el simulador los botones dibujados pueden no responder; ver
//! docs/GUIA_DEMO.md, "Si los botones no responden").
//!
//! | Acción | Botón | Toque |
//! |---|---|---|
//! | Iniciar / pausar la guardia | START | tocar el botón grande |
//! | Menú principal | mantener UP | tocar la batería o la hora, o mantener la pantalla |
//! | Escenario siguiente (demo) | DOWN, con la guardia en marcha | deslizar a la izquierda |
//! | Escenario anterior (demo) | — | deslizar a la derecha |
//! | Descanso (fatiga en Alto) | menú → Tomar descanso | tocar el aviso ámbar |
//! | Salir | BACK | deslizar a la derecha (sin modo demo) |
//!
//! - START (onKey, KEY_ENTER) y el toque en el botón grande (su área táctil,
//!   RoundLayout.buttonTouchRect) dan además el foco al botón (borde cian, ButtonFocus).
//! - La zona del menú (RoundLayout.menuZoneRect) no toca el botón grande: tocar la hora
//!   nunca inicia la guardia. Un toque en cualquier otra parte no hace nada.
//! - UP y DOWN enfocan el botón grande (borde cian durante 1,5 s).
//! - BACK sale de la app; si la guardia está activa, antes la detiene y guarda la
//!   actividad (ver onBack).
//!
//! Verificado en el simulador del fr165 con la traza de entrada (InputTrace): START y
//! cualquier toque disparan primero el comportamiento onSelect; solo si devuelve false
//! llegan onKey (KEY_ENTER) u onTap (con coordenadas). Por eso onSelect no hace nada.
//! Deslizar a la derecha llega como onBack (como el botón BACK, pero sin evento de
//! tecla: BackSource los distingue); a la izquierda, como onSwipe.
class MainDelegate extends WatchUi.BehaviorDelegate {

    //! Nombre de la vista en la traza de entrada (InputTrace, solo en depuración).
    const TRACE = "esfera";

    private var _guard as GuardController;

    //! Foco del botón grande: START y un toque en él lo marcan (borde cian en la esfera).
    private var _focus as ButtonFocus;

    //! Geometría de la pantalla, la misma que usa MainView para dibujar el botón.
    private var _layout as RoundLayout;

    //! ¿El último onBack vino del botón o de deslizar a la derecha?
    private var _back as BackSource = new BackSource();

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
        InputTrace.behavior(TRACE, "onSelect");
        return false;
    }

    //! Botón START/STOP (KEY_ENTER): inicia o pausa la guardia.
    function onKey(keyEvent as KeyEvent) as Boolean {
        InputTrace.key(TRACE, "onKey", keyEvent);
        if (keyEvent.getKey() == WatchUi.KEY_ENTER) {
            _focus.press(System.getTimer());
            _guard.toggle();
            return true;
        }
        return false;
    }

    //! Toque en la pantalla, por orden de prioridad: el botón grande (su área táctil)
    //! inicia o pausa la guardia; el aviso de fatiga, si se ve, abre el descanso guiado;
    //! la franja de la batería y la hora abre el menú principal. Se consume siempre,
    //! también fuera de todos ellos, para que un toque en cualquier parte no tenga otro
    //! efecto.
    function onTap(clickEvent as ClickEvent) as Boolean {
        InputTrace.click(TRACE, "toque", clickEvent);
        var point = clickEvent.getCoordinates();
        if (_layout.hitsButton(point[0], point[1])) {
            _focus.press(System.getTimer());
            _guard.toggle();
        } else if (_guard.showsFatigueWarning() && _layout.hitsFatigueBanner(point[0], point[1])) {
            _guard.startBreak();
        } else if (_layout.hitsMenuZone(point[0], point[1])) {
            MainMenu.open(_guard);
        }
        return true;
    }

    //! Mantener la pantalla pulsada (en cualquier parte): abre el menú principal, como
    //! mantener UP.
    function onHold(clickEvent as ClickEvent) as Boolean {
        InputTrace.click(TRACE, "pulsación larga", clickEvent);
        MainMenu.open(_guard);
        return true;
    }

    //! Deslizar a la izquierda: con el modo demo, escenario siguiente. Deslizar a la
    //! derecha llega antes como onBack (ahí se trata); si llega aquí, escenario anterior.
    //! Arriba y abajo ya llegaron como nextPage / previousPage.
    function onSwipe(swipeEvent as SwipeEvent) as Boolean {
        InputTrace.swipe(TRACE, swipeEvent);
        var direction = swipeEvent.getDirection();
        if (direction == WatchUi.SWIPE_LEFT) {
            return _guard.stepDemoScenario(true);
        }
        if (direction == WatchUi.SWIPE_RIGHT) {
            return _guard.stepDemoScenario(false);
        }
        return false;
    }

    //! BACK. Si no hubo tecla BACK (es el gesto de deslizar a la derecha) y el modo demo
    //! está activo, cambia al escenario anterior y no sale. En otro caso sale de la app:
    //! si la guardia está activa, antes la detiene y guarda la actividad (devuelve false
    //! para que BACK siga saliendo).
    function onBack() as Boolean {
        InputTrace.behavior(TRACE, "onBack");
        if (!_back.isFromKey(System.getTimer()) && _guard.stepDemoScenario(false)) {
            return true;
        }
        if (_guard.isActive()) {
            _guard.shutdown();
        }
        return false;
    }

    //! DOWN (nextPage): enfoca el botón grande y, con el modo demo durante la guardia,
    //! pasa al siguiente escenario.
    function onNextPage() as Boolean {
        InputTrace.behavior(TRACE, "nextPage");
        _focus.focus(System.getTimer());
        WatchUi.requestUpdate();
        return _guard.cycleDemoScenario();
    }

    //! UP (previousPage): enfoca el botón grande (ButtonFocus), el único control de la
    //! esfera.
    function onPreviousPage() as Boolean {
        InputTrace.behavior(TRACE, "previousPage");
        _focus.focus(System.getTimer());
        WatchUi.requestUpdate();
        return true;
    }

    //! Pulsación larga del botón de menú (UP en el fr165; tecla M en el simulador): abre
    //! el menú principal (modo demo, ajustes, historial…; en depuración, también el menú
    //! de depuración).
    function onMenu() as Boolean {
        InputTrace.behavior(TRACE, "onMenu");
        MainMenu.open(_guard);
        return true;
    }

    //! Tecla pulsada y soltada: se trazan (InputTrace) y la tecla BACK se anota para
    //! distinguir el botón del gesto (BackSource). Devuelven false para que el sistema
    //! siga generando el comportamiento (onSelect, onBack, onMenu…) y onKey.
    function onKeyPressed(keyEvent as KeyEvent) as Boolean {
        InputTrace.key(TRACE, "pulsada", keyEvent);
        noteBackKey(keyEvent);
        return false;
    }

    function onKeyReleased(keyEvent as KeyEvent) as Boolean {
        InputTrace.key(TRACE, "soltada", keyEvent);
        noteBackKey(keyEvent);
        return false;
    }

    function onRelease(clickEvent as ClickEvent) as Boolean {
        InputTrace.click(TRACE, "fin de pulsación", clickEvent);
        return false;
    }

    private function noteBackKey(keyEvent as KeyEvent) as Void {
        if (keyEvent.getKey() == WatchUi.KEY_ESC) {
            _back.keyEvent(System.getTimer());
        }
    }
}
