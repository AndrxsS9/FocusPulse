import Toybox.Lang;

//! Banco de pruebas del detector: fuente simulada → TelemetryEngine → DrowsinessDetector
//! → StateClassifier, en el mismo orden que GuardController.onBatch. Un paso es un lote de 1 s; la guardia
//! empieza en t = 0 y el lote i termina en i × 1000 ms, así que el tiempo está controlado.
(:test)
class DetectorRig {

    var source as SimulatedAccelSource;
    var engine as TelemetryEngine;
    var detector as DrowsinessDetector;
    var classifier as StateClassifier;

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
