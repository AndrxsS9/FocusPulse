import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Punto de entrada de FocusPulse AI (declarado como `entry` en manifest.xml).
class FocusPulseApp extends Application.AppBase {

    //! Estado de la guardia (activo / en pausa).
    private var _monitorState as MonitorState;

    //! Guardia: fuente del acelerómetro, telemetría y grabación.
    private var _guard as GuardController;

    function initialize() {
        AppBase.initialize();
        _monitorState = new MonitorState();
        _guard = new GuardController(_monitorState,
            WatchUi.loadResource(Rez.Strings.SessionName) as String,
            System.getTimer());
    }

    //! Se llama al iniciar la app, antes de mostrar la vista inicial.
    function onStart(state as Dictionary?) as Void {
        restoreDebugSource();
    }

    //! Se llama al cerrar la app (BACK, cierre del sistema): si la guardia sigue
    //! activa, libera el sensor y guarda la actividad.
    function onStop(state as Dictionary?) as Void {
        _guard.shutdown();
    }

    //! Vista inicial de la app.
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new MainView(_guard), new MainDelegate(_guard)];
    }

    //! En depuración recupera la fuente elegida en el menú de depuración, para no
    //! tener que elegirla otra vez en cada arranque del simulador.
    (:debug)
    private function restoreDebugSource() as Void {
        DebugSource.restore(_guard);
    }

    //! En release la guardia siempre usa el acelerómetro real.
    (:release)
    private function restoreDebugSource() as Void {
    }
}

//! Acceso tipado a la instancia de la aplicación.
function getApp() as FocusPulseApp {
    return Application.getApp() as FocusPulseApp;
}
