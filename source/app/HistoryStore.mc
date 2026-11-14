import Toybox.Application;
import Toybox.Lang;

//! Guarda y recupera el historial de guardias (SessionHistory) en Application.Storage,
//! para que siga ahí al volver a abrir la app. Mismo patrón que DemoStore: si Storage
//! falla, se sigue con lo que hay en memoria.
module HistoryStore {

    //! Clave en Storage. El valor es el diccionario de SessionHistory.toStorage().
    const KEY = "history";

    //! Historial guardado, o uno vacío si no hay o no se puede leer.
    function load() as SessionHistory {
        try {
            return SessionHistory.fromStorage(Application.Storage.getValue(KEY));
        } catch (e instanceof Lang.Exception) {
            return new SessionHistory();
        }
    }

    function save(history as SessionHistory) as Void {
        try {
            Application.Storage.setValue(KEY,
                history.toStorage() as Dictionary<Application.Storage.KeyType, Application.Storage.ValueType>);
        } catch (e instanceof Lang.Exception) {
            // Storage lleno o no disponible: el historial dura hasta cerrar la app.
        }
    }

    //! Borra el historial guardado.
    function clear() as Void {
        try {
            Application.Storage.deleteValue(KEY);
        } catch (e instanceof Lang.Exception) {
            // Nada que borrar o Storage no disponible.
        }
    }
}
