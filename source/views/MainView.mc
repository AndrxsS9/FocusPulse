import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;

//! Esfera principal (vista de guardia).
//!
//! Orden de dibujo, de atrás hacia delante:
//!   1. fondo (BACKGROUND);
//!   2. orbe IA detrás de la hora y sus partículas (OrbModel);
//!   3. anillo de nivel de alerta en el borde;
//!   4. contenido.
//!
//! Medidas: RoundLayout (source/util/Layout.mc) y docs/DISENO.md.
//!
//! Refresco: un Timer redibuja cada REFRESH_PAUSED_MS en pausa (la hora) y cada
//! REFRESH_ACTIVE_MS con la guardia activa (la animación del orbe y del punto de la
//! fase siguiente subirá esa tasa). Se detiene en onHide y se reanuda en onShow. El
//! puntaje no depende del timer: se actualiza con cada lote de telemetría
//! (GuardController.onBatch), que además pide su propio redibujo.
class MainView extends WatchUi.View {

    //! Periodo de redibujo (ms) en pausa: basta para que cambie la hora.
    const REFRESH_PAUSED_MS = 1000;

    //! Periodo de redibujo (ms) con la guardia activa (~5 por segundo).
    const REFRESH_ACTIVE_MS = 200;

    //! Opacidad (milésimas) de cada anillo del orbe, del exterior al interior. En el
    //! fr165 no hay trazos con alfa: se mezcla el color con el fondo (ColorMath).
    const ORB_ALPHA = [600, 450, 350];

    //! En pausa el orbe se ve más tenue: opacidad × ORB_PAUSED_DIM / 1000.
    const ORB_PAUSED_DIM = 450;

    //! Grosor (px) de los anillos del orbe.
    const ORB_PEN = 2;

    //! Opacidad máxima (milésimas) de una partícula en su punto más brillante, y brillo
    //! fijo de las partículas en pausa.
    const PARTICLE_MAX_ALPHA = 700;
    const PARTICLE_PAUSED_BRIGHTNESS = 0.3f;

    //! Radio de cada partícula, en milésimas del lado (fr165: 2 px).
    const PARTICLE_SIZE = 6;

    //! El orbe se centra un poco por debajo de la hora (en milésimas del lado: 9 px en el
    //! fr165) y con el 88 % de layout.orbRadius, para que su borde superior no cruce la
    //! batería: queda entre y ≈ 55 y y ≈ 225.
    const ORB_CENTER_DROP = 25;
    const ORB_SCALE = 880;

    //! dt máximo (s) entre cuadros: tras un onHide largo la animación no da un salto.
    const MAX_FRAME_DT = 0.25f;

    //! Batería en o por debajo de este porcentaje: ícono y número en rojo.
    const BATTERY_LOW = 15;

    //! Ícono de batería, en milésimas del lado de la pantalla (fr165: 27×14 px).
    const BATTERY_WIDTH = 70;
    const BATTERY_HEIGHT = 36;

    //! Separación (px, en milésimas) entre el ícono de batería y su porcentaje.
    const BATTERY_GAP = 15;

    //! Separación (en milésimas) entre "ALERTA" y el porcentaje.
    const SCORE_GAP = 20;

    //! Fuente del porcentaje de alerta. Es de texto (no FONT_NUMBER_*) porque lleva "%",
    //! que las fuentes numéricas del reloj quizá no tengan (docs/PENDIENTES.md).
    const SCORE_FONT = Graphics.FONT_SMALL;

    private var _guard as GuardController;
    private var _layout as RoundLayout?;

    //! Orbe IA y los arreglos donde se escriben sus puntos (sin crear objetos por cuadro).
    private var _orb as OrbModel;
    private var _xs as Array<Number>;
    private var _ys as Array<Number>;
    private var _particleXs as Array<Number>;
    private var _particleYs as Array<Number>;

    //! System.getTimer() del cuadro anterior (null: aún no hubo cuadro).
    private var _lastFrameMs as Number? = null;

    //! Timer de redibujo y su periodo actual (0 = detenido).
    private var _timer as Timer.Timer? = null;
    private var _timerPeriod as Number = 0;

    private var _percentFormat as String = "";
    private var _alertLabel as String = "";
    private var _dateFormat as String = "";
    private var _dateLowercase as Boolean = false;
    private var _statusPaused as String = "";
    private var _statusActive as String = "";
    private var _statusSensorUnavailable as String = "";
    private var _badgeDemo as String = "";
    private var _buttonStart as String = "";
    private var _buttonPause as String = "";

    function initialize(guard as GuardController) {
        View.initialize();
        _guard = guard;
        _orb = new OrbModel();
        _xs = new Array<Number>[OrbModel.POINTS];
        _ys = new Array<Number>[OrbModel.POINTS];
        _particleXs = new Array<Number>[OrbModel.PARTICLES];
        _particleYs = new Array<Number>[OrbModel.PARTICLES];
    }

    function onLayout(dc as Dc) as Void {
        _layout = new RoundLayout(dc.getWidth(), dc.getHeight());
        _percentFormat = WatchUi.loadResource(Rez.Strings.PercentFormat) as String;
        _alertLabel = WatchUi.loadResource(Rez.Strings.LabelAlertShort) as String;
        _dateFormat = WatchUi.loadResource(Rez.Strings.DateFormat) as String;
        _dateLowercase = (WatchUi.loadResource(Rez.Strings.DateCase) as String).equals("lower");
        _statusPaused = WatchUi.loadResource(Rez.Strings.StatusPaused) as String;
        _statusActive = WatchUi.loadResource(Rez.Strings.StatusActive) as String;
        _statusSensorUnavailable = WatchUi.loadResource(Rez.Strings.StatusSensorUnavailable) as String;
        _badgeDemo = WatchUi.loadResource(Rez.Strings.BadgeDemo) as String;
        _buttonStart = WatchUi.loadResource(Rez.Strings.ButtonStartGuard) as String;
        _buttonPause = WatchUi.loadResource(Rez.Strings.ButtonPauseGuard) as String;
    }

    //! La vista vuelve a primer plano: reanuda el redibujo periódico.
    function onShow() as Void {
        updateTimer();
    }

    //! La vista deja de verse (otra vista encima, app en segundo plano): detiene el
    //! timer para no gastar batería redibujando algo que no se ve.
    function onHide() as Void {
        stopTimer();
    }

    //! Callback del timer.
    function onTick() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        // El estado pudo cambiar (START, toque): ajusta la tasa de redibujo.
        updateTimer();

        var layout = _layout;
        if (layout == null) {
            return;
        }
        Draw.enableAntiAlias(dc);
        var score = _guard.alertness();
        advanceOrb(score);

        Draw.clear(dc, Palette.BACKGROUND);
        drawOrb(dc, layout, score);
        drawRing(dc, layout, score);
        drawContent(dc, layout, score);
    }

    //! Arranca el timer con el periodo que toca según el estado de la guardia, o lo
    //! reinicia si el periodo cambió.
    private function updateTimer() as Void {
        var period = _guard.isActive() ? REFRESH_ACTIVE_MS : REFRESH_PAUSED_MS;
        if (_timer != null && period == _timerPeriod) {
            return;
        }
        stopTimer();
        var timer = new Timer.Timer();
        timer.start(method(:onTick), period, true);
        _timer = timer;
        _timerPeriod = period;
    }

    private function stopTimer() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
        }
        _timer = null;
        _timerPeriod = 0;
    }

    //! Actualiza el estado del orbe y avanza su animación el tiempo real desde el cuadro
    //! anterior (como mucho MAX_FRAME_DT).
    private function advanceOrb(score as Number) as Void {
        var now = System.getTimer();
        var last = _lastFrameMs;
        _lastFrameMs = now;
        _orb.setState(OrbModel.stateFor(_guard.isActive(), _guard.latestSnapshot(), score));
        if (last != null) {
            var dt = (now - last) / 1000.0f;
            _orb.advance(dt > MAX_FRAME_DT ? MAX_FRAME_DT : dt);
        }
    }

    //! Orbe IA detrás de la hora: 3 anillos orgánicos (OrbModel) en los colores de
    //! orbPalette(score), atenuados, y 16 partículas que titilan en un anillo cerca del
    //! borde. En pausa está quieto y más tenue.
    private function drawOrb(dc as Dc, layout as RoundLayout, score as Number) as Void {
        var palette = OrbModel.paletteFor(score);
        var paused = _orb.state() == OrbState.PAUSED;
        var alphas = ORB_ALPHA as Array<Number>;
        var orbCenterY = layout.timeY + layout.scaled(ORB_CENTER_DROP);
        var orbRadius = layout.orbRadius * ORB_SCALE / 1000;

        dc.setPenWidth(ORB_PEN);
        for (var ring = 0; ring < OrbModel.RINGS; ring++) {
            var alpha = paused ? alphas[ring] * ORB_PAUSED_DIM / 1000 : alphas[ring];
            dc.setColor(ColorMath.blend(palette[ring], Palette.BACKGROUND, alpha),
                Graphics.COLOR_TRANSPARENT);
            _orb.ringPoints(ring, layout.centerX, orbCenterY, orbRadius, _xs, _ys);
            var last = OrbModel.POINTS - 1;
            for (var k = 0; k < last; k++) {
                dc.drawLine(_xs[k], _ys[k], _xs[k + 1], _ys[k + 1]);
            }
            dc.drawLine(_xs[last], _ys[last], _xs[0], _ys[0]);
        }
        dc.setPenWidth(1);

        // Partículas: en el hueco entre el círculo seguro del contenido y el anillo de
        // alerta (170–177 px en el fr165), así no caen sobre textos ni el botón.
        var radius = (layout.contentRadius + layout.ringInnerRadius) / 2;
        _orb.particlePoints(layout.centerX, layout.centerY, radius, _particleXs, _particleYs);
        var size = layout.scaled(PARTICLE_SIZE);
        if (size < 1) {
            size = 1;
        }
        for (var i = 0; i < OrbModel.PARTICLES; i++) {
            var brightness = paused ? PARTICLE_PAUSED_BRIGHTNESS : _orb.particleBrightness(i);
            var alpha = (brightness * PARTICLE_MAX_ALPHA).toNumber();
            dc.setColor(ColorMath.blend(palette[1], Palette.BACKGROUND, alpha),
                Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_particleXs[i], _particleYs[i], size);
        }
    }

    //! Anillo de nivel de alerta: pista RING_TRACK completa y avance desde las 12 en
    //! sentido horario, del color de la banda del puntaje.
    private function drawRing(dc as Dc, layout as RoundLayout, score as Number) as Void {
        Draw.progressRing(dc, layout.centerX, layout.centerY, layout.ringRadius, layout.ringWidth,
            score, Palette.RING_TRACK, AlertnessColors.colorForAlertness(score));
    }

    private function drawContent(dc as Dc, layout as RoundLayout, score as Number) as Void {
        drawBattery(dc, layout);
        drawClock(dc, layout);
        drawScore(dc, layout, score);
        drawStatus(dc, layout);
        drawButton(dc, layout);
        drawDemoBadge(dc, layout);
    }

    //! Ícono de batería y porcentaje real, centrados en topY.
    private function drawBattery(dc as Dc, layout as RoundLayout) as Void {
        var percent = ClockFormat.batteryPercent(System.getSystemStats().battery);
        var color = percent <= BATTERY_LOW ? Palette.RED : Palette.TEXT_SECONDARY;
        var text = Lang.format(_percentFormat, [percent]);

        var iconWidth = layout.scaled(BATTERY_WIDTH);
        var iconHeight = layout.scaled(BATTERY_HEIGHT);
        var gap = layout.scaled(BATTERY_GAP);
        var textWidth = dc.getTextWidthInPixels(text, Typography.LABEL);
        var left = layout.centerX - (iconWidth + gap + textWidth) / 2;

        Draw.battery(dc, new Rect(left, layout.topY - iconHeight / 2, iconWidth, iconHeight),
            percent, color);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + iconWidth + gap, layout.topY, Typography.LABEL, text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! Hora grande (24 h o 12 h según el sistema) y fecha corta en el idioma del reloj.
    private function drawClock(dc as Dc, layout as RoundLayout) as Void {
        var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var time = ClockFormat.hoursMinutes(now.hour, now.min, System.getDeviceSettings().is24Hour);
        Draw.centeredText(dc, layout.centerX, layout.timeY, Typography.TIME, time, Palette.TEXT);

        var weekday = now.day_of_week as String;
        var month = now.month as String;
        if (_dateLowercase) {
            weekday = weekday.toLower();
            month = month.toLower();
        }
        var date = Lang.format(_dateFormat, [weekday, now.day, month]);
        Draw.centeredText(dc, layout.centerX, layout.dateY, Typography.LABEL, date,
            Palette.TEXT_SECONDARY);
    }

    //! "ALERTA" en etiqueta pequeña y el porcentaje en el color del anillo, centrados
    //! juntos en scoreY.
    private function drawScore(dc as Dc, layout as RoundLayout, score as Number) as Void {
        var text = Lang.format(_percentFormat, [score]);
        var gap = layout.scaled(SCORE_GAP);
        var labelWidth = dc.getTextWidthInPixels(_alertLabel, Typography.LABEL);
        var left = layout.centerX - (labelWidth + gap + dc.getTextWidthInPixels(text, SCORE_FONT)) / 2;
        var justify = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Palette.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, layout.scoreY, Typography.LABEL, _alertLabel, justify);
        dc.setColor(AlertnessColors.colorForAlertness(score), Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + labelWidth + gap, layout.scoreY, SCORE_FONT, text, justify);
    }

    //! Píldora de estado: en pausa (gris), guardia activa (cian, con punto) o sensor no
    //! disponible (ámbar). El punto se animará en la fase siguiente.
    private function drawStatus(dc as Dc, layout as RoundLayout) as Void {
        var text = _statusPaused;
        var color = Palette.TEXT_SECONDARY;
        var active = _guard.isActive();
        if (active) {
            text = _statusActive;
            color = Palette.ACCENT;
        } else if (_guard.isSensorUnavailable()) {
            text = _statusSensorUnavailable;
            color = Palette.AMBER;
        }
        Draw.statusPill(dc, layout.centerX, layout.pillY, text, Typography.LABEL, color,
            Palette.SURFACE, Palette.BORDER_STRONG, active);
    }

    //! Botón grande: "Iniciar guardia" (cian, texto oscuro) o "Pausar guardia"
    //! (superficie con borde, texto claro). Si el texto no cabe, baja la fuente.
    //! START y un toque en layout.buttonTouchRect hacen lo mismo (MainDelegate).
    private function drawButton(dc as Dc, layout as RoundLayout) as Void {
        var rect = layout.buttonRect;
        if (_guard.isActive()) {
            Draw.largeButton(dc, rect, _buttonPause, Typography.BODY, Palette.SURFACE, Palette.TEXT);
            dc.setPenWidth(2);
            dc.setColor(Palette.BORDER_STRONG, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rect.x, rect.y, rect.width, rect.height, rect.height / 2);
            dc.setPenWidth(1);
        } else {
            Draw.largeButton(dc, rect, _buttonStart, Typography.BODY, Palette.ACCENT,
                Palette.BACKGROUND);
        }
    }

    //! Marca "DEMO" bajo el botón cuando la fuente es simulada, para que en la
    //! sustentación se sepa qué datos se ven. Texto pequeño en color secundario: no
    //! compite con el contenido y casi no enciende píxeles.
    private function drawDemoBadge(dc as Dc, layout as RoundLayout) as Void {
        if (_guard.isDemoSource()) {
            Draw.centeredText(dc, layout.centerX, layout.footerY, Typography.LABEL, _badgeDemo,
                Palette.TEXT_SECONDARY);
        }
    }
}
