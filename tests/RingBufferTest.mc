import Toybox.Lang;
import Toybox.Test;

//! Pruebas de RingBuffer (source/core): llenado, vuelta circular y magnitud.

(:test)
function ringBufferFillsInOrder(logger as Logger) as Boolean {
    var buffer = new RingBuffer(3);
    Test.assert(buffer.isEmpty());
    Test.assertEqual(buffer.capacity(), 3);
    Test.assertEqual(buffer.newestIndex(), -1);

    buffer.push(1, 10, 100);
    buffer.push(2, 20, 200);
    Test.assertEqual(buffer.size(), 2);
    Test.assert(!buffer.isFull());
    Test.assertEqual(buffer.x(0), 1);
    Test.assertEqual(buffer.y(0), 10);
    Test.assertEqual(buffer.z(0), 100);
    Test.assertEqual(buffer.x(buffer.newestIndex()), 2);
    return true;
}

(:test)
function ringBufferWrapsAroundKeepingNewest(logger as Logger) as Boolean {
    var buffer = new RingBuffer(3);
    for (var i = 1; i <= 5; i++) {
        buffer.push(i, -i, 1000 + i);
    }
    Test.assert(buffer.isFull());
    Test.assertEqual(buffer.size(), 3);

    // Quedan 3, 4 y 5, de la más antigua a la más reciente.
    Test.assertEqual(buffer.x(0), 3);
    Test.assertEqual(buffer.x(1), 4);
    Test.assertEqual(buffer.x(2), 5);
    Test.assertEqual(buffer.y(2), -5);
    Test.assertEqual(buffer.z(0), 1003);

    // Una vuelta completa más sigue en orden.
    for (var i = 6; i <= 9; i++) {
        buffer.push(i, 0, 0);
    }
    Test.assertEqual(buffer.x(0), 7);
    Test.assertEqual(buffer.x(2), 9);
    return true;
}

(:test)
function ringBufferClearKeepsCapacity(logger as Logger) as Boolean {
    var buffer = new RingBuffer(4);
    buffer.push(1, 1, 1);
    buffer.push(2, 2, 2);
    buffer.clear();
    Test.assert(buffer.isEmpty());
    Test.assertEqual(buffer.capacity(), 4);

    buffer.push(7, 8, 9);
    Test.assertEqual(buffer.size(), 1);
    Test.assertEqual(buffer.x(0), 7);
    return true;
}

(:test)
function ringBufferStoresRoundedMagnitude(logger as Logger) as Boolean {
    var buffer = new RingBuffer(3);
    buffer.push(3, 4, 0);
    buffer.push(0, 0, -1000);
    buffer.push(-240, -940, 240);   // √998800 = 999,4
    Test.assertEqual(buffer.magnitude(0), 5);
    Test.assertEqual(buffer.magnitude(1), 1000);
    Test.assertEqual(buffer.magnitude(2), 999);
    Test.assertEqual(RingBuffer.magnitudeOf(22, -18, 996), 996);
    return true;
}
