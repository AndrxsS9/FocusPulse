import Toybox.Lang;
import Toybox.Math;

//! Búfer circular de tamaño fijo para muestras del acelerómetro.
//!
//! Guarda x, y, z en mili‑g (1000 = 1 g) y la magnitud del vector, redondeada a mg
//! enteros. La magnitud se guarda como entero para que la ventana deslizante pueda
//! sumar y restar sin errores de redondeo acumulados (ver SlidingWindow).
//!
//! Los índices van de 0 (muestra más antigua) a size() - 1 (la más reciente).
//! Al llenarse, cada muestra nueva reemplaza a la más antigua. No reserva memoria
//! después de initialize().
//!
//! Lógica pura: no depende de Sensor, WatchUi ni Graphics.
class RingBuffer {

    private var _capacity as Number;
    private var _x as Array<Number>;
    private var _y as Array<Number>;
    private var _z as Array<Number>;
    private var _magnitude as Array<Number>;

    //! Posición donde se escribirá la próxima muestra.
    private var _head as Number = 0;

    //! Número de muestras válidas (como máximo _capacity).
    private var _size as Number = 0;

    //! capacity: número máximo de muestras (> 0).
    function initialize(capacity as Number) {
        if (capacity < 1) {
            capacity = 1;
        }
        _capacity = capacity;
        _x = filledArray(capacity);
        _y = filledArray(capacity);
        _z = filledArray(capacity);
        _magnitude = filledArray(capacity);
    }

    //! Magnitud del vector (x, y, z) en mg, redondeada al entero más cercano.
    static function magnitudeOf(x as Number, y as Number, z as Number) as Number {
        var sq = x.toLong() * x + y.toLong() * y + z.toLong() * z;
        return (Math.sqrt(sq.toDouble()) + 0.5d).toNumber();
    }

    //! Agrega una muestra. Si el búfer está lleno, descarta la más antigua.
    function push(x as Number, y as Number, z as Number) as Void {
        _x[_head] = x;
        _y[_head] = y;
        _z[_head] = z;
        _magnitude[_head] = magnitudeOf(x, y, z);
        _head = (_head + 1) % _capacity;
        if (_size < _capacity) {
            _size += 1;
        }
    }

    //! Vacía el búfer sin liberar memoria.
    function clear() as Void {
        _head = 0;
        _size = 0;
    }

    function size() as Number {
        return _size;
    }

    function capacity() as Number {
        return _capacity;
    }

    function isEmpty() as Boolean {
        return _size == 0;
    }

    function isFull() as Boolean {
        return _size == _capacity;
    }

    //! Eje x de la muestra i (0 = más antigua).
    function x(i as Number) as Number {
        return _x[slot(i)];
    }

    //! Eje y de la muestra i (0 = más antigua).
    function y(i as Number) as Number {
        return _y[slot(i)];
    }

    //! Eje z de la muestra i (0 = más antigua).
    function z(i as Number) as Number {
        return _z[slot(i)];
    }

    //! Magnitud de la muestra i (0 = más antigua).
    function magnitude(i as Number) as Number {
        return _magnitude[slot(i)];
    }

    //! Índice de la muestra más reciente (-1 si está vacío).
    function newestIndex() as Number {
        return _size - 1;
    }

    //! Traduce un índice lógico (0 = más antigua) a una posición del arreglo.
    //! Requiere 0 <= i < size(); no se comprueba para no penalizar el bucle de
    //! la ventana, que recorre el búfer en cada lote.
    private function slot(i as Number) as Number {
        return (_head - _size + i + _capacity) % _capacity;
    }

    private static function filledArray(n as Number) as Array<Number> {
        var a = new Array<Number>[n];
        for (var i = 0; i < n; i++) {
            a[i] = 0;
        }
        return a;
    }
}
