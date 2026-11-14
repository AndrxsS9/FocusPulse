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
//! Escalamiento (fase 9): sin respuesta, AlertController sube la alerta un nivel cada
//! 10 s (6 s en modo demo) hasta el 3. Lo avanzan los lotes (onBatch) y el reloj de la
//! propia alerta (onAlertTick); al subir, Haptics cambia al patrón del nivel nuevo. Se
//! guarda el nivel máximo alcanzado junto al tiempo de respuesta.
//!
//! Episodios y fatiga (fase 9): cada alerta abierta por el detector es un episodio de
//! la guardia actual (_episodes, que se vacía al iniciar una guardia), con su hora
//! desde el inicio de la guardia, su respuesta (o ninguna, si se pausó con la alerta
//! abierta) y su nivel máximo. Las alertas de "Probar alerta" no cuentan. Con cada lote
//! y cada episodio nuevo, FatiguePredictor recalcula la fatiga; en Alto la esfera
//! muestra el aviso de descanso.
//!
//! Descanso guiado: startBreak (toque en el aviso o "Tomar descanso" en el menú)
//! suspende la detección (fuente, detector, guion) sin terminar la guardia: la
//! grabación sigue y los episodios se conservan. Al llegar a cero vibra suave y la
//! fatiga vuelve a contar desde ese instante; endBreak ("Reanudar guardia" o BACK)
//! reanuda la detección, que vuelve a calibrar.
//!
//! Resumen e historial: al terminar una guardia (pausa, cierre de la app o fallo del
//! sensor al reanudar) se arma su GuardSummary con la fatiga final. Si merece la pena
//! (1 min o algún episodio) se guarda en el historial (SessionHistory, las 10 últimas,
//! en Storage con HistoryStore) y, al pausar desde la esfera, se abre "Resumen de la
//! guardia" (SummaryView).
//!
//! Modo demo (fase 8): DemoConfig decide la fuente y los tiempos; se guarda en Storage
//! (DemoStore) con cada cambio. Cambiar de modo con la guardia activa la reinicia sin
//! pausarla (restartGuard): otra fuente, motor, puntaje y detector desde cero, y la
//! grabación sigue.
//!
//! Guion automático (DemoScript): avanza con los lotes y con las alertas del detector
//! que se responden; cada paso cambia el escenario simulado. Se cancela al pausar la
//! guardia, al apagar el modo demo, con DOWN o al elegir un escenario a mano.
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

    //! Aviso breve en la esfera (cambio de escenario con DOWN, fin del guion).
    private var _toast as Toast;

    //! Guion automático del modo demo.
    private var _script as DemoScript;

    //! true si el último intento de iniciar la guardia falló por el sensor.
    private var _sensorUnavailable as Boolean = false;

    //! Puntaje mínimo tras confirmar "Estoy despierto".
    static const SCORE_AFTER_ALERT = 70.0f;

    //! Alerta a pantalla completa: estado y vibración.
    private var _alerts as AlertController;
    private var _haptics as Haptics;

    //! true si la alerta abierta (o la última) la abrió el detector: es un episodio.
    private var _alertFromDetector as Boolean = false;

    //! Episodios de la guardia actual (startMs desde _guardStartMs).
    private var _episodes as AlertLog;

    //! System.getTimer() al iniciar la guardia (no cambia al reiniciar la detección).
    private var _guardStartMs as Number = 0;

    //! Desde cuándo cuenta el predictor de fatiga (ms desde el inicio de la guardia):
    //! 0, o el final del último descanso completo.
    private var _fatigueSinceMs as Number = 0;
    private var _fatigue as FatigueLevel.Id = FatigueLevel.LOW;

    //! Descanso guiado en curso (la guardia está suspendida mientras corre).
    private var _break as BreakTimer;

    //! Inicio de la guardia (segundos Unix) y si corrió en modo demo, para su resumen.
    private var _guardDateSec as Number = 0;
    private var _guardDemo as Boolean = false;

    //! Últimas guardias (se carga al abrir la app: loadHistory).
    private var _history as SessionHistory;

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
        _script = new DemoScript();
        _demoSource = new SimulatedAccelSource(_demo.scenario(), demoSeed);
        _realSource.setListener(method(:onBatch));
        _demoSource.setListener(method(:onBatch));
        _alerts = new AlertController();
        _alerts.setEscalationMs(_demo.alertEscalationMs());
        _haptics = new Haptics();
        _episodes = new AlertLog();
        _break = new BreakTimer();
        _history = new SessionHistory();
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
        // Guardia nueva: sin episodios y con la fatiga en Bajo.
        _guardStartMs = System.getTimer();
        _guardDateSec = Time.now().value();
        _guardDemo = _demo.isEnabled();
        _episodes.clear();
        _fatigueSinceMs = 0;
        _fatigue = FatigueLevel.LOW;
        _state.start();
        WatchUi.requestUpdate();
        return true;
    }

    //! Pausa la guardia: detiene la fuente, guarda la actividad, si se grababa, y guarda
    //! y muestra el resumen de la guardia si merece la pena.
    function pause() as Void {
        if (!_state.isActive()) {
            return;
        }
        // Con una alerta abierta, la cierra sin respuesta (el episodio cuenta) y vuelve
        // a la esfera.
        if (cancelAlert()) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
        var summary = finishGuard();
        stopAll();
        _state.pause();
        if (summary != null) {
            WatchUi.pushView(new SummaryView(summary, null), new SummaryDelegate(),
                WatchUi.SLIDE_UP);
        }
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
        if (_state.isActive() || _break.isRunning()) {
            cancelAlert();
            finishGuard();
        }
        _break.cancel();
        stopAll();
        _state.pause();
    }

    //! Resumen de la guardia que termina, con la fatiga final. Si merece la pena
    //! (GuardSummary.shouldShow) lo guarda en el historial y lo devuelve; si no, null.
    private function finishGuard() as GuardSummary? {
        updateFatigue();
        var summary = GuardSummary.fromEpisodes(_guardDateSec, guardElapsedMs(), _episodes,
            _fatigue, _guardDemo);
        logSummary(summary);
        if (!summary.isWorthShowing()) {
            return null;
        }
        _history.add(summary);
        HistoryStore.save(_history);
        return summary;
    }

    (:debug)
    private function logSummary(summary as GuardSummary) as Void {
        System.println("GUARDIA terminada: " + summary.durationMs + " ms, " + summary.episodes
            + " episodios, respuesta media " + summary.avgResponseMs + " ms, nivel máximo "
            + summary.maxLevel + ", fatiga " + (summary.fatigue as Number) + ", demo "
            + summary.demo + (summary.isWorthShowing() ? "" : " (sin resumen: < 1 min y sin episodios)"));
    }

    (:release)
    private function logSummary(summary as GuardSummary) as Void {
    }

    //! Historial de guardias (solo lectura para los menús).
    function history() as SessionHistory {
        return _history;
    }

    //! "Borrar historial" (tras confirmar): vacía el historial en memoria y en Storage.
    function clearHistory() as Void {
        _history.clear();
        HistoryStore.clear();
    }

    //! Aplica el historial guardado al arrancar la app.
    function loadHistory(history as SessionHistory) as Void {
        _history = history;
    }

    //! Detiene la detección y guarda la actividad: fin de la guardia.
    private function stopAll() as Void {
        stopDetection();
        _recorder.stop(true);
    }

    //! Detiene la fuente, el detector, el clasificador y el guion, sin tocar la
    //! grabación (pausa o descanso).
    private function stopDetection() as Void {
        _script.cancel();
        _score.setActive(false);
        _detector.reset();
        _classifier.reset();
        _realSource.stop();
        _demoSource.stop();
    }

    // --- Descanso guiado ----------------------------------------------------------

    //! true si se puede empezar un descanso: guardia activa y sin alerta abierta.
    function canTakeBreak() as Boolean {
        return _state.isActive() && !_alerts.isActive();
    }

    //! Empieza el descanso guiado (15 min, 30 s en demo) y abre su vista. La guardia
    //! queda suspendida: sin detección ni alertas, pero sin terminar (la actividad se
    //! sigue grabando y los episodios se conservan). Devuelve false si no se puede.
    function startBreak() as Boolean {
        if (!canTakeBreak()) {
            return false;
        }
        stopDetection();
        _state.pause();
        _break.start(System.getTimer(), _demo.breakMs());
        WatchUi.pushView(new BreakView(self), new BreakDelegate(self), WatchUi.SLIDE_UP);
        return true;
    }

    //! Reloj del descanso (lo llama su vista cada segundo). Al llegar a cero vibra suave
    //! una vez y la fatiga vuelve a contar desde ahora: el descanso se completó.
    function onBreakTick() as Void {
        if (_break.update(System.getTimer())) {
            _fatigueSinceMs = guardElapsedMs();
            _fatigue = FatigueLevel.LOW;
            _haptics.notify();
        }
    }

    //! "Reanudar guardia" (al terminar) o BACK (en cualquier momento): cierra la vista
    //! del descanso y reanuda la detección. Si se canceló antes de tiempo, la fatiga no
    //! se reinicia.
    function endBreak() as Void {
        if (!_break.isRunning()) {
            return;
        }
        _break.cancel();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        resumeAfterBreak();
    }

    function isOnBreak() as Boolean {
        return _break.isRunning();
    }

    //! Cuenta regresiva del descanso (solo lectura para su vista).
    function breakTimer() as BreakTimer {
        return _break;
    }

    //! Vuelve a vigilar tras el descanso, con la misma guardia: fuente, motor, puntaje
    //! y detector desde cero (vuelve a calibrar). Si la fuente no arranca, la guardia
    //! termina.
    private function resumeAfterBreak() as Void {
        _engine.reset();
        _snapshot = _engine.snapshot();
        _lastBatchMs = null;
        if (!currentSource().start()) {
            _sensorUnavailable = true;
            finishGuard();
            stopAll();
            WatchUi.requestUpdate();
            return;
        }
        _sensorUnavailable = false;
        _score.reset();
        startDetection();
        _state.start();
        updateFatigue();
        WatchUi.requestUpdate();
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
                // Solo las alertas del detector cuentan para los pasos de espera del
                // guion (no las de prueba del menú).
                _script.onAlertOpened();
                _alertFromDetector = true;
                showAlert();
            }
        }
        updateAlert();
        updateFatigue();
        if (_script.update(timestampMs, _alerts.isActive())) {
            onScriptStep();
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
        _alertFromDetector = false;
        showAlert();
        return true;
    }

    //! Apila la alerta sobre la vista actual (normalmente la esfera) y empieza a vibrar.
    private function showAlert() as Void {
        WatchUi.pushView(new AlertView(_alerts, method(:onAlertTick)),
            new AlertDelegate(method(:dismissAlert)), WatchUi.SLIDE_IMMEDIATE);
        _haptics.start(_alerts.level());
    }

    //! Reloj de la alerta abierta (lo llama la vista de la alerta en cada cuadro): la
    //! escala aunque la guardia esté en pausa (alertas de prueba) y sin esperar al lote.
    function onAlertTick() as Void {
        updateAlert();
    }

    //! Sube la alerta de nivel si lleva escalationMs sin respuesta y, si subió, cambia la
    //! vibración al patrón del nivel nuevo. La vista lee el nivel en cada cuadro.
    private function updateAlert() as Void {
        if (_alerts.update(System.getTimer())) {
            _haptics.start(_alerts.level());
            logEscalation();
        }
    }

    (:debug)
    private function logEscalation() as Void {
        System.println("ALERTA sube al nivel " + _alerts.level() + " a los "
            + _alerts.elapsedMs(System.getTimer()) + " ms sin respuesta");
    }

    (:release)
    private function logEscalation() as Void {
    }

    //! "Estoy despierto" (botón o START): detiene la vibración, sube el puntaje a un
    //! mínimo de SCORE_AFTER_ALERT, guarda el episodio con su tiempo de respuesta y su
    //! nivel máximo (si lo abrió el detector) y vuelve a la vista anterior. El detector sigue vigilando: no se reinicia, así que
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
        recordEpisode(response);
        logDismiss(response);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        if (_script.onAlertDismissed(System.getTimer())) {
            onScriptStep();
        }
        WatchUi.requestUpdate();
    }

    //! Cierra la alerta sin respuesta (pausa o cierre de la app). Devuelve true si había
    //! una abierta; quien llama decide si quita la vista.
    private function cancelAlert() as Boolean {
        if (!_alerts.cancel()) {
            return false;
        }
        _haptics.stop();
        // El episodio cuenta igual, sin respuesta y con el nivel al que llegó.
        recordEpisode(null);
        logCancel();
        return true;
    }

    //! Guarda la alerta que acaba de cerrarse como episodio de la guardia (solo las del
    //! detector y con la guardia activa) y recalcula la fatiga.
    private function recordEpisode(responseMs as Number?) as Void {
        if (!_alertFromDetector || !_state.isActive()) {
            return;
        }
        _episodes.add(new AlertRecord(_alerts.reason(), _alerts.level(),
            _alerts.startMs() - _guardStartMs, responseMs));
        updateFatigue();
    }

    // --- Fatiga -----------------------------------------------------------------

    //! Recalcula la fatiga con los episodios de la guardia y la ventana del modo.
    private function updateFatigue() as Void {
        if (!_state.isActive() && !_break.isRunning()) {
            return;
        }
        _fatigue = FatiguePredictor.assess(_episodes, guardElapsedMs(),
            _demo.fatigueWindowMs(), _fatigueSinceMs);
    }

    //! Fatiga de la guardia actual (o de la última, en pausa).
    function fatigue() as FatigueLevel.Id {
        return _fatigue;
    }

    //! true si la esfera debe mostrar el aviso "Micro-sueños repetidos": guardia activa
    //! con la fatiga en Alto.
    function showsFatigueWarning() as Boolean {
        return _state.isActive() && _fatigue == FatigueLevel.HIGH;
    }

    //! Tiempo desde el inicio de la guardia (ms).
    function guardElapsedMs() as Number {
        return System.getTimer() - _guardStartMs;
    }

    //! Episodios de la guardia actual (o de la última).
    function episodes() as AlertLog {
        return _episodes;
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
        System.println("ALERTA descartada en " + responseMs + " ms, nivel máximo "
            + _alerts.level() + " (" + _haptics.bursts()
            + " ráfagas); episodios: " + _episodes.size() + ", media "
            + _episodes.averageResponseMs() + " ms; fatiga " + (_fatigue as Number)
            + "; puntaje " + _score.value());
    }

    (:release)
    private function logDismiss(responseMs as Number) as Void {
    }

    function isAlertActive() as Boolean {
        return _alerts.isActive();
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
        _alerts.setEscalationMs(_demo.alertEscalationMs());
    }

    //! Activa o desactiva el modo demo y lo guarda. Con la guardia activa la reinicia
    //! con la otra fuente y los tiempos del otro modo.
    function setDemoMode(enabled as Boolean) as Void {
        if (enabled == _demo.isEnabled()) {
            return;
        }
        if (!enabled) {
            _script.cancel();
        }
        _demo.setEnabled(enabled);
        DemoStore.save(_demo);
        if (enabled && _state.isActive()) {
            _guardDemo = true;
        }
        _alerts.setEscalationMs(_demo.alertEscalationMs());
        restartGuard();
    }

    //! Elige un escenario a mano (menú, DOWN, depuración): cancela el guion, si
    //! corría, y aplica el escenario.
    function setDemoScenario(scenario as AccelScenario.Id) as Void {
        _script.cancel();
        applyScenario(scenario);
    }

    //! Cambia el escenario simulado y lo guarda. El escenario empieza desde el
    //! principio (elegir otra vez "Simular cabeceo" repite el cabeceo); el detector no
    //! se reinicia, como al cambiar de postura de verdad.
    private function applyScenario(scenario as AccelScenario.Id) as Void {
        _demo.setScenario(scenario);
        _demoSource.setScenario(_demo.scenario());
        DemoStore.save(_demo);
        WatchUi.requestUpdate();
    }

    // --- Guion automático ---------------------------------------------------------

    //! Empieza el guion desde el paso 1 (movimiento normal). Si la guardia está en
    //! pausa, la inicia (calibra durante el paso 1). Solo con el modo demo activo;
    //! devuelve false si no se pudo empezar.
    function startDemoScript() as Boolean {
        if (!_demo.isEnabled()) {
            return false;
        }
        _script.cancel();
        applyScenario(AccelScenario.NORMAL);
        if (!_state.isActive() && !start()) {
            return false;
        }
        _script.start(System.getTimer());
        logScriptStep();
        WatchUi.requestUpdate();
        return true;
    }

    //! Detiene el guion (menú). El escenario del paso en curso sigue activo.
    function cancelDemoScript() as Void {
        if (_script.cancel()) {
            WatchUi.requestUpdate();
        }
    }

    //! Guion automático (solo lectura para la esfera y el menú).
    function demoScript() as DemoScript {
        return _script;
    }

    //! El guion cambió de paso o terminó: aplica el escenario del paso nuevo; al
    //! terminar vuelve a movimiento normal y muestra el aviso "Guion · Completado".
    private function onScriptStep() as Void {
        logScriptStep();
        if (_script.isFinished()) {
            applyScenario(AccelScenario.NORMAL);
            _toast.show(ToastKind.SCRIPT_DONE, 0, System.getTimer());
            return;
        }
        applyScenario(_script.scenario());
    }

    (:debug)
    private function logScriptStep() as Void {
        System.println(_script.isFinished() ? "GUION terminado"
            : "GUION paso " + _script.stepNumber() + "/" + _script.stepCount() + ": escenario "
                + (_script.scenario() as Number));
    }

    (:release)
    private function logScriptStep() as Void {
    }

    //! Atajo DOWN de la esfera: con el modo demo activo y la guardia en marcha pasa al
    //! siguiente escenario (normal → tecleo → cabeceo → inactividad → normal) y muestra
    //! un aviso de 1,5 s con su nombre. Devuelve false, sin hacer nada, en otro caso.
    function cycleDemoScenario() as Boolean {
        if (!_demo.handlesDownButton(_state.isActive())) {
            return false;
        }
        // Tomar el control a mano cancela el guion (setDemoScenario).
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
