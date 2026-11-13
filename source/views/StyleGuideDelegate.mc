import Toybox.Lang;
import Toybox.WatchUi;

//! Entrada de la guía de estilo (solo en compilaciones de depuración).
//!
//! - DOWN / deslizar hacia arriba: página siguiente.
//! - UP / deslizar hacia abajo: página anterior.
//! - START/STOP o toque: página siguiente.
//! - BACK: vuelve a la pantalla principal (comportamiento por defecto).
(:debug)
class StyleGuideDelegate extends WatchUi.BehaviorDelegate {

    private var _view as StyleGuideView;

    function initialize(view as StyleGuideView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() as Boolean {
        _view.showNext();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.showPrevious();
        return true;
    }

    function onSelect() as Boolean {
        _view.showNext();
        return true;
    }

    function onTap(clickEvent as ClickEvent) as Boolean {
        _view.showNext();
        return true;
    }
}
