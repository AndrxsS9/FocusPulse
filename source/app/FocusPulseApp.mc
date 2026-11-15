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
        // Ajustes de usuario (Application.Properties, editables desde Garmin Connect).
        _guard.applySettings(AppSettings.load());
        // El modo demo y su escenario se recuerdan entre arranques (DemoStore).
        _guard.loadDemoConfig(DemoStore.load());
        // Las últimas 10 guardias (HistoryStore).
        _guard.loadHistory(HistoryStore.load());
    }

    //! Llega al guardar los ajustes en la app Garmin Connect (o en el editor de ajustes
    //! del simulador) con la app abierta: se aplican sin reiniciar la guardia.
    function onSettingsChanged() as Void {
        _guard.applySettings(AppSettings.load());
        WatchUi.requestUpdate();
    }

    //! Se llama al cerrar la app (BACK, cierre del sistema): si la guardia sigue
    //! activa, libera el sensor y guarda la actividad.
    function onStop(state as Dictionary?) as Void {
        _guard.shutdown();
    }

    //! Vista inicial de la app.
    function getInitialView() as [Views] or [Views, InputDelegates] {
        // El foco del botón grande lo comparten la esfera (lo dibuja) y su delegado (lo
        // pulsa).
        var focus = new ButtonFocus();
        return [new MainView(_guard, focus), new MainDelegate(_guard, focus)];
    }
}

//! Acceso tipado a la instancia de la aplicación.
function getApp() as FocusPulseApp {
    return Application.getApp() as FocusPulseApp;
}
