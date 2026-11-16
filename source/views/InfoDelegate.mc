import Toybox.Lang;
import Toybox.WatchUi;

//! Entrada de las pantallas de solo lectura que se abren desde el menú principal
//! (Modelo IA y Acerca de): BACK, START, deslizar a la derecha o un toque en cualquier
//! parte vuelven al menú. Así se pueden recorrer solo con toques (en el simulador los
//! botones dibujados pueden no responder).
class InfoDelegate extends WatchUi.BehaviorDelegate {

    //! Nombre de la vista en la traza de entrada (InputTrace, solo en depuración).
    const TRACE = "info";

    function initialize() {
        BehaviorDelegate.initialize();
    }

    //! START y cualquier toque (en el fr165 los dos llegan como onSelect).
    function onSelect() as Boolean {
        InputTrace.behavior(TRACE, "onSelect");
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    //! BACK o deslizar a la derecha.
    function onBack() as Boolean {
        InputTrace.behavior(TRACE, "onBack");
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
