import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

//! Coordina la guardia: estado (MonitorState), fuente del acelerómetro, motor de
//! telemetría, detector de somnolencia, clasificador y grabación de la actividad.
//!
//! - start(): reinicia el motor y el puntaje de alerta (88), arranca la fuente (real, o
//!   simulada si se eligió la fuente demo), el detector (que empieza calibrando, con
//!   los tiempos del modo demo si la fuente es simulada) y, si el ajuste recordActivity
//!   está activo, la grabación.
//! - pause(): detiene la fuente, guarda la actividad, congela el puntaje y reinicia el
//!   detector y el clasificador.
//! - shutdown(): lo mismo, al cerrar la app con la guardia activa.
//!
//! Con cada lote (onBatch), en este orden: motor → snapshot → detector → clasificador →
//! puntaje (que sigue las probabilidades del clasificador). Todo se actualiza con los lotes de telemetría, no con el redibujo de la
//! vista. El último evento del detector se guarda con su hora para las vistas. Las vistas
//! leen el estado, el puntaje y el snapshot; los delegados llaman a toggle().
class GuardController {

    private var _state as MonitorState;
    private var _engine as TelemetryEngine;
    private var _score as AlertnessScore;
    private var _detector as DrowsinessDetector;
    private var _classifier as StateClassifier;

    //! Último evento del detector y su hora (se conservan al pausar).
    private var _lastEvent as DrowsinessEvent.Id = DrowsinessEvent.NONE;
    private var _lastEventMoment as Time.Moment? = null;

    //! System.getTimer() al arrancar el detector (para el registro de depuración).
    private var _detectionStartMs as Number = 0;

    //! Último snapshot calculado (uno por lote). Las vistas lo leen en cada cuadro sin
    //! crear objetos nuevos.
    private var _snapshot as TelemetrySnapshot;

    //! Marca de tiempo del último lote, para calcular el dt del puntaje. null tras
    //! iniciar la guardia o cambiar de fuente.
    private var _lastBatchMs as Number? = null;
    private var _recorder as SessionRecorder;

    private var _realSource as RealAccelSource;
    private var _demoSource as SimulatedAccelSource;

    //! true: la guardia usa la fuente simulada (modo demo / depuración).
    private var _useDemoSource as Boolean = false;

    //! true si el último intento de iniciar la guardia falló por el sensor.
    private var _sensorUnavailable as Boolean = false;

    //! sessionName: nombre de la actividad grabada (texto localizado).
    function initialize(state as MonitorState, sessionName as String, demoSeed as Number) {
        _state = state;
        _engine = new TelemetryEngine();
        _score = new AlertnessScore();
        _detector = new DrowsinessDetector();
        _classifier = new StateClassifier();
        _snapshot = _engine.snapshot();
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

    //! Inicia la guardia. Devuelve false, sin cambiar de estado, si la fuente no está
    //! disponible. Que no se pueda grabar la actividad no impide la guardia.
    function start() as Boolean {
        if (_state.isActive()) {
            return true;
        }
        _engine.reset();
        _snapshot = _engine.snapshot();
        if (!currentSource().start()) {
            _sensorUnavailable = true;
            WatchUi.requestUpdate();
            return false;
        }
        _sensorUnavailable = false;
        _score.reset();
        startDetection();
        _lastBatchMs = null;
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
    //! sesión aún grabando, aunque onStop la guarde), y desde onStop como respaldo para
    //! los cierres del sistema. La segunda llamada no hace nada.
    function shutdown() as Void {
        stopAll();
        _state.pause();
    }

    private function stopAll() as Void {
        _score.setActive(false);
        _detector.reset();
        _classifier.reset();
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

        // dt del puntaje: tiempo desde el lote anterior; en el primero, la duración
        // nominal del lote.
        var last = _lastBatchMs;
        var dt = xs.size().toFloat() / currentSource().sampleRateHz();
        if (last != null && timestampMs > last) {
            dt = (timestampMs - last) / 1000.0f;
        }
        _lastBatchMs = timestampMs;
        _snapshot = _engine.snapshot();

        var event = _detector.update(_snapshot, timestampMs);
        _classifier.update(_snapshot, _detector);
        if (event != DrowsinessEvent.NONE) {
            _lastEvent = event;
            _lastEventMoment = Time.now();
            logEvent(event, timestampMs);
        }
        _score.update(_classifier.isReady() ? _classifier.probabilities() : null, dt);

        WatchUi.requestUpdate();
    }

    //! Arranca el detector (calibrando) y el clasificador desde cero.
    private function startDetection() as Void {
        _detectionStartMs = System.getTimer();
        _detector.start(_detectionStartMs, _useDemoSource);
        _classifier.reset();
    }

    //! En depuración, cada evento queda en la consola del simulador.
    (:debug)
    private function logEvent(event as DrowsinessEvent.Id, timestampMs as Number) as Void {
        System.println("EVENTO " + (event == DrowsinessEvent.NOD ? "cabeceo" : "inactividad")
            + " a los " + ((timestampMs - _detectionStartMs) / 1000.0f).format("%.1f")
            + " s de iniciar, inclinación " + _detector.tiltDegrees().format("%.0f")
            + "°, umbral " + _detector.stillThreshold().format("%.0f") + " mg²");
    }

    (:release)
    private function logEvent(event as DrowsinessEvent.Id, timestampMs as Number) as Void {
    }

    //! Detector de somnolencia (solo lectura para las vistas).
    function detector() as DrowsinessDetector {
        return _detector;
    }

    //! Clasificador de estado (solo lectura para las vistas).
    function classifier() as StateClassifier {
        return _classifier;
    }

    //! Clase ganadora del clasificador (Normal antes del primer lote y en pausa).
    function topClass() as DrowsinessClass.Id {
        return _classifier.topClass();
    }

    //! true con la guardia activa mientras se calibra la línea base.
    function isCalibrating() as Boolean {
        return _state.isActive() && _detector.isCalibrating();
    }

    //! Último evento detectado (NONE si aún no hubo ninguno).
    function lastEvent() as DrowsinessEvent.Id {
        return _lastEvent;
    }

    //! Hora del último evento (null si aún no hubo ninguno).
    function lastEventMoment() as Time.Moment? {
        return _lastEventMoment;
    }

    //! Puntaje de alerta (0–100). Congelado en pausa; 88 antes de la primera guardia.
    function alertness() as Number {
        return _score.value();
    }

    //! Características actuales (snapshot nuevo).
    function snapshot() as TelemetrySnapshot {
        return _engine.snapshot();
    }

    //! Snapshot del último lote, sin crear objetos: para redibujos frecuentes.
    function latestSnapshot() as TelemetrySnapshot {
        return _snapshot;
    }

    function isRecording() as Boolean {
        return _recorder.isRecording();
    }

    function isSensorUnavailable() as Boolean {
        return _sensorUnavailable;
    }

    // --- Fuente -----------------------------------------------------------------

    //! true si la guardia usa (o usará) la fuente simulada.
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
            _lastBatchMs = null;
            if (!currentSource().start()) {
                _sensorUnavailable = true;
                pause();
                return;
            }
            // Otra fuente, otro modo: vuelve a calibrar.
            startDetection();
        }
        WatchUi.requestUpdate();
    }

    private function currentSource() as AccelSource {
        return _useDemoSource ? _demoSource : _realSource;
    }
}
