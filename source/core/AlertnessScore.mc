import Toybox.Lang;

//! Puntaje de alerta provisional (v1), de 0 (dormido) a 100 (bien despierto).
//!
//! Se actualiza con cada lote de telemetría a partir del snapshot y del tiempo
//! transcurrido desde el lote anterior (dt, en segundos):
//!
//! | Situación | Condición | Efecto |
//! |---|---|---|
//! | Actividad alta | varianza > ACTIVE_VARIANCE (1500 mg²) | sube ACTIVE_RISE_PER_S |
//! | Quietud | ventana quieta (varianza < SlidingWindow.STILL_VARIANCE_MAX, 100 mg²) | baja STILL_DROP_PER_S |
//! | Movimiento normal | el resto | se acerca a NORMAL_TARGET a NORMAL_PULL_PER_S |
//!
//! Todas las tasas son lineales y por segundo, así que el resultado no depende de la
//! frecuencia de muestreo ni de cómo se partan los lotes: dos pasos de 1 s dan lo mismo
//! que uno de 2 s. Mientras la ventana no está llena (los primeros 2 s) no cambia.
//!
//! Empieza en INITIAL al iniciar la guardia (reset) y se congela en pausa
//! (setActive(false)). Es provisional: el detector de cabeceos lo reemplazará.
//!
//! Lógica pura: no depende de Sensor, WatchUi ni Graphics.
class AlertnessScore {

    //! Puntaje al iniciar la guardia.
    static const INITIAL = 88.0f;

    //! Valor al que tiende con movimiento normal.
    static const NORMAL_TARGET = 85.0f;

    //! Varianza de la magnitud (mg²) por encima de la cual hay actividad alta (tecleo).
    static const ACTIVE_VARIANCE = 1500.0f;

    //! Puntos por segundo que sube con actividad alta.
    static const ACTIVE_RISE_PER_S = 3.0f;

    //! Puntos por segundo que baja en quietud: de 85 a la banda ámbar (< 60) en unos
    //! 12 s y a la roja (< 35) en unos 25 s.
    static const STILL_DROP_PER_S = 2.0f;

    //! Puntos por segundo con los que se acerca a NORMAL_TARGET con movimiento normal.
    static const NORMAL_PULL_PER_S = 1.5f;

    static const MIN = 0.0f;
    static const MAX = 100.0f;

    private var _value as Float = INITIAL;
    private var _active as Boolean = false;

    function initialize() {
    }

    //! Vuelve al valor inicial y activa la actualización (al iniciar la guardia).
    function reset() as Void {
        _value = INITIAL;
        _active = true;
    }

    //! false congela el puntaje (guardia en pausa); true lo reanuda sin reiniciarlo.
    function setActive(active as Boolean) as Void {
        _active = active;
    }

    function isActive() as Boolean {
        return _active;
    }

    //! Aplica dtSeconds de telemetría y devuelve el puntaje (0–100, entero).
    function update(snapshot as TelemetrySnapshot, dtSeconds as Float) as Number {
        if (!_active || dtSeconds <= 0.0f || !snapshot.windowFull) {
            return value();
        }

        if (snapshot.variance > ACTIVE_VARIANCE) {
            _value += ACTIVE_RISE_PER_S * dtSeconds;
        } else if (snapshot.isStill) {
            _value -= STILL_DROP_PER_S * dtSeconds;
        } else {
            var step = NORMAL_PULL_PER_S * dtSeconds;
            var distance = NORMAL_TARGET - _value;
            if (distance > step) {
                _value += step;
            } else if (distance < -step) {
                _value -= step;
            } else {
                _value = NORMAL_TARGET;
            }
        }

        if (_value < MIN) {
            _value = MIN;
        } else if (_value > MAX) {
            _value = MAX;
        }
        return value();
    }

    //! Puntaje actual redondeado (0–100).
    function value() as Number {
        return (_value + 0.5f).toNumber();
    }

    //! Puntaje actual sin redondear (para las pruebas).
    function exactValue() as Float {
        return _value;
    }
}
