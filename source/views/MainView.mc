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
//!   3. anillo de nivel de alerta en el borde y, con la guardia activa, el arco de
//!      escaneo que gira por dentro de él;
//!   4. contenido.
//!
//! Medidas: RoundLayout (source/util/Layout.mc) y docs/DISENO.md.
//!
//! Con la fatiga en Alto (FatiguePredictor) el aviso ámbar "Micro-sueños repetidos ·
//! descansa 15 min" ocupa el sitio del puntaje y de la píldora de estado
//! (layout.fatigueBannerRect). El anillo sigue mostrando el nivel de alerta.
//!
//! Refresco: un Timer redibuja cada REFRESH_PAUSED_MS en pausa (la hora; el orbe está
//! quieto) y cada REFRESH_ACTIVE_MS con la guardia activa (unos 12 cuadros por segundo
//! para el orbe, el arco y el latido). Con ANIMATIONS_ENABLED = false la guardia activa
//! también redibuja una vez por segundo y nada se anima. Con el ajuste "Animaciones
//! reducidas" el orbe sigue latiendo pero sin sus 16 partículas. Se detiene en onHide y se
//! reanuda en onShow. El puntaje no depende del timer: se actualiza con cada lote de
//! telemetría (GuardController.onBatch), que además pide su propio redibujo.
//!
//! Anti quemado (AMOLED): cada minuto toda la esfera se desplaza a la siguiente posición
//! del ciclo de PixelShift (±2 px), aplicada a su RoundLayout con shiftTo. El área
//! táctil del botón (MainDelegate) no se mueve: le sobran 12 px de margen.
//!
//! En depuración, FrameStats mide los cuadros por segundo reales y el tiempo de dibujo
//! y los escribe en la consola cada 5 s.
class MainView extends WatchUi.View {

    //! Periodo de redibujo (ms) en pausa: basta para que cambie la hora.
    const REFRESH_PAUSED_MS = 1000;

    //! Periodo de redibujo (ms) con la guardia activa: unos 12 cuadros por segundo.
    const REFRESH_ACTIVE_MS = 83;

    //! false desactiva el orbe animado, el arco de escaneo y el latido (orbe quieto,
    //! 1 redibujo por segundo). El ajuste "Animaciones reducidas" solo quita las
    //! partículas (drawOrb).
    const ANIMATIONS_ENABLED = true;

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

    //! Arco de escaneo: largo total (grados), número de tramos (el de la cabeza más
    //! brillante, la cola se desvanece), duración de una vuelta (ms) y opacidad de la
    //! cabeza (milésimas).
    const SCAN_LENGTH = 15;
    const SCAN_SEGMENTS = 3;
    const SCAN_PERIOD_MS = 3000;
    const SCAN_ALPHA = 550;

    //! Grosor del arco de escaneo y separación con el borde interior del anillo de
    //! alerta, en milésimas del lado (fr165: 3 px y 3 px).
    const SCAN_PEN = 8;
    const SCAN_INSET = 8;

    //! Periodo del latido del punto de "Guardia activa" (ms).
    const HEARTBEAT_PERIOD_MS = 1600;

    //! dt máximo (s) entre cuadros: tras un onHide largo la animación no da un salto.
    const MAX_FRAME_DT = 0.25f;

    //! Aviso breve (Toast): margen interior y grosor del borde, en milésimas del lado
    //! (fr165: 12 px y 2 px).
    const TOAST_PADDING = 30;
    const TOAST_BORDER = 5;

    //! Aviso de fatiga: grosor del borde, en milésimas del lado
    //! (fr165: 2 px).
    const BANNER_BORDER = 5;

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

    //! Medición de cuadros por segundo y tiempo de dibujo (solo se informa en depuración).
    private var _frameStats as FrameStats = new FrameStats();

    //! Timer de redibujo y su periodo actual (0 = detenido).
    private var _timer as Timer.Timer? = null;
    private var _timerPeriod as Number = 0;

    private var _percentFormat as String = "";
    private var _alertLabel as String = "";
    private var _dateFormat as String = "";
    private var _dateLowercase as Boolean = false;
    private var _statusPaused as String = "";
    private var _statusActive as String = "";
    private var _statusCalibrating as String = "";
    private var _statusSensorUnavailable as String = "";
    private var _statusNoSensorData as String = "";
    private var _badgeDemo as String = "";
    private var _demoBadgeFormat as String = "";
    private var _scriptFormat as String = "";

    //! Línea del modo demo ya formateada y la clave con la que se formateó (escenario
    //! y paso del guion; se rehace solo cuando cambia, no en cada cuadro).
    private var _demoLine as String = "";
    private var _demoLineKey as Number = -1;

    //! Textos del aviso breve: título y valor, rehechos solo cuando cambia el aviso.
    private var _toastScenarioTitle as String = "";
    private var _toastKind as Number = -1;
    private var _toastValue as Number = -1;
    private var _toastTitle as String = "";
    private var _toastText as String = "";
    private var _buttonStart as String = "";
    private var _buttonPause as String = "";
    private var _bannerTitle as String = "";
    private var _bannerAction as String = "";

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
        _statusCalibrating = WatchUi.loadResource(Rez.Strings.StatusCalibrating) as String;
        _statusSensorUnavailable = WatchUi.loadResource(Rez.Strings.StatusSensorUnavailable) as String;
        _statusNoSensorData = WatchUi.loadResource(Rez.Strings.StatusNoSensorData) as String;
        _badgeDemo = WatchUi.loadResource(Rez.Strings.BadgeDemo) as String;
        _demoBadgeFormat = WatchUi.loadResource(Rez.Strings.DemoBadgeFormat) as String;
        _scriptFormat = WatchUi.loadResource(Rez.Strings.ScriptProgressFormat) as String;
        _demoLineKey = -1;
        _toastScenarioTitle = WatchUi.loadResource(Rez.Strings.MenuScenario) as String;
        _toastKind = -1;
        _buttonStart = WatchUi.loadResource(Rez.Strings.ButtonStartGuard) as String;
        _buttonPause = WatchUi.loadResource(Rez.Strings.ButtonPauseGuard) as String;
        _bannerTitle = WatchUi.loadResource(Rez.Strings.FatigueBannerTitle) as String;
        _bannerAction = WatchUi.loadResource(Rez.Strings.FatigueBannerAction) as String;
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

    //! Callback del timer: de paso revisa si siguen llegando lotes del acelerómetro.
    function onTick() as Void {
        _guard.checkSensorData();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        // El estado pudo cambiar (START, toque): ajusta la tasa de redibujo.
        updateTimer();

        var layout = _layout;
        if (layout == null) {
            return;
        }
        var start = System.getTimer();
        applyPixelShift(layout);
        Draw.enableAntiAlias(dc);
        var score = _guard.alertness();
        var animate = isAnimating();
        advanceOrb(score, animate);

        Draw.clear(dc, Palette.BACKGROUND);
        drawOrb(dc, layout, score);
        drawRing(dc, layout, score);
        if (animate) {
            drawScanArc(dc, layout);
        }
        drawContent(dc, layout, score, animate);

        if (_frameStats.frame(start, System.getTimer())) {
            reportFrameStats();
        }
    }

    //! Desplaza la esfera a la posición del minuto actual (PixelShift).
    private function applyPixelShift(layout as RoundLayout) as Void {
        var step = PixelShift.stepAt(Time.now().value());
        layout.shiftTo(PixelShift.offsetX(step), PixelShift.offsetY(step));
    }

    //! true si este cuadro anima (guardia activa y animaciones habilitadas).
    private function isAnimating() as Boolean {
        return ANIMATIONS_ENABLED && _guard.isActive();
    }

    //! Escribe en la consola la medición de los últimos 5 s.
    (:debug)
    private function reportFrameStats() as Void {
        System.println("FPS " + _frameStats.fps.format("%.1f") + " (" + _frameStats.frames
            + " cuadros), dibujo medio " + _frameStats.drawAvgMs.format("%.1f") + " ms, max "
            + _frameStats.drawMaxMs + " ms, periodo " + _timerPeriod + " ms, orbe "
            + _orb.state() + " t=" + _orb.time().format("%.2f") + " s");
    }

    //! En release la medición no se informa.
    (:release)
    private function reportFrameStats() as Void {
    }

    //! Arranca el timer con el periodo que toca según el estado de la guardia, o lo
    //! reinicia si el periodo cambió.
    private function updateTimer() as Void {
        var period = isAnimating() ? REFRESH_ACTIVE_MS : REFRESH_PAUSED_MS;
        if (_timer != null && period == _timerPeriod) {
            return;
        }
        stopTimer();
        _frameStats.reset();
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

    //! Actualiza el estado del orbe y, si se anima, avanza su animación el tiempo real
    //! desde el cuadro anterior (como mucho MAX_FRAME_DT).
    private function advanceOrb(score as Number, animate as Boolean) as Void {
        var now = System.getTimer();
        var last = _lastFrameMs;
        _lastFrameMs = now;
        _orb.setState(OrbModel.stateFor(_guard.isActive(), _guard.topClass(), score));
        if (!animate) {
            // Sin animación el orbe no avanza, pero conserva el color de su estado.
            return;
        }
        if (last != null) {
            var dt = (now - last) / 1000.0f;
            _orb.advance(dt > MAX_FRAME_DT ? MAX_FRAME_DT : dt);
        }
    }

    //! Orbe IA detrás de la hora: 3 anillos orgánicos (OrbModel) en los colores de
    //! orbPalette(score), atenuados, y 16 partículas que titilan en un anillo cerca del
    //! borde (no con animaciones reducidas). En pausa está quieto y más tenue.
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
        if (_guard.settings().reducedAnimations) {
            return;
        }

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

    //! Arco corto cian tenue que gira en sentido horario por dentro del anillo de
    //! alerta, una vuelta cada SCAN_PERIOD_MS: indica que la guardia está vigilando.
    //! Se dibuja en SCAN_SEGMENTS tramos; la cabeza es la más opaca.
    private function drawScanArc(dc as Dc, layout as RoundLayout) as Void {
        var pen = layout.scaled(SCAN_PEN);
        var radius = layout.ringInnerRadius - layout.scaled(SCAN_INSET) - pen / 2;
        // drawArc: 0° = 3 en punto, crece en sentido antihorario. La cabeza parte de las
        // 12 (90°) y avanza en sentido horario.
        var head = 90 - (System.getTimer() % SCAN_PERIOD_MS) * 360 / SCAN_PERIOD_MS;
        var segment = SCAN_LENGTH / SCAN_SEGMENTS;

        dc.setPenWidth(pen);
        for (var i = 0; i < SCAN_SEGMENTS; i++) {
            var alpha = SCAN_ALPHA * (SCAN_SEGMENTS - i) / SCAN_SEGMENTS;
            dc.setColor(ColorMath.blend(Palette.ACCENT, Palette.BACKGROUND, alpha),
                Graphics.COLOR_TRANSPARENT);
            var start = head + i * segment;
            dc.drawArc(layout.centerX, layout.centerY, radius, Graphics.ARC_CLOCKWISE,
                normalizeDegrees(start + segment), normalizeDegrees(start));
        }
        dc.setPenWidth(1);
    }

    //! Ángulo en 0..359.
    private static function normalizeDegrees(degrees as Number) as Number {
        var d = degrees % 360;
        return d < 0 ? d + 360 : d;
    }

    private function drawContent(dc as Dc, layout as RoundLayout, score as Number,
            animate as Boolean) as Void {
        drawBattery(dc, layout);
        drawClock(dc, layout);
        if (_guard.showsFatigueWarning()) {
            drawFatigueBanner(dc, layout);
        } else {
            drawScore(dc, layout, score);
            drawStatus(dc, layout, animate);
        }
        drawButton(dc, layout);
        drawToast(dc, layout);
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

    //! Hora grande (24 h o 12 h según el sistema) y, debajo, la fecha corta en el idioma
    //! del reloj o, con el modo demo activo, la línea del modo demo.
    private function drawClock(dc as Dc, layout as RoundLayout) as Void {
        var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var time = ClockFormat.hoursMinutes(now.hour, now.min, System.getDeviceSettings().is24Hour);
        Draw.centeredText(dc, layout.centerX, layout.timeY, Typography.TIME, time, Palette.TEXT);
        if (_guard.isDemoMode()) {
            drawDemoLine(dc, layout);
            return;
        }

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

    //! Píldora de estado: en pausa (gris), guardia activa (cian, con un punto que late
    //! cada HEARTBEAT_PERIOD_MS; "Calibrando…" mientras el detector aprende la línea
    //! base), sin datos del sensor (ámbar, sin punto: más de 5 s sin lotes con la
    //! guardia activa; se quita sola al volver los datos) o sensor no disponible (ámbar).
    private function drawStatus(dc as Dc, layout as RoundLayout, animate as Boolean) as Void {
        var text = _statusPaused;
        var color = Palette.TEXT_SECONDARY;
        var active = _guard.isActive();
        if (_guard.isSensorDataMissing()) {
            text = _statusNoSensorData;
            color = Palette.AMBER;
            active = false;
            animate = false;
        } else if (active) {
            text = _guard.isCalibrating() ? _statusCalibrating : _statusActive;
            color = Palette.ACCENT;
        } else if (_guard.isSensorUnavailable()) {
            text = _statusSensorUnavailable;
            color = Palette.AMBER;
        }
        // Latido: fase 0–1 dentro de cada periodo; -1 (sin halo) si no se anima.
        var pulse = animate
            ? (System.getTimer() % HEARTBEAT_PERIOD_MS) / HEARTBEAT_PERIOD_MS.toFloat()
            : -1.0f;
        Draw.statusPill(dc, layout.centerX, layout.pillY, text, Typography.LABEL, color,
            Palette.SURFACE, Palette.BORDER_STRONG, active, pulse);
    }

    //! Aviso de fatiga alta en lugar del puntaje y la píldora: caja SURFACE con borde
    //! ámbar y dos líneas, "Micro-sueños repetidos" en ámbar y "descansa 15 min"
    //! en TEXT. Es fijo (sin animación): en AMOLED solo se encienden el borde y
    //! el texto. Un toque en la caja abre el descanso guiado (MainDelegate).
    private function drawFatigueBanner(dc as Dc, layout as RoundLayout) as Void {
        var rect = layout.fatigueBannerRect;
        var corner = rect.height / 3;
        dc.setColor(Palette.SURFACE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(rect.x, rect.y, rect.width, rect.height, corner);
        dc.setPenWidth(layout.scaled(BANNER_BORDER));
        dc.setColor(Palette.AMBER, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(rect.x, rect.y, rect.width, rect.height, corner);
        dc.setPenWidth(1);

        var line = dc.getFontHeight(Typography.LABEL);
        var cy = rect.centerY();
        Draw.centeredText(dc, layout.centerX, cy - line / 2, Typography.LABEL, _bannerTitle,
            Palette.AMBER);
        Draw.centeredText(dc, layout.centerX, cy + line / 2, Typography.LABEL, _bannerAction,
            Palette.TEXT);
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

    //! Aviso breve (Toast) sobre el centro de la esfera durante 1,5 s: caja SURFACE con
    //! borde cian, título pequeño en gris ("Escenario") y el valor debajo ("Tecleo
    //! activo"), con la fuente más grande que quepa. Tapa la fecha, el puntaje y la
    //! píldora mientras dura; la hora y el botón siguen a la vista. El aviso de seguridad
    //! ("Alerta solo visual", 3 s) lleva el borde y el título en ámbar, como el de fatiga.
    private function drawToast(dc as Dc, layout as RoundLayout) as Void {
        var toast = _guard.toast();
        if (!toast.isVisible(System.getTimer()) || !updateToastTexts(toast)) {
            return;
        }
        var pad = layout.scaled(TOAST_PADDING);
        var titleHeight = dc.getFontHeight(Typography.LABEL);
        // El ancho disponible se mide con el alto máximo (valor en BODY): la caja final
        // solo puede ser igual o más baja, así que también cabe.
        var height = 2 * pad + titleHeight + dc.getFontHeight(Typography.BODY);
        var top = layout.centerY - height / 2;
        var maxWidth = layout.safeWidthBetween(top, top + height);
        var valueFont = Draw.fittingFont(dc, _toastText, maxWidth - 2 * pad, Typography.BODY);
        var valueHeight = dc.getFontHeight(valueFont);
        height = 2 * pad + titleHeight + valueHeight;
        top = layout.centerY - height / 2;

        var textWidth = dc.getTextWidthInPixels(_toastText, valueFont);
        var titleWidth = dc.getTextWidthInPixels(_toastTitle, Typography.LABEL);
        var width = (textWidth > titleWidth ? textWidth : titleWidth) + 4 * pad;
        if (width > maxWidth) {
            width = maxWidth;
        }
        var left = layout.centerX - width / 2;

        dc.setColor(Palette.SURFACE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(left, top, width, height, pad);
        var warning = toast.kind() == ToastKind.VISUAL_ONLY;
        dc.setPenWidth(layout.scaled(TOAST_BORDER));
        dc.setColor(warning ? Palette.AMBER : Palette.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(left, top, width, height, pad);
        dc.setPenWidth(1);
        Draw.centeredText(dc, layout.centerX, top + pad + titleHeight / 2, Typography.LABEL,
            _toastTitle, warning ? Palette.AMBER : Palette.TEXT_SECONDARY);
        Draw.centeredText(dc, layout.centerX, top + pad + titleHeight + valueHeight / 2,
            valueFont, _toastText, Palette.TEXT);
    }

    //! Prepara el título y el valor del aviso si cambió. Devuelve false si el tipo de
    //! aviso no tiene texto.
    private function updateToastTexts(toast as Toast) as Boolean {
        var kind = toast.kind() as Number;
        if (kind == _toastKind && toast.value() == _toastValue) {
            return true;
        }
        if (toast.kind() == ToastKind.SCENARIO) {
            _toastTitle = _toastScenarioTitle;
            _toastText = DemoText.scenarioName(toast.value() as AccelScenario.Id);
        } else if (toast.kind() == ToastKind.VISUAL_ONLY) {
            _toastTitle = DemoText.text(Rez.Strings.WarningVisualOnlyTitle);
            _toastText = DemoText.text(Rez.Strings.WarningVisualOnlyShort);
        } else {
            return false;
        }
        _toastKind = kind;
        _toastValue = toast.value();
        return true;
    }

    //! Línea del modo demo en el sitio de la fecha: "DEMO · Tecleo activo" o, con el
    //! guion en marcha, "Guion 2/5 · Tecleo activo", en cian, para que en la
    //! sustentación se sepa qué datos se ven y qué escenario corre. Va aquí y no en el
    //! pie (footerY), donde la cuerda del círculo seguro solo deja unos 130 px; en dateY
    //! hay unos 335 px. Los nombres cortos (DemoShort*) caben en ambos idiomas.
    private function drawDemoLine(dc as Dc, layout as RoundLayout) as Void {
        var scenario = _guard.demoScenario() as Number;
        var script = _guard.demoScript();
        var step = script.stepNumber();
        var key = step * AccelScenario.COUNT + scenario;
        if (key != _demoLineKey) {
            var name = DemoText.scenarioShortName(scenario as AccelScenario.Id);
            _demoLine = step > 0
                ? Lang.format(_scriptFormat, [step, script.stepCount(), name])
                : Lang.format(_demoBadgeFormat, [_badgeDemo, name]);
            _demoLineKey = key;
        }
        Draw.centeredText(dc, layout.centerX, layout.dateY, Typography.LABEL, _demoLine,
            Palette.ACCENT);
    }
}
