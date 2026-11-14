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
        // El modo demo y su escenario se recuerdan entre arranques (DemoStore).
        _guard.loadDemoConfig(DemoStore.load());
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
}

//! Acceso tipado a la instancia de la aplicación.
function getApp() as FocusPulseApp {
    return Application.getApp() as FocusPulseApp;
}
