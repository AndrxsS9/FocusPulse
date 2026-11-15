import Toybox.Lang;
import Toybox.Test;

//! Pruebas de ClockFormat (source/util): hora en 24 h y 12 h, y batería.

(:test)
function clockFormatPicksListItems(logger as Logger) as Boolean {
    var days = "Dom,Lun,Mar,Mié,Jue,Vie,Sáb";
    Test.assertEqual(ClockFormat.listItem(days, 0), "Dom");
    Test.assertEqual(ClockFormat.listItem(days, 3), "Mié");
    Test.assertEqual(ClockFormat.listItem(days, 6), "Sáb");
    Test.assertEqual(ClockFormat.listItem(days, 7), "");
    Test.assertEqual(ClockFormat.listItem("Nov", 0), "Nov");
    return true;
}

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
function clockFormatAddsSecondsForEvents(logger as Logger) as Boolean {
    Test.assertEqual(ClockFormat.hoursMinutesSeconds(7, 5, 3, true), "07:05:03");
    Test.assertEqual(ClockFormat.hoursMinutesSeconds(13, 42, 59, false), "1:42:59");
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
