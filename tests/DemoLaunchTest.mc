import Toybox.Lang;
import Toybox.Test;

//! Pruebas de DemoLaunch: arranque directo en la demo y guion automático al abrir.

(:test)
function demoLaunchOffByDefault(logger as Logger) as Boolean {
    var settings = new Settings();
    Test.assertMessage(!settings.demoOnStart, "Iniciar en modo demo: apagado por defecto");
    Test.assertMessage(!settings.demoAutoScript, "Guion automático al abrir: apagado por defecto");
    Test.assertMessage(!DemoLaunch.enablesDemo(settings), "por defecto no fuerza el modo demo");
    Test.assertMessage(!DemoLaunch.schedulesScript(settings), "por defecto no hay guion");
    return true;
}

(:test)
function demoLaunchStartInDemo(logger as Logger) as Boolean {
    var settings = new Settings();
    settings.demoOnStart = true;
    Test.assert(DemoLaunch.enablesDemo(settings));
    Test.assertMessage(!DemoLaunch.schedulesScript(settings), "solo el modo demo, sin guion");
    return true;
}

(:test)
function demoLaunchAutoScriptImpliesDemo(logger as Logger) as Boolean {
    var settings = new Settings();
    settings.demoAutoScript = true;
    Test.assertMessage(DemoLaunch.enablesDemo(settings), "el guion necesita el modo demo");
    Test.assert(DemoLaunch.schedulesScript(settings));
    Test.assertEqual(DemoLaunch.SCRIPT_DELAY_MS, 3000);
    return true;
}

(:test)
function demoLaunchDoesNotOverrideUser(logger as Logger) as Boolean {
    Test.assertMessage(DemoLaunch.startsScriptNow(true, false, false), "esfera en pausa: arranca");
    Test.assertMessage(!DemoLaunch.startsScriptNow(true, true, false),
        "el usuario ya inició la guardia");
    Test.assertMessage(!DemoLaunch.startsScriptNow(true, false, true), "el guion ya corre");
    Test.assertMessage(!DemoLaunch.startsScriptNow(false, false, false),
        "el usuario apagó el modo demo");
    return true;
}

(:test)
function demoLaunchSettingsAreCopied(logger as Logger) as Boolean {
    var settings = new Settings();
    settings.demoOnStart = true;
    settings.demoAutoScript = true;
    var copy = settings.copy();
    Test.assert(copy.demoOnStart && copy.demoAutoScript);
    copy.demoAutoScript = false;
    Test.assertMessage(settings.demoAutoScript, "el original no cambia");
    return true;
}
