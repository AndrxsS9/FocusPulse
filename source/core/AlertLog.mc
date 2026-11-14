import Toybox.Lang;

//! Una alerta (un episodio): motivo, nivel máximo alcanzado, inicio y tiempo de
//! respuesta (null si se cerró sin respuesta, al pausar la guardia).
class AlertRecord {

    var reason as DrowsinessEvent.Id;

    //! Nivel más alto al que llegó la alerta antes de la respuesta (1–3): con el
    //! escalamiento, una alerta que abrió en el 1 y se respondió en el 3 guarda 3.
    var maxLevel as Number;

    //! Inicio de la alerta (ms). La guardia lo guarda desde su propio inicio, que es la
    //! escala que usa FatiguePredictor.
    var startMs as Number;

    //! Tiempo hasta "Estoy despierto" (ms); null si nadie respondió.
    var responseMs as Number?;

    function initialize(reason as DrowsinessEvent.Id, maxLevel as Number, startMs as Number,
            responseMs as Number?) {
        self.reason = reason;
        self.maxLevel = maxLevel;
        self.startMs = startMs;
        self.responseMs = responseMs;
    }
}

//! Alertas (episodios) de una guardia, solo en memoria; el historial persistente guarda
//! solo el resumen de cada guardia (SessionHistory). Guarda como mucho CAPACITY: al
//! llenarse descarta la más antigua, para que una guardia muy larga no agote la memoria.
//!
//! Lógica pura: sin WatchUi, Graphics ni Storage.
class AlertLog {

    //! Máximo de alertas guardadas.
    static const CAPACITY = 32;

    private var _records as Array<AlertRecord>;

    function initialize() {
        _records = [] as Array<AlertRecord>;
    }

    //! Agrega una alerta respondida (si está lleno, descarta la más antigua).
    function add(record as AlertRecord) as Void {
        if (_records.size() >= CAPACITY) {
            _records = _records.slice(1, null);
        }
        _records.add(record);
    }

    function size() as Number {
        return _records.size();
    }

    //! Alerta i, de la más antigua (0) a la más reciente.
    function get(i as Number) as AlertRecord {
        return _records[i];
    }

    //! La alerta más reciente (null si no hay ninguna).
    function last() as AlertRecord? {
        return _records.size() > 0 ? _records[_records.size() - 1] : null;
    }

    //! Media de los tiempos de respuesta (ms) de las alertas respondidas; 0 si no hay
    //! ninguna respondida.
    function averageResponseMs() as Number {
        var total = 0;
        var count = 0;
        for (var i = 0; i < _records.size(); i++) {
            var response = _records[i].responseMs;
            if (response != null) {
                total += response;
                count += 1;
            }
        }
        return count > 0 ? total / count : 0;
    }

    //! Alertas con tiempo de respuesta.
    function answeredCount() as Number {
        var count = 0;
        for (var i = 0; i < _records.size(); i++) {
            if (_records[i].responseMs != null) {
                count += 1;
            }
        }
        return count;
    }

    //! Nivel más alto que alcanzó alguna alerta del registro (0 si no hay alertas).
    function maxLevel() as Number {
        var max = 0;
        for (var i = 0; i < _records.size(); i++) {
            if (_records[i].maxLevel > max) {
                max = _records[i].maxLevel;
            }
        }
        return max;
    }

    function clear() as Void {
        _records = [] as Array<AlertRecord>;
    }
}
