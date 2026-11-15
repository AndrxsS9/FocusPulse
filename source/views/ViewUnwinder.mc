import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

//! Cierra todo lo que haya encima de la esfera (menú principal, Ajustes, Historial,
//! Modelo IA, Probar alerta, confirmaciones…) y después llama a done: así la alerta se
//! abre sobre la esfera y, al responder "Estoy despierto", se vuelve directamente a
//! ella, sin pantallas apiladas.
//!
//! popView no cambia la vista actual hasta el siguiente ciclo de eventos
//! (WatchUi.getCurrentView sigue devolviendo la vista recién cerrada; verificado en el
//! simulador del SDK 9.3.0), así que no se pueden contar las vistas en un bucle: se
//! cierra una, se espera STEP_MS y se vuelve a mirar. Si la vista de arriba sigue siendo
//! la que se cerró, espera otro paso en vez de cerrar otra: nunca cierra la esfera, que
//! saldría de la app. Con la esfera ya arriba, done se llama en el acto, sin timer.
class ViewUnwinder {

    //! Espera (ms) entre un popView y la comprobación siguiente.
    const STEP_MS = 50;

    //! Más vistas de las que la app puede apilar sobre la esfera (menú principal,
    //! submenú, pantalla de información y confirmación son 4).
    const MAX_POPS = 8;

    //! Pasos seguidos sin que se aplique un popView antes de rendirse y llamar a done.
    const MAX_WAITS = 10;

    private var _timer as Timer.Timer? = null;
    private var _done as Method() as Void or Null = null;
    private var _lastPopped as Object? = null;
    private var _pops as Number = 0;
    private var _waits as Number = 0;

    function initialize() {
    }

    //! Empieza a cerrar vistas; al terminar llama a done (una vez).
    function start(done as Method() as Void) as Void {
        cancel();
        _done = done;
        _lastPopped = null;
        _pops = 0;
        _waits = 0;
        step();
    }

    //! Abandona lo que estuviera cerrando sin llamar a done.
    function cancel() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
        }
        _timer = null;
        _done = null;
    }

    //! Vistas cerradas por el último start().
    function pops() as Number {
        return _pops;
    }

    //! Un paso: termina si la esfera está arriba; si no, cierra la vista de arriba (o
    //! espera a que se aplique el cierre anterior) y programa el paso siguiente.
    function step() as Void {
        _timer = null;
        if (_done == null) {
            return;
        }
        var current = WatchUi.getCurrentView()[0];
        if (current == null || current instanceof MainView || _pops >= MAX_POPS) {
            finish();
            return;
        }
        if (current == _lastPopped) {
            _waits += 1;
            if (_waits > MAX_WAITS) {
                finish();
                return;
            }
        } else {
            _waits = 0;
            _lastPopped = current;
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            _pops += 1;
        }
        var timer = new Timer.Timer();
        timer.start(method(:step), STEP_MS, false);
        _timer = timer;
    }

    private function finish() as Void {
        var done = _done;
        _done = null;
        if (done != null) {
            done.invoke();
        }
    }
}
