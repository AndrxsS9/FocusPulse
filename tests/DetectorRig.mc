import Toybox.Lang;

//! Banco de pruebas del detector: fuente simulada → TelemetryEngine → DrowsinessDetector
//! → StateClassifier → NodConfirmation → AlertnessScore, en el mismo orden que
//! GuardController.onBatch. nods/inactivities cuentan los eventos del detector; alertNods,
//! los cabeceos que abrirían la alerta (tras la confirmación, activada por defecto). Un paso es un lote de 1 s; la guardia
//! empieza en t = 0 y el lote i termina en i × 1000 ms, así que el tiempo está controlado.
(:test)
class DetectorRig {

    var source as SimulatedAccelSource;
    var engine as TelemetryEngine;
    var detector as DrowsinessDetector;
    var classifier as StateClassifier;
    var confirmation as NodConfirmation;

    //! Evento que abriría la alerta en el último lote (tras la confirmación).
    var alertEvent as DrowsinessEvent.Id = DrowsinessEvent.NONE;
    var alertNods as Number = 0;
    var firstAlertNodMs as Number? = null;

    //! Puntaje de alerta, ya iniciado (88). Se puede reemplazar para partir de otro valor.
    var score as AlertnessScore;

    //! Instante del último lote (ms).
    var timeMs as Number = 0;

    var nods as Number = 0;
    var inactivities as Number = 0;
    var firstNodMs as Number? = null;
    var firstInactivityMs as Number? = null;

    //! Instantes de todos los eventos, en orden.
    var eventTimes as Array<Number>;

    //! Mayor sacudida de lote vista y número de lotes con sacudida >= 400 mg.
    var maxPeakJerk as Number = 0;
    var jerkBatches as Number = 0;

    function initialize(scenario as AccelScenario.Id, seed as Number, demo as Boolean) {
        source = new SimulatedAccelSource(scenario, seed);
        engine = new TelemetryEngine();
        detector = new DrowsinessDetector();
        detector.start(0, demo);
        classifier = new StateClassifier();
        confirmation = new NodConfirmation();
        score = new AlertnessScore();
        score.reset();
        eventTimes = [] as Array<Number>;
    }

    //! Entrega un lote de 1 s y devuelve el evento emitido.
    function step() as DrowsinessEvent.Id {
        timeMs += 1000;
        var batch = source.nextBatch(SlidingWindow.SAMPLE_RATE_HZ);
        engine.addBatch(batch[0], batch[1], batch[2], timeMs);
        var snapshot = engine.snapshot();
        if (snapshot.batchPeakJerk > maxPeakJerk) {
            maxPeakJerk = snapshot.batchPeakJerk;
        }
        if (snapshot.batchPeakJerk >= DrowsinessDetector.NOD_JERK_MIN) {
            jerkBatches += 1;
        }
        var event = detector.update(snapshot, timeMs);
        classifier.update(snapshot, detector);
        alertEvent = confirmation.update(event, classifier.probability(DrowsinessClass.NORMAL));
        if (alertEvent == DrowsinessEvent.NOD) {
            alertNods += 1;
            if (firstAlertNodMs == null) {
                firstAlertNodMs = timeMs;
            }
        }
        score.update(classifier.isReady() ? classifier.probabilities() : null, 1.0f);
        if (event == DrowsinessEvent.NOD) {
            nods += 1;
            if (firstNodMs == null) {
                firstNodMs = timeMs;
            }
        } else if (event == DrowsinessEvent.INACTIVITY) {
            inactivities += 1;
            if (firstInactivityMs == null) {
                firstInactivityMs = timeMs;
            }
        }
        if (event != DrowsinessEvent.NONE) {
            eventTimes.add(timeMs);
        }
        return event;
    }

    //! Snapshot de ventana llena con los valores dados, para alimentar el detector sin
    //! muestras (las pruebas de umbrales).
    static function snapshot(variance as Float, peakJerk as Number, jerk as Number,
            gx as Float, gy as Float, gz as Float) as TelemetrySnapshot {
        var s = new TelemetrySnapshot();
        s.windowFull = true;
        s.variance = variance;
        s.batchPeakJerk = peakJerk;
        s.jerk = jerk;
        s.gravityX = gx;
        s.gravityY = gy;
        s.gravityZ = gz;
        return s;
    }

    //! Mirar la hora justo después de teclear: 8 s de tecleo y, a continuación, el
    //! escenario GLANCE desde el giro (sin su movimiento normal previo), con el tiempo en
    //! 8 s. El detector por reglas lo toma por cabeceo (NodConfirmationTest).
    static function glanceAfterTyping(seed as Number) as DetectorRig {
        var rig = new DetectorRig(AccelScenario.TYPING, seed, true);
        rig.run(8);
        var glance = new SimulatedAccelSource(AccelScenario.GLANCE, seed + 100);
        glance.nextBatch(SimulatedAccelSource.GLANCE_RAISE_START);
        rig.source = glance;
        return rig;
    }

    //! Corte de datos: pasan seconds sin lotes (el tiempo avanza, la fuente no). Con
    //! handled, al volver los datos se hace lo mismo que GuardController.onSensorDataBack:
    //! ventana, detector (quietud, caída y postura), clasificador y confirmación desde cero.
    function gap(seconds as Number, handled as Boolean) as Void {
        timeMs += seconds * 1000;
        if (handled) {
            engine.reset();
            detector.onDataGap();
            classifier.reset();
            confirmation.reset();
        }
    }

    //! Entrega seconds lotes.
    function run(seconds as Number) as Void {
        for (var i = 0; i < seconds; i++) {
            step();
        }
    }

    function events() as Number {
        return nods + inactivities;
    }

    //! Suma el lote actual a una matriz de confusión matrix[real][predicha], si el
    //! clasificador ya opina (el primer lote no llena la ventana).
    function countInto(matrix as Array<Array<Number>>, real as DrowsinessClass.Id) as Void {
        if (classifier.isReady()) {
            matrix[real as Number][classifier.topClass() as Number] += 1;
        }
    }
}
