import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! Punto de entrada de FocusPulse AI (declarado como `entry` en manifest.xml).
class FocusPulseApp extends Application.AppBase {

    //! Estado compartido entre la vista y su delegado.
    private var _monitorState as MonitorState;

    function initialize() {
        AppBase.initialize();
        _monitorState = new MonitorState();
    }

    //! Se llama al iniciar la app, antes de mostrar la vista inicial.
    function onStart(state as Dictionary?) as Void {
    }

    //! Se llama al cerrar la app. Aquí se liberarán sensores y alertas.
    function onStop(state as Dictionary?) as Void {
    }

    //! Vista inicial de la app.
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new MainView(_monitorState), new MainDelegate(_monitorState)];
    }
}

//! Acceso tipado a la instancia de la aplicación.
function getApp() as FocusPulseApp {
    return Application.getApp() as FocusPulseApp;
}
