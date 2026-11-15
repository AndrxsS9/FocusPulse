import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

//! Descanso guiado: cuenta regresiva de 15 min (30 s en modo demo) con un anillo que se
//! vacía. Se abre desde el aviso de fatiga de la esfera o desde "Tomar descanso" en el
//! menú (GuardController.startBreak), con la guardia suspendida mientras dura.
//!
//! En marcha (fr165, 390×390):
//!   - anillo en el borde (mismas medidas que el de la esfera): ACCENT de las 12 en
//!     sentido horario, tan largo como la fracción que queda, sobre la pista RING_TRACK;
//!   - "Descanso" (LABEL, secundario) arriba;
//!   - el tiempo que queda, "14:59", grande (Typography.clock) en el centro;
//!   - "BACK · cancelar" (LABEL, secundario) debajo.
//! Al terminar: el anillo queda vacío, "Descanso terminado" (BODY) y el botón grande
//! "Reanudar guardia" (ACCENT, como "Iniciar guardia"). La app vibra suave una vez.
//!
//! AMOLED: solo trazos y texto, sin rellenos grandes; se redibuja una vez por segundo.
class BreakView extends WatchUi.View {

    //! Redibujo (ms): el reloj cambia cada segundo.
    const REFRESH_MS = 1000;

    //! Alturas, en milésimas del lado.
    const TITLE_Y = 290;
    const COUNTDOWN_Y = 480;
    const HINT_Y = 660;
    const DONE_Y = 470;

    private var _guard as GuardController;
    private var _layout as RoundLayout?;
    private var _timer as Timer.Timer? = null;

    private var _title as String = "";
    private var _done as String = "";
    private var _hint as String = "";
    private var _resume as String = "";

    function initialize(guard as GuardController) {
        View.initialize();
        _guard = guard;
    }

    function onLayout(dc as Dc) as Void {
        _layout = new RoundLayout(dc.getWidth(), dc.getHeight());
        _title = DemoText.text(Rez.Strings.BreakTitle);
        _done = DemoText.text(Rez.Strings.BreakDone);
        _hint = DemoText.text(Rez.Strings.BreakHint);
        _resume = DemoText.text(Rez.Strings.ButtonResumeGuard);
    }

    function onShow() as Void {
        var timer = new Timer.Timer();
        timer.start(method(:onTick), REFRESH_MS, true);
        _timer = timer;
    }

    function onHide() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
        }
        _timer = null;
    }

    function onTick() as Void {
        _guard.onBreakTick();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var layout = _layout;
        if (layout == null) {
            return;
        }
        var timer = _guard.breakTimer();
        var now = System.getTimer();
        Draw.enableAntiAlias(dc);
        Draw.clear(dc, Palette.BACKGROUND);

        var percent = (timer.progress(now) * 100.0f + 0.5f).toNumber();
        Draw.progressRing(dc, layout.centerX, layout.centerY, layout.ringRadius,
            layout.ringWidth, percent, Palette.RING_TRACK, Palette.ACCENT);

        var cx = layout.centerX;
        if (timer.isFinished()) {
            var doneY = layout.scaled(DONE_Y);
            var font = Draw.fittingFont(dc, _done, layout.safeWidthAt(doneY), Typography.body);
            Draw.centeredText(dc, cx, doneY, font, _done, Palette.TEXT);
            Draw.largeButton(dc, layout.buttonRect, _resume, Typography.button, Palette.ACCENT,
                Palette.BACKGROUND);
            return;
        }
        Draw.centeredText(dc, cx, layout.scaled(TITLE_Y), Typography.label, _title,
            Palette.TEXT_SECONDARY);
        Draw.centeredText(dc, cx, layout.scaled(COUNTDOWN_Y), Typography.clock,
            ClockFormat.countdown(timer.remainingSeconds(now)), Palette.TEXT);
        Draw.centeredText(dc, cx, layout.scaled(HINT_Y), Typography.label, _hint,
            Palette.TEXT_SECONDARY);
    }
}

//! Entrada del descanso.
//!
//! - BACK: cancela el descanso y reanuda la guardia (GuardController.endBreak).
//! - Terminado: START o un toque en "Reanudar guardia" reanudan la guardia.
//! - En marcha, START y los toques no hacen nada: el descanso solo se corta con BACK.
//!
//! Como en la esfera, onSelect devuelve false para decidir en onKey y onTap.
class BreakDelegate extends WatchUi.BehaviorDelegate {

    private var _guard as GuardController;
    private var _layout as RoundLayout;

    function initialize(guard as GuardController) {
        BehaviorDelegate.initialize();
        _guard = guard;
        var settings = System.getDeviceSettings();
        _layout = new RoundLayout(settings.screenWidth, settings.screenHeight);
    }

    function onSelect() as Boolean {
        return false;
    }

    function onKey(keyEvent as KeyEvent) as Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_ENTER && _guard.breakTimer().isFinished()) {
            _guard.endBreak();
        }
        return keyEvent.getKey() == WatchUi.KEY_ENTER;
    }

    function onTap(clickEvent as ClickEvent) as Boolean {
        var point = clickEvent.getCoordinates();
        if (_guard.breakTimer().isFinished() && _layout.hitsButton(point[0], point[1])) {
            _guard.endBreak();
        }
        return true;
    }

    //! BACK: cancela (o cierra, si ya terminó) y vuelve a la guardia.
    function onBack() as Boolean {
        _guard.endBreak();
        return true;
    }

    function onMenu() as Boolean {
        return true;
    }
}
