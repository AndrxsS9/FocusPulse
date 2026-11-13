import Toybox.Lang;
import Toybox.Sensor;
import Toybox.System;

//! Fuente real: acelerómetro del reloj con `Sensor.registerSensorDataListener`.
//!
//! Pide solo el acelerómetro (sin pitch, roll, power ni timestamps) a
//! SlidingWindow.SAMPLE_RATE_HZ (25 Hz) en lotes de PERIOD_SECONDS (1 s): 25 muestras
//! por lote. Si el dispositivo admite menos, usa su máximo
//! (`getMaxSampleRateForSensorType`, 100 Hz en el fr165).
//!
//! Si el sensor no existe, el registro lanza una excepción o el máximo es 0, start()
//! devuelve false y la app sigue funcionando (la guardia muestra "Sensor no disponible").
//!
//! Solo puede haber un listener de datos de sensor por app: no crear dos instancias
//! en marcha a la vez.
class RealAccelSource extends AccelSource {

    //! Duración de cada lote (s). El máximo del SDK es 4 s; 1 s da una latencia baja.
    static const PERIOD_SECONDS = 1;

    private var _sampleRate as Number = SlidingWindow.SAMPLE_RATE_HZ;

    function initialize() {
        AccelSource.initialize();
    }

    function start() as Boolean {
        if (_running) {
            return true;
        }
        if (!(Toybox has :Sensor) || !(Sensor has :registerSensorDataListener)) {
            return false;
        }

        var rate = SlidingWindow.SAMPLE_RATE_HZ;
        if (Sensor has :getMaxSampleRateForSensorType) {
            var max = Sensor.getMaxSampleRateForSensorType(:accelerometer);
            if (max <= 0) {
                return false;
            }
            if (max < rate) {
                rate = max;
            }
        }

        try {
            Sensor.registerSensorDataListener(method(:onSensorData), {
                :period => PERIOD_SECONDS,
                :accelerometer => {
                    :enabled => true,
                    :sampleRate => rate
                }
            });
        } catch (e instanceof Lang.Exception) {
            System.println("RealAccelSource: " + e.getErrorMessage());
            return false;
        }

        _sampleRate = rate;
        _running = true;
        return true;
    }

    function stop() as Void {
        if (_running) {
            Sensor.unregisterSensorDataListener();
        }
        _running = false;
    }

    function sampleRateHz() as Number {
        return _sampleRate;
    }

    //! Callback del sistema con cada lote.
    function onSensorData(data as Sensor.SensorData) as Void {
        if (!_running) {
            return;
        }
        var accel = data.accelerometerData;
        if (accel == null) {
            return;
        }
        deliver(accel.x, accel.y, accel.z, System.getTimer());
    }
}
