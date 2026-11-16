import Toybox.Lang;
import Toybox.Test;

//! Pruebas de BackSource: botón BACK frente al gesto de deslizar a la derecha.

(:test)
function backSourceWithoutKeyIsGesture(logger as Logger) as Boolean {
    var source = new BackSource();
    Test.assertMessage(!source.isFromKey(0), "sin tecla: es el gesto");
    Test.assertMessage(!source.isFromKey(50000), "sin tecla: es el gesto");
    return true;
}

(:test)
function backSourceKeyJustBeforeIsButton(logger as Logger) as Boolean {
    var source = new BackSource();
    // Orden medido en el simulador: tecla pulsada → onBack (mismo instante).
    source.keyEvent(10000);
    Test.assertMessage(source.isFromKey(10000), "onBack en el mismo instante");
    Test.assertMessage(source.isFromKey(10000 + BackSource.KEY_WINDOW_MS), "límite incluido");
    return true;
}

(:test)
function backSourceOldKeyIsGesture(logger as Logger) as Boolean {
    var source = new BackSource();
    source.keyEvent(10000);
    Test.assertMessage(!source.isFromKey(10000 + BackSource.KEY_WINDOW_MS + 1),
        "una tecla vieja no convierte un gesto en botón");
    // Un tiempo anterior a la tecla (reloj que da la vuelta) tampoco cuenta.
    Test.assertMessage(!source.isFromKey(9000), "tiempo anterior a la tecla");
    // Nueva tecla: vuelve a ser el botón.
    source.keyEvent(30000);
    Test.assert(source.isFromKey(30100));
    return true;
}
