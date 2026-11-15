import Toybox.Lang;

//! Estado visible del detector.
module DetectorState {

    enum Id {
        //! Guardia en pausa: el detector no mira nada.
        IDLE = 0,
        //! Primeros 30 s (5 s en demo): aprende la línea base. Ya detecta eventos, con el
        //! umbral de quietud por defecto.
        CALIBRATING = 1,
        //! Vigilando: sin caída pendiente ni evento reciente.
        WATCHING = 2,
        //! Hubo una sacudida y el movimiento se calmó: se espera la quietud.
        FALL_DETECTED = 3,
        //! Acaba de emitirse un evento (dura lo que el periodo refractario).
        EVENT = 4
    }
}

//! Eventos que emite el detector.
module DrowsinessEvent {

    enum Id {
        NONE = 0,
        //! Cabeceo: sacudida > 400 mg, quietud antes de 5 s y el brazo cambió de postura.
        NOD = 1,
        //! Inactividad prolongada: quietud continua durante T segundos.
        INACTIVITY = 2
    }
}

//! Detector de somnolencia: a partir de un TelemetrySnapshot por lote (1 s) decide si
//! hubo un cabeceo o una inactividad prolongada.
//!
//! **Cabeceo.** Se combinan tres señales y hacen falta las tres:
//!
//! 1. *Sacudida*: el pico del lote (batchPeakJerk) supera NOD_JERK_MIN (400 mg). Abre
//!    una caída candidata y guarda la gravedad de la ventana anterior (la postura de
//!    antes de la caída).
//! 2. *Quietud*: antes de NOD_STILL_WITHIN_MS (5 s) la ventana de 2 s queda quieta
//!    (varianza < umbral). El tecleo da sacudidas igual de fuertes, pero nunca va
//!    seguido de quietud; si pasan 5 s sin ella la candidata se descarta.
//! 3. *Inclinación*: el ángulo entre la gravedad de antes de la caída y la de la ventana
//!    quieta supera NOD_TILT_MIN (35°): el brazo cayó de verdad. Descarta el caso
//!    "sacudida y luego quietud sin cambiar de postura" (dejar de teclear, un golpe en la
//!    mesa): esa candidata se descarta al llegar la quietud.
//!
//! Cada señal descarta un falso positivo distinto: la sacudida, apoyar el brazo despacio;
//! la quietud, el tecleo; la inclinación, quedarse quieto tras un golpe.
//!
//! **Inactividad prolongada.** Quietud continua durante inactivityMs() (60 s; 8 s en
//! modo demo). La quietud se cuenta desde que la ventana está quieta menos los 2 s de la
//! ventana: si toda la ventana está quieta, el brazo lleva al menos 2 s sin moverse.
//!
//! **Periodo refractario.** Tras un evento no se emite otro durante REFRACTORY_MS (10 s)
//! y la cuenta de quietud vuelve a empezar: si el usuario sigue inmóvil, el siguiente
//! evento llega como pronto a los 10 s.
//!
//! **Línea base.** Al empezar calibra la línea base del usuario (Baseline) y después la
//! adapta despacio. Solo le pasa ventanas ordinarias: ni quietas, ni con una caída
//! calmada pendiente, ni de un evento o su refractario. De ella sale el umbral de
//! quietud (stillThreshold). Los eventos no esperan a la calibración: con el umbral por
//! defecto ya funcionan, y perder un cabeceo en los primeros 30 s sería peor.
//!
//! **Sensibilidad (fase 11).** La sacudida, la inclinación y el tiempo de inactividad
//! salen de DetectorThresholds según el ajuste; los valores de abajo son los de la
//! sensibilidad media.
//!
//! El tiempo entra como parámetro (ms, el del lote). Lógica pura: no depende de Sensor,
//! WatchUi ni Graphics.
class DrowsinessDetector {

    //! Sacudida mínima (mg) que abre una caída candidata, con la sensibilidad media. La
    //! que se usa sale de DetectorThresholds (ajuste "Sensibilidad").
    static const NOD_JERK_MIN = 400;

    //! Sacudida máxima (mg) en las últimas muestras del lote para considerar que el
    //! movimiento casi se detuvo tras la caída (estado FALL_DETECTED). Un brazo que cuelga
    //! o descansa da ≈ 10 mg; el movimiento normal, ≈ 70, y el tecleo, más de 400. Así
    //! ni el tecleo ni el movimiento normal que lo sigue muestran "caída detectada".
    static const NOD_CALM_JERK = 50;

    //! Tiempo máximo (ms) entre la sacudida y la quietud.
    static const NOD_STILL_WITHIN_MS = 5000;

    //! Cambio de inclinación mínimo (grados) entre antes y después de la caída
    //! (sensibilidad media).
    static const NOD_TILT_MIN = 35.0f;

    //! Quietud continua (ms) que dispara la inactividad prolongada (sensibilidad media).
    static const INACTIVITY_MS = 60000;

    //! Lo mismo en modo demo, para la sustentación.
    static const INACTIVITY_DEMO_MS = 8000;

    //! Periodo refractario (ms) después de cada evento.
    static const REFRACTORY_MS = 10000;

    //! Quietud que ya se da por hecha al ver la ventana quieta: su duración.
    static const STILL_CREDIT_MS = SlidingWindow.WINDOW_SECONDS * 1000;

    private var _baseline as Baseline;

    //! Umbrales de la sensibilidad elegida (Media: los NOD_JERK_MIN, NOD_TILT_MIN e
    //! INACTIVITY_* de arriba).
    private var _thresholds as DetectorThresholds;

    private var _running as Boolean = false;
    private var _demo as Boolean = false;
    private var _state as DetectorState.Id = DetectorState.IDLE;

    //! Gravedad de la ventana del lote anterior (válida si _hasPrevious).
    private var _hasPrevious as Boolean = false;
    private var _prevX as Float = 0.0f;
    private var _prevY as Float = 0.0f;
    private var _prevZ as Float = 0.0f;

    //! Caída candidata: instante de la sacudida (null si no hay) y gravedad de antes.
    private var _fallMs as Number? = null;
    private var _fallX as Float = 0.0f;
    private var _fallY as Float = 0.0f;
    private var _fallZ as Float = 0.0f;

    //! true si hay caída candidata y el último lote terminó calmado.
    private var _fallCalm as Boolean = false;

    //! Inicio estimado de la quietud actual (null si hay movimiento).
    private var _stillSinceMs as Number? = null;

    //! Instante del último lote.
    private var _lastTimeMs as Number = 0;

    //! Cambio de inclinación (grados) del último lote.
    private var _tilt as Float = 0.0f;

    //! Fin del periodo refractario (null si no hubo evento).
    private var _refractoryUntilMs as Number? = null;

    private var _lastEvent as DrowsinessEvent.Id = DrowsinessEvent.NONE;
    private var _eventCount as Number = 0;

    function initialize() {
        _baseline = new Baseline();
        _thresholds = new DetectorThresholds(SensitivityLevel.MEDIUM);
    }

    //! Cambia la sensibilidad (ajuste "Sensibilidad"). Se aplica desde el lote siguiente
    //! sin reiniciar nada: una caída candidata ya abierta sigue pendiente.
    function setSensitivity(level as SensitivityLevel.Id) as Void {
        _thresholds = new DetectorThresholds(level);
    }

    //! Umbrales en uso (solo lectura).
    function thresholds() as DetectorThresholds {
        return _thresholds;
    }

    //! Empieza a vigilar y a calibrar (al iniciar la guardia). demo: usa los tiempos
    //! del modo demo.
    function start(nowMs as Number, demo as Boolean) as Void {
        reset();
        _running = true;
        _demo = demo;
        _lastTimeMs = nowMs;
        _baseline.start(nowMs, demo ? Baseline.CALIBRATION_DEMO_MS : Baseline.CALIBRATION_MS);
        _state = DetectorState.CALIBRATING;
    }

    //! Olvida todo y deja de vigilar (guardia en pausa).
    function reset() as Void {
        _running = false;
        _baseline.reset();
        _state = DetectorState.IDLE;
        _hasPrevious = false;
        _fallMs = null;
        _fallCalm = false;
        _stillSinceMs = null;
        _tilt = 0.0f;
        _refractoryUntilMs = null;
        _lastEvent = DrowsinessEvent.NONE;
        _eventCount = 0;
    }

    //! Se perdieron lotes (SensorWatchdog: más de 5 s sin datos) y acaban de volver. Lo
    //! que se vio antes del corte ya no vale: olvida la quietud (la inactividad vuelve a
    //! contar desde cero, para no tomar el corte por un brazo inmóvil), la caída
    //! candidata y la postura anterior. Conserva la línea base, la calibración y el
    //! refractario.
    function onDataGap() as Void {
        _hasPrevious = false;
        _fallMs = null;
        _fallCalm = false;
        _stillSinceMs = null;
        _tilt = 0.0f;
    }

    //! Procesa el snapshot del lote que terminó en timeMs y devuelve el evento emitido
    //! (NONE casi siempre).
    function update(snapshot as TelemetrySnapshot, timeMs as Number) as DrowsinessEvent.Id {
        if (!_running) {
            return DrowsinessEvent.NONE;
        }
        _lastTimeMs = timeMs;
        if (!snapshot.windowFull) {
            // Con menos de 2 s de datos no hay varianza ni gravedad fiables.
            _baseline.observe(null, timeMs);
            _state = currentState(timeMs);
            return DrowsinessEvent.NONE;
        }

        var gx = snapshot.gravityX;
        var gy = snapshot.gravityY;
        var gz = snapshot.gravityZ;

        // 1. Sacudida: abre (o renueva) la caída candidata con la postura de antes.
        if (snapshot.batchPeakJerk >= _thresholds.nodJerkMin) {
            _fallMs = timeMs;
            if (_hasPrevious) {
                _fallX = _prevX;
                _fallY = _prevY;
                _fallZ = _prevZ;
            } else {
                _fallX = gx;
                _fallY = gy;
                _fallZ = gz;
            }
        }
        var fallMs = _fallMs;
        if (fallMs != null && timeMs - fallMs > NOD_STILL_WITHIN_MS) {
            _fallMs = null;
        }

        // 2. Quietud.
        var still = snapshot.variance < stillThreshold();
        if (!still) {
            _stillSinceMs = null;
        } else if (_stillSinceMs == null) {
            _stillSinceMs = timeMs - STILL_CREDIT_MS;
        }

        // 3. Inclinación: desde antes de la caída si hay una pendiente; si no, respecto
        // al lote anterior.
        var pending = _fallMs != null;
        if (pending) {
            _tilt = Tilt.angleDegrees(_fallX, _fallY, _fallZ, gx, gy, gz);
        } else if (_hasPrevious) {
            _tilt = Tilt.angleDegrees(_prevX, _prevY, _prevZ, gx, gy, gz);
        } else {
            _tilt = 0.0f;
        }
        _prevX = gx;
        _prevY = gy;
        _prevZ = gz;
        _hasPrevious = true;

        // 4. Eventos.
        var event = decide(timeMs, still, pending);
        if (event != DrowsinessEvent.NONE) {
            _lastEvent = event;
            _eventCount += 1;
            _refractoryUntilMs = timeMs + REFRACTORY_MS;
            _fallMs = null;
            if (still) {
                _stillSinceMs = timeMs;
            }
        }
        // La candidata pudo descartarse o consumirse en decide().
        _fallCalm = _fallMs != null && snapshot.jerk < NOD_CALM_JERK;

        // 5. Línea base: solo con ventanas ordinarias (el umbral nuevo rige desde el
        // lote siguiente).
        var ordinary = event == DrowsinessEvent.NONE && !still && !_fallCalm && canEmit(timeMs);
        _baseline.observe(ordinary ? snapshot.variance : null, timeMs);
        _state = currentState(timeMs);
        return event;
    }

    //! Decide el evento del lote. Durante el refractario la caída candidata sigue viva
    //! (puede dispararse al terminar, si no caducó) pero no se emite nada.
    private function decide(timeMs as Number, still as Boolean, pending as Boolean) as DrowsinessEvent.Id {
        var blocked = !canEmit(timeMs);
        if (pending && still) {
            if (_tilt < _thresholds.nodTiltMin) {
                // Quietud sin cambio de postura: no fue una caída del brazo.
                _fallMs = null;
            } else if (!blocked) {
                return DrowsinessEvent.NOD;
            }
        }
        var since = _stillSinceMs;
        if (!blocked && since != null && timeMs - since >= inactivityMs()) {
            return DrowsinessEvent.INACTIVITY;
        }
        return DrowsinessEvent.NONE;
    }

    //! false durante el periodo refractario.
    private function canEmit(timeMs as Number) as Boolean {
        var until = _refractoryUntilMs;
        return until == null || timeMs >= until;
    }

    private function currentState(timeMs as Number) as DetectorState.Id {
        if (!_running) {
            return DetectorState.IDLE;
        }
        if (!canEmit(timeMs)) {
            return DetectorState.EVENT;
        }
        if (_fallCalm) {
            return DetectorState.FALL_DETECTED;
        }
        if (_baseline.isCalibrating()) {
            return DetectorState.CALIBRATING;
        }
        return DetectorState.WATCHING;
    }

    // --- Lectura ----------------------------------------------------------------

    function state() as DetectorState.Id {
        return _state;
    }

    function isRunning() as Boolean {
        return _running;
    }

    function isDemo() as Boolean {
        return _demo;
    }

    //! Varianza (mg²) por debajo de la cual la ventana cuenta como quieta: la adapta la
    //! línea base (100 mientras calibra).
    function stillThreshold() as Float {
        return _baseline.stillThreshold();
    }

    //! Línea base del usuario (solo lectura para las vistas y las pruebas).
    function baseline() as Baseline {
        return _baseline;
    }

    //! true mientras calibra la línea base.
    function isCalibrating() as Boolean {
        return _running && _baseline.isCalibrating();
    }

    //! Quietud continua que dispara la inactividad (ms): 60 s, o 8 s en modo demo, con la
    //! sensibilidad media (DetectorThresholds).
    function inactivityMs() as Number {
        return _demo ? _thresholds.inactivityDemoMs : _thresholds.inactivityMs;
    }

    //! Segundos de quietud continua hasta el último lote (0 si hay movimiento).
    function stillSeconds() as Float {
        var since = _stillSinceMs;
        return since == null ? 0.0f : (_lastTimeMs - since) / 1000.0f;
    }

    //! Cambio de inclinación (grados) del último lote: desde antes de la caída si hay
    //! una pendiente, si no respecto al lote anterior.
    function tiltDegrees() as Float {
        return _tilt;
    }

    //! true si hubo una sacudida hace menos de 5 s y el movimiento ya se calmó: se está
    //! esperando la quietud para confirmar el cabeceo.
    function isFallPending() as Boolean {
        return _fallCalm;
    }

    //! Instante de la sacudida de la caída candidata (null si no hay).
    function fallMs() as Number? {
        return _fallMs;
    }

    function lastEvent() as DrowsinessEvent.Id {
        return _lastEvent;
    }

    //! Eventos emitidos desde start().
    function eventCount() as Number {
        return _eventCount;
    }
}
