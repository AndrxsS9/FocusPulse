import Toybox.Lang;

//! Confirmación de los cabeceos del detector por el modelo (fase 11, ajuste
//! "Confirmación por IA", activado por defecto).
//!
//! El detector por reglas (DrowsinessDetector) da un evento CABECEO con sacudida, quietud
//! e inclinación. Con datos sintéticos, eso también pasa al mirar la hora justo después
//! de teclear (15 de 24 secuencias de prueba): el giro de la muñeca y el brazo sostenido
//! cumplen las tres reglas. La diferencia llega un par de segundos después: el brazo que
//! cayó dormido queda inerte y el clasificador pasa a Inerte; el que mira la hora vuelve
//! a Normal.
//!
//! Por eso un CABECEO no abre la alerta en el acto: se retiene DELAY_BATCHES lotes (2 s)
//! y se confirma solo si entonces la probabilidad **suavizada de Normal** del
//! clasificador (StateClassifier) es menor que NORMAL_MAX; si no, se descarta. La
//! INACTIVIDAD no pasa por el modelo: sale en el acto. Con el ajuste desactivado, el
//! CABECEO también sale en el acto (comportamiento de las fases 6–10).
//!
//! Retardo y umbral los eligió ml/confirmation.py con los usuarios de entrenamiento del
//! dataset sintético (el menor umbral que no pierde ningún cabeceo). En los 12 usuarios de
//! prueba: falsos cabeceos al mirar la hora 15 → 3 de 24 y cabeceos reales 22 → 22 de 36
//! (ml/reports/confirmation.md, docs/IA.md §12). La alerta de cabeceo llega 2 s más tarde.
//!
//! Uso, una vez por lote y después de StateClassifier.update (así p(Normal) ya incluye el
//! lote): update(evento del detector, p(Normal) suavizada) devuelve el evento que abre la
//! alerta en este lote. Lógica pura: no depende de Sensor, WatchUi ni Graphics.
class NodConfirmation {

    //! Lotes (1 s cada uno) que se espera tras el CABECEO antes de decidir.
    static const DELAY_BATCHES = 2;

    //! Se confirma si la p(Normal) suavizada en ese lote es menor que esto.
    static const NORMAL_MAX = 0.35f;

    private var _enabled as Boolean = true;

    //! Lotes que faltan para decidir el CABECEO pendiente (0: no hay ninguno).
    private var _pendingBatches as Number = 0;

    private var _confirmed as Number = 0;
    private var _rejected as Number = 0;

    //! p(Normal) con que se decidió el último CABECEO (-1 si aún no hubo).
    private var _lastNormal as Float = -1.0f;

    function initialize() {
    }

    //! Activa o desactiva la confirmación (ajuste). Si se desactiva con un CABECEO
    //! pendiente, sale en el lote siguiente sin esperar al modelo.
    function setEnabled(enabled as Boolean) as Void {
        _enabled = enabled;
    }

    function isEnabled() as Boolean {
        return _enabled;
    }

    //! Olvida el CABECEO pendiente y las cuentas (al iniciar o pausar la guardia).
    function reset() as Void {
        _pendingBatches = 0;
        _confirmed = 0;
        _rejected = 0;
        _lastNormal = -1.0f;
    }

    //! Recibe el evento del detector de este lote y la p(Normal) suavizada del
    //! clasificador tras este lote. Devuelve el evento que debe abrir la alerta ahora.
    function update(event as DrowsinessEvent.Id, pNormal as Float) as DrowsinessEvent.Id {
        if (event == DrowsinessEvent.INACTIVITY) {
            return event;
        }
        if (event == DrowsinessEvent.NOD) {
            if (!_enabled) {
                return event;
            }
            _pendingBatches = DELAY_BATCHES;
            return _pendingBatches == 0 ? decide(pNormal) : DrowsinessEvent.NONE;
        }
        if (_pendingBatches == 0) {
            return DrowsinessEvent.NONE;
        }
        if (!_enabled) {
            _pendingBatches = 0;
            return DrowsinessEvent.NOD;
        }
        _pendingBatches -= 1;
        return _pendingBatches == 0 ? decide(pNormal) : DrowsinessEvent.NONE;
    }

    private function decide(pNormal as Float) as DrowsinessEvent.Id {
        _lastNormal = pNormal;
        if (pNormal < NORMAL_MAX) {
            _confirmed += 1;
            return DrowsinessEvent.NOD;
        }
        _rejected += 1;
        return DrowsinessEvent.NONE;
    }

    //! true mientras un CABECEO espera al modelo.
    function isPending() as Boolean {
        return _pendingBatches > 0;
    }

    //! Cabeceos confirmados y descartados desde reset().
    function confirmedCount() as Number {
        return _confirmed;
    }

    function rejectedCount() as Number {
        return _rejected;
    }

    //! p(Normal) con que se decidió el último CABECEO (-1 si aún no hubo).
    function lastNormal() as Float {
        return _lastNormal;
    }
}
