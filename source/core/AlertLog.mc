import Toybox.Lang;

//! Una alerta respondida: motivo, nivel, inicio y tiempo de respuesta.
class AlertRecord {

    var reason as DrowsinessEvent.Id;
    var level as Number;

    //! Inicio de la alerta (ms, System.getTimer() en la app).
    var startMs as Number;

    //! Tiempo hasta "Estoy despierto" (ms).
    var responseMs as Number;

    function initialize(reason as DrowsinessEvent.Id, level as Number, startMs as Number,
            responseMs as Number) {
        self.reason = reason;
        self.level = level;
        self.startMs = startMs;
        self.responseMs = responseMs;
    }
}

//! Alertas respondidas durante la sesión, solo en memoria (el historial persistente en
//! Application.Storage es de la fase siguiente). Guarda como mucho CAPACITY: al llenarse
//! descarta la más antigua, para que una guardia muy larga no agote la memoria.
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

    //! Media de los tiempos de respuesta (ms); 0 si no hay alertas.
    function averageResponseMs() as Number {
        if (_records.size() == 0) {
            return 0;
        }
        var total = 0;
        for (var i = 0; i < _records.size(); i++) {
            total += _records[i].responseMs;
        }
        return total / _records.size();
    }

    function clear() as Void {
        _records = [] as Array<AlertRecord>;
    }
}
