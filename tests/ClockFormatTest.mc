import Toybox.Lang;
import Toybox.Test;

//! Pruebas de ClockFormat (source/util): hora en 24 h y 12 h, y batería.

(:test)
function clockFormatUses24HourWithLeadingZeros(logger as Logger) as Boolean {
    Test.assertEqual(ClockFormat.hoursMinutes(7, 5, true), "07:05");
    Test.assertEqual(ClockFormat.hoursMinutes(0, 0, true), "00:00");
    Test.assertEqual(ClockFormat.hoursMinutes(23, 59, true), "23:59");
    return true;
}

(:test)
function clockFormatUses12HourWithoutLeadingZero(logger as Logger) as Boolean {
    Test.assertEqual(ClockFormat.hoursMinutes(7, 5, false), "7:05");
    Test.assertEqual(ClockFormat.hoursMinutes(0, 30, false), "12:30");
    Test.assertEqual(ClockFormat.hoursMinutes(12, 0, false), "12:00");
    Test.assertEqual(ClockFormat.hoursMinutes(13, 42, false), "1:42");
    Test.assertEqual(ClockFormat.hoursMinutes(23, 59, false), "11:59");
    return true;
}

(:test)
function clockFormatRoundsAndClampsBattery(logger as Logger) as Boolean {
    Test.assertEqual(ClockFormat.batteryPercent(84.6f), 85);
    Test.assertEqual(ClockFormat.batteryPercent(84.4f), 84);
    Test.assertEqual(ClockFormat.batteryPercent(-3.0f), 0);
    Test.assertEqual(ClockFormat.batteryPercent(100.4f), 100);
    Test.assertEqual(ClockFormat.batteryPercent(120.0f), 100);
    return true;
}
