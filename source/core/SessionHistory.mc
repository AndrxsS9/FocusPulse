import Toybox.Lang;

//! Historial de guardias: los resúmenes (GuardSummary) de las últimas CAPACITY (10)
//! guardias, de la más reciente (0) a la más antigua.
//!
//! - add() pone la nueva al principio y descarta la más antigua si ya había 10: el
//!   tamaño es fijo, así que el historial nunca crece en memoria ni en Storage
//!   (10 × 7 valores simples).
//! - toStorage() da { "v" => VERSION, "items" => [[…], …] }. fromStorage() acepta
//!   cualquier cosa: sin datos, otro tipo, otra versión o una lista que no es lista dan
//!   un historial vacío; un resumen dañado se salta sin perder los demás; si vinieran
//!   más de 10, se quedan los 10 primeros (los más recientes).
//!
//! Lógica pura: sin Application.Storage (lo usa HistoryStore, en source/app).
class SessionHistory {

    //! Máximo de guardias guardadas.
    static const CAPACITY = 10;

    //! Versión del formato guardado. Cambiarla si cambia GuardSummary.toStorage():
    //! los datos de la versión anterior se descartan en vez de leerse mal.
    static const VERSION = 1;

    static const KEY_VERSION = "v";
    static const KEY_ITEMS = "items";

    private var _items as Array<GuardSummary>;

    function initialize() {
        _items = [] as Array<GuardSummary>;
    }

    //! Agrega la guardia más reciente (al principio).
    function add(summary as GuardSummary) as Void {
        var items = [summary] as Array<GuardSummary>;
        var keep = _items.size() < CAPACITY ? _items.size() : CAPACITY - 1;
        for (var i = 0; i < keep; i++) {
            items.add(_items[i]);
        }
        _items = items;
    }

    function size() as Number {
        return _items.size();
    }

    function isEmpty() as Boolean {
        return _items.size() == 0;
    }

    //! Guardia i: 0 es la más reciente.
    function get(i as Number) as GuardSummary {
        return _items[i];
    }

    function clear() as Void {
        _items = [] as Array<GuardSummary>;
    }

    //! Diccionario para Application.Storage.
    function toStorage() as Dictionary<String, Number or Array> {
        var items = [] as Array<Array<Number or Boolean> >;
        for (var i = 0; i < _items.size(); i++) {
            items.add(_items[i].toStorage());
        }
        return { KEY_VERSION => VERSION, KEY_ITEMS => items } as Dictionary<String, Number or Array>;
    }

    //! Historial a partir de lo leído de Storage (ver arriba qué pasa con datos malos).
    static function fromStorage(data as Object?) as SessionHistory {
        var history = new SessionHistory();
        if (!(data instanceof Dictionary)) {
            return history;
        }
        var dict = data as Dictionary<String, Object?>;
        var version = dict.get(KEY_VERSION);
        var items = dict.get(KEY_ITEMS);
        if (!(version instanceof Number) || version != VERSION || !(items instanceof Array)) {
            return history;
        }
        var list = items as Array<Object?>;
        // Se leen de la más antigua a la más reciente para que add() conserve el orden.
        var last = list.size() < CAPACITY ? list.size() : CAPACITY;
        for (var i = last - 1; i >= 0; i--) {
            var summary = GuardSummary.fromStorage(list[i]);
            if (summary != null) {
                history.add(summary);
            }
        }
        return history;
    }
}
