import Toybox.Application;
import Toybox.Lang;

//! Guarda y recupera la configuración del modo demo (DemoConfig) en
//! Application.Storage, para que siga igual al volver a abrir la app (en el reloj y en
//! el simulador).
module DemoStore {

    //! Clave en Storage. El valor es el diccionario de DemoConfig.toStorage().
    const KEY = "demoConfig";

    //! Configuración guardada, o la de por defecto si no hay o no se puede leer.
    function load() as DemoConfig {
        try {
            return DemoConfig.fromStorage(Application.Storage.getValue(KEY));
        } catch (e instanceof Lang.Exception) {
            return new DemoConfig();
        }
    }

    //! Guarda la configuración. Sin almacenamiento, el cambio dura hasta cerrar la app.
    function save(config as DemoConfig) as Void {
        try {
            Application.Storage.setValue(KEY,
                config.toStorage() as Dictionary<Application.Storage.KeyType, Application.Storage.ValueType>);
        } catch (e instanceof Lang.Exception) {
            // Storage lleno o no disponible: se sigue con la configuración en memoria.
        }
    }
}
