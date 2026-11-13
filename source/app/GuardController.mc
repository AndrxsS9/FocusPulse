import Toybox.Lang;
import Toybox.WatchUi;

//! Coordina la guardia: estado (MonitorState), fuente del acelerÃ³metro, motor de
//! telemetrÃ­a y grabaciÃ³n de la actividad.
//!
//! - start(): reinicia el motor, arranca la fuente (real, o simulada si se eligiÃ³ la
//!   fuente demo) y, si el ajuste recordActivity estÃ¡ activo, la grabaciÃ³n.
//! - pause(): detiene la fuente y guarda la actividad.
//! - shutdown(): lo mismo, al cerrar la app con la guardia activa.
//!
//! Las vistas leen el estado y el snapshot; los delegados llaman a toggle().
class GuardController {

    private var _state as MonitorState;
    private var _engine as TelemetryEngine;
    private var _recorder as SessionRecorder;

    private var _realSource as RealAccelSource;
    private var _demoSource as SimulatedAccelSource;

    //! true: la guardia usa la fuente simulada (modo demo / depuraciÃ³n).
    private var _useDemoSource as Boolean = false;

    //! true si el Ãºltimo intento de iniciar la guardia fallÃ³ por el sensor.
    private var _sensorUnavailable as Boolean = false;

    //! sessionName: nombre de la actividad grabada (texto localizado).
    function initialize(state as MonitorState, sessionName as String, demoSeed as Number) {
        _state = state;
        _engine = new TelemetryEngine();
        _recorder = new SessionRecorder(sessionName);
        _realSource = new RealAccelSource();
        _demoSource = new SimulatedAccelSource(AccelScenario.NORMAL, demoSeed);
        _realSource.setListener(method(:onBatch));
        _demoSource.setListener(method(:onBatch));
    }

    // --- Guardia ----------------------------------------------------------------

    function isActive() as Boolean {
        return _state.isActive();
    }

    //! Inicia o pausa la guardia. Devuelve el nuevo estado (activo o no).
    function toggle() as Boolean {
        if (_state.isActive()) {
            pause();
        } else {
            start();
        }
        return _state.isActive();
    }

    //! Inicia la guardia. Devuelve false, sin cambiar de estado, si la fuente no estÃ¡
    //! disponible. Que no se pueda grabar la actividad no impide la guardia.
    function start() as Boolean {
        if (_state.isActive()) {
            return true;
        }
        _engine.reset();
        if (!currentSource().start()) {
            _sensorUnavailable = true;
            WatchUi.requestUpdate();
            return false;
        }
        _sensorUnavailable = false;
        if (AppSettings.recordActivity()) {
            _recorder.start();
        }
        _state.start();
        WatchUi.requestUpdate();
        return true;
    }

    //! Pausa la guardia: detiene la fuente y guarda la actividad, si se grababa.
    function pause() as Void {
        stopAll();
        _state.pause();
        WatchUi.requestUpdate();
    }

    //! Cierre seguro al salir de la app: libera el sensor o el temporizador y guarda
    //! la actividad. No pide redibujar porque la vista ya no existe.
    //!
    //! Se llama dos veces al salir con BACK: desde MainDelegate.onBack, antes de que la
    //! app empiece a cerrarse (el simulador 9.3.0 se cae si la app termina con una
    //! sesiÃ³n aÃºn grabando, aunque onStop la guarde), y desde onStop como respaldo para
    //! los cierres del sistema. La segunda llamada no hace nada.
    function shutdown() as Void {
        stopAll();
        _state.pause();
    }

    private function stopAll() as Void {
        _realSource.stop();
        _demoSource.stop();
        _recorder.stop(true);
    }

    // --- Datos ------------------------------------------------------------------

    //! Callback de lote de la fuente activa.
    function onBatch(xs as Array<Number>, ys as Array<Number>, zs as Array<Number>,
            timestampMs as Number) as Void {
        if (!_state.isActive()) {
            return;
        }
        _engine.addBatch(xs, ys, zs, timestampMs);
        WatchUi.requestUpdate();
    }

    function snapshot() as TelemetrySnapshot {
        return _engine.snapshot();
    }

    function isRecording() as Boolean {
        return _recorder.isRecording();
    }

    function isSensorUnavailable() as Boolean {
        return _sensorUnavailable;
    }

    // --- Fuente -----------------------------------------------------------------

    //! true si la guardia usa (o usarÃ¡) la fuente simulada.
    function isDemoSource() as Boolean {
        return _useDemoSource;
    }

    function demoScenario() as AccelScenario.Id {
        return _demoSource.scenario();
    }

    //! Frecuencia nominal de la fuente elegida (Hz).
    function nominalRateHz() as Number {
        return currentSource().sampleRateHz();
    }

    //! Elige la fuente: real (demo = false) o simulada con un escenario. Con la guardia
    //! activa cambia de fuente en caliente y reinicia el motor; elegir de nuevo un
    //! escenario lo empieza desde el principio.
    function selectSource(demo as Boolean, scenario as AccelScenario.Id) as Void {
        _demoSource.setScenario(scenario);
        if (demo == _useDemoSource) {
            WatchUi.requestUpdate();
            return;
        }

        var wasActive = _state.isActive();
        if (wasActive) {
            currentSource().stop();
        }
        _useDemoSource = demo;
        if (wasActive) {
            _engine.reset();
            if (!currentSource().start()) {
                _sensorUnavailable = true;
                pause();
                return;
            }
        }
        WatchUi.requestUpdate();
    }

    private function currentSource() as AccelSource {
        return _useDemoSource ? _demoSource : _realSource;
    }
}
