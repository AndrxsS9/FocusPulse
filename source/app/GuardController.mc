import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

//! Coordina la guardia: estado (MonitorState), fuente del acelerómetro, motor de
//! telemetría, detector de somnolencia, clasificador y grabación de la actividad.
//!
//! - start(): reinicia el motor y el puntaje de alerta (88), arranca la fuente (real, o
//!   simulada con el modo demo activo), el detector (que empieza calibrando, con los
//!   tiempos del modo: DemoConfig) y, si el ajuste recordActivity está activo, la
//!   grabación.
//! - pause(): detiene la fuente, guarda la actividad, congela el puntaje y reinicia el
//!   detector y el clasificador.
//! - shutdown(): lo mismo, al cerrar la app con la guardia activa.
//!
//! Con cada lote (onBatch), en este orden: motor → snapshot → detector → clasificador →
//! puntaje (que sigue las probabilidades del clasificador). Todo se actualiza con los lotes de telemetría, no con el redibujo de la
//! vista. El último evento del detector se guarda con su hora para las vistas. Las vistas
//! leen el estado, el puntaje y el snapshot; los delegados llaman a toggle().
//!
//! Alerta (fase 7): un evento del detector pasa a AlertController; si abre una alerta,
//! se apila AlertView y Haptics empieza a vibrar. Mientras está abierta, los eventos
//! nuevos se ignoran y la esfera no se redibuja. "Estoy despierto" (dismissAlert) para
//! la vibración, sube el puntaje a SCORE_AFTER_ALERT y guarda la alerta en AlertLog con
//! su tiempo de respuesta. Pausar la guardia (o cerrar la app) la cierra sin respuesta.
//!
//! Modo demo (fase 8): DemoConfig decide la fuente y los tiempos; se guarda en Storage
//! (DemoStore) con cada cambio. Cambiar de modo con la guardia activa la reinicia sin
//! pausarla (restartGuard): otra fuente, motor, puntaje y detector desde cero, y la
//! grabación sigue.
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

    //! Modo demo: fuente simulada, escenario y tiempos del detector.
    private var _demo as DemoConfig;

    //! Aviso breve en la esfera (cambio de escenario con DOWN).
    private var _toast as Toast;

    //! true si el último intento de iniciar la guardia falló por el sensor.
    private var _sensorUnavailable as Boolean = false;

    //! Puntaje mínimo tras confirmar "Estoy despierto".
    static const SCORE_AFTER_ALERT = 70.0f;

    //! Alerta a pantalla completa: estado, vibración y alertas respondidas (en memoria).
    private var _alerts as AlertController;
    private var _haptics as Haptics;
    private var _alertLog as AlertLog;

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
        _demo = new DemoConfig();
        _toast = new Toast();
        _demoSource = new SimulatedAccelSource(_demo.scenario(), demoSeed);
        _realSource.setListener(method(:onBatch));
        _demoSource.setListener(method(:onBatch));
        _alerts = new AlertController();
        _haptics = new Haptics();
        _alertLog = new AlertLog();
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
        // Con una alerta abierta, la cierra sin guardar respuesta y vuelve a la esfera.
        if (cancelAlert()) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
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
        cancelAlert();
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
            // Con una alerta ya abierta, AlertController ignora el evento.
            if (_alerts.onEvent(event, System.getTimer())) {
                showAlert();
            }
        }
        _score.update(_classifier.isReady() ? _classifier.probabilities() : null, dt);

        // Con la alerta encima, la esfera y el orbe no se ven: no se redibujan (MainView
        // además detiene su timer en onHide). La alerta tiene su propio timer.
        if (!_alerts.isActive()) {
            WatchUi.requestUpdate();
        }
    }

    // --- Alerta -----------------------------------------------------------------

    //! Abre una alerta de un nivel concreto (menú de depuración). Devuelve false si ya
    //! había una abierta.
    function triggerAlert(level as Number, reason as DrowsinessEvent.Id) as Boolean {
        if (!_alerts.trigger(level, reason, System.getTimer())) {
            return false;
        }
        showAlert();
        return true;
    }

    //! Apila la alerta sobre la vista actual (normalmente la esfera) y empieza a vibrar.
    private function showAlert() as Void {
        WatchUi.pushView(new AlertView(_alerts), new AlertDelegate(method(:dismissAlert)),
            WatchUi.SLIDE_IMMEDIATE);
        _haptics.start(_alerts.level());
    }

    //! "Estoy despierto" (botón o START): detiene la vibración, sube el puntaje a un
    //! mínimo de SCORE_AFTER_ALERT, guarda la alerta con su tiempo de respuesta y
    //! vuelve a la vista anterior. El detector sigue vigilando: no se reinicia, así que
    //! respeta el refractario del evento que abrió la alerta.
    function dismissAlert() as Void {
        var response = _alerts.dismiss(System.getTimer());
        if (response == null) {
            return;
        }
        _haptics.stop();
        if (_state.isActive()) {
            _score.raiseTo(SCORE_AFTER_ALERT);
        }
        _alertLog.add(new AlertRecord(_alerts.reason(), _alerts.level(), _alerts.startMs(),
            response));
        logDismiss(response);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.requestUpdate();
    }

    //! Cierra la alerta sin respuesta (pausa o cierre de la app). Devuelve true si había
    //! una abierta; quien llama decide si quita la vista.
    private function cancelAlert() as Boolean {
        if (!_alerts.cancel()) {
            return false;
        }
        _haptics.stop();
        logCancel();
        return true;
    }

    (:debug)
    private function logCancel() as Void {
        System.println("ALERTA cerrada sin respuesta (guardia en pausa o app cerrada)");
    }

    (:release)
    private function logCancel() as Void {
    }

    (:debug)
    private function logDismiss(responseMs as Number) as Void {
        System.println("ALERTA descartada en " + responseMs + " ms (" + _haptics.bursts()
            + " ráfagas); alertas respondidas: " + _alertLog.size() + ", media "
            + _alertLog.averageResponseMs() + " ms; puntaje " + _score.value());
    }

    (:release)
    private function logDismiss(responseMs as Number) as Void {
    }

    function isAlertActive() as Boolean {
        return _alerts.isActive();
    }

    //! Alertas respondidas en esta ejecución de la app (solo en memoria).
    function alertLog() as AlertLog {
        return _alertLog;
    }

    //! Arranca el detector (calibrando) y el clasificador desde cero.
    private function startDetection() as Void {
        _detectionStartMs = System.getTimer();
        _detector.start(_detectionStartMs, _demo.isEnabled());
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

    // --- Modo demo --------------------------------------------------------------

    //! Configuración del modo demo (solo lectura para las vistas y los menús).
    function demoConfig() as DemoConfig {
        return _demo;
    }

    //! true con el modo demo activo: la guardia usa (o usará) la fuente simulada.
    function isDemoMode() as Boolean {
        return _demo.isEnabled();
    }

    function demoScenario() as AccelScenario.Id {
        return _demo.scenario();
    }

    //! Aplica la configuración guardada al arrancar la app (antes de la primera guardia).
    function loadDemoConfig(config as DemoConfig) as Void {
        _demo = config;
        _demoSource.setScenario(config.scenario());
    }

    //! Activa o desactiva el modo demo y lo guarda. Con la guardia activa la reinicia
    //! con la otra fuente y los tiempos del otro modo.
    function setDemoMode(enabled as Boolean) as Void {
        if (enabled == _demo.isEnabled()) {
            return;
        }
        _demo.setEnabled(enabled);
        DemoStore.save(_demo);
        restartGuard();
    }

    //! Cambia el escenario simulado y lo guarda. El escenario empieza desde el
    //! principio (elegir otra vez "Simular cabeceo" repite el cabeceo); el detector no
    //! se reinicia, como al cambiar de postura de verdad.
    function setDemoScenario(scenario as AccelScenario.Id) as Void {
        _demo.setScenario(scenario);
        _demoSource.setScenario(_demo.scenario());
        DemoStore.save(_demo);
        WatchUi.requestUpdate();
    }

    //! Atajo DOWN de la esfera: con el modo demo activo y la guardia en marcha pasa al
    //! siguiente escenario (normal → tecleo → cabeceo → inactividad → normal) y muestra
    //! un aviso de 1,5 s con su nombre. Devuelve false, sin hacer nada, en otro caso.
    function cycleDemoScenario() as Boolean {
        if (!_demo.handlesDownButton(_state.isActive())) {
            return false;
        }
        setDemoScenario(DemoConfig.scenarioAfter(_demo.scenario()));
        _toast.show(ToastKind.SCENARIO, _demo.scenario() as Number, System.getTimer());
        return true;
    }

    //! Aviso breve para la esfera (solo lectura).
    function toast() as Toast {
        return _toast;
    }

    //! Frecuencia nominal de la fuente elegida (Hz).
    function nominalRateHz() as Number {
        return currentSource().sampleRateHz();
    }

    //! Reinicio seguro tras cambiar de modo: con la guardia en pausa solo redibuja; con
    //! la guardia activa detiene las dos fuentes, vacía el motor, vuelve el puntaje a 88,
    //! arranca la fuente del modo nuevo y vuelve a calibrar. La grabación de la
    //! actividad no se corta. Si la fuente nueva no arranca, pausa la guardia.
    private function restartGuard() as Void {
        if (!_state.isActive()) {
            WatchUi.requestUpdate();
            return;
        }
        if (cancelAlert()) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
        _realSource.stop();
        _demoSource.stop();
        _engine.reset();
        _snapshot = _engine.snapshot();
        _lastBatchMs = null;
        if (!currentSource().start()) {
            _sensorUnavailable = true;
            pause();
            return;
        }
        _sensorUnavailable = false;
        _score.reset();
        startDetection();
        WatchUi.requestUpdate();
    }

    private function currentSource() as AccelSource {
        return _demo.usesSimulatedSource() ? _demoSource : _realSource;
    }
}
