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
//! reducidas" el orbe queda congelado y sin sus 16 partículas. Se detiene en onHide y se
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

    //! Grosor de cada contorno (px del diseño web, escalados con la pantalla).
    const ORB_PEN = [2.5f, 2.0f, 2.0f];

    //! dt máximo (s) entre cuadros: tras un onHide largo la animación no da un salto.
    const MAX_FRAME_DT = 0.25f;

    //! Aviso breve (Toast): margen interior y grosor del borde, en milésimas del lado
    //! (fr165: 12 px y 2 px).
    const TOAST_PADDING = 30;
    const TOAST_BORDER = 5;

    //! Borde cian del botón con el foco, en milésimas del lado (fr165: 2 px).
    const FOCUS_BORDER = 6;

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

    //! Foco del botón grande (lo pulsa MainDelegate): borde cian mientras dura.
    private var _focus as ButtonFocus;

    //! Orbe IA y los arreglos donde se escriben sus puntos (sin crear objetos por cuadro).
    private var _orb as OrbModel;
    private var _xs as Array<Float>;
    private var _ys as Array<Float>;
    private var _particleXs as Array<Float>;
    private var _particleYs as Array<Float>;

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

    function initialize(guard as GuardController, focus as ButtonFocus) {
        View.initialize();
        _guard = guard;
        _focus = focus;
        _orb = new OrbModel();
        _xs = new Array<Float>[OrbModel.POINTS];
        _ys = new Array<Float>[OrbModel.POINTS];
        _particleXs = new Array<Float>[OrbModel.PARTICLES];
        _particleYs = new Array<Float>[OrbModel.PARTICLES];
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
            + _orb.state() + " fase A " + _orb.phase(0).format("%.3f"));
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
        if (!animate || _guard.settings().reducedAnimations) {
            // Sin animación (o con animaciones reducidas) el orbe queda congelado, pero
            // conserva el color y la opacidad de su estado.
            return;
        }
        if (last != null) {
            var dt = (now - last) / 1000.0f;
            _orb.advance(dt > MAX_FRAME_DT ? MAX_FRAME_DT : dt);
        }
    }

    //! Orbe IA detrás del contenido: 3 contornos de Bézier (OrbModel) centrados en la
    //! pantalla, en los colores de orbPalette(score) y con la opacidad del estado
    //! (OrbModel.ringAlpha), y 16 partículas que titilan en un anillo de radio 150 px (no
    //! con animaciones reducidas). En pausa está quieto y al 30 %.
    private function drawOrb(dc as Dc, layout as RoundLayout, score as Number) as Void {
        var palette = OrbModel.paletteFor(score);
        var state = _orb.state();
        var pens = ORB_PEN as Array<Float>;
        var k = layout.size / OrbModel.DESIGN_SIZE.toFloat();
        var last = OrbModel.POINTS - 1;

        for (var ring = 0; ring < OrbModel.RINGS; ring++) {
            // En el fr165 no hay trazos con alfa: se mezcla el color con el fondo.
            dc.setColor(ColorMath.blend(palette[ring], Palette.BACKGROUND,
                OrbModel.ringAlpha(state, ring)),
                Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(pens[ring] * k);
            _orb.ringPoints(ring, layout.centerX, layout.centerY, k, _xs, _ys);
            for (var i = 0; i < last; i++) {
                dc.drawLine(_xs[i], _ys[i], _xs[i + 1], _ys[i + 1]);
            }
            dc.drawLine(_xs[last], _ys[last], _xs[0], _ys[0]);
        }
        dc.setPenWidth(1);
        if (_guard.settings().reducedAnimations) {
            return;
        }

        // Partículas: titileo de 0,1 a 1 por la opacidad del estado, colores de la
        // paleta en rotación y radios alternos de 2,2 y 1,6 px.
        var opacity = OrbModel.opacityFor(state);
        _orb.particlePoints(layout.centerX, layout.centerY, k, _particleXs, _particleYs);
        for (var i = 0; i < OrbModel.PARTICLES; i++) {
            var alpha = _orb.particleAlpha(i) * opacity / 1000;
            dc.setColor(ColorMath.blend(palette[OrbModel.particleColorIndex(i)],
                Palette.BACKGROUND, alpha), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_particleXs[i], _particleYs[i], OrbModel.particleRadius(i) * k);
        }
    }

    //! Anillo de nivel de alerta: pista RING_TRACK completa y avance desde las 12 en
    //! sentido horario, del color de la banda del puntaje.
    private function drawRing(dc as Dc, layout as RoundLayout, score as Number) as Void {
        Draw.progressRing(dc, layout.centerX, layout.centerY, layout.ringRadius, layout.ringWidth,
            score, Palette.RING_TRACK, AlertnessColors.colorForAlertness(score));
    }

    //! Arco de escaneo del diseño web (GuardVisuals): cian al 55 %, 46 px de largo y
    //! 3 px de trazo sobre un círculo de radio 164 px, una vuelta en sentido horario cada
    //! 2,8 s. Indica que la guardia está vigilando.
    private function drawScanArc(dc as Dc, layout as RoundLayout) as Void {
        var k = layout.size / OrbModel.DESIGN_SIZE.toFloat();
        var head = GuardVisuals.scanHeadDegrees(System.getTimer());
        var tail = GuardVisuals.normalizeDegrees(head + GuardVisuals.scanLengthDegrees());
        dc.setPenWidth(GuardVisuals.SCAN_PEN * k);
        dc.setColor(ColorMath.blend(Palette.ACCENT, Palette.BACKGROUND, GuardVisuals.SCAN_ALPHA),
            Graphics.COLOR_TRANSPARENT);
        // drawArc: 0° = 3 en punto, crece en sentido antihorario. De la cola a la cabeza
        // en sentido horario.
        dc.drawArc(layout.centerX, layout.centerY, GuardVisuals.SCAN_RADIUS * k,
            Graphics.ARC_CLOCKWISE, tail, head);
        dc.setPenWidth(1);
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
        var textWidth = dc.getTextWidthInPixels(text, Typography.label);
        var left = layout.centerX - (iconWidth + gap + textWidth) / 2;

        Draw.battery(dc, new Rect(left, layout.topY - iconHeight / 2, iconWidth, iconHeight),
            percent, color);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + iconWidth + gap, layout.topY, Typography.label, text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! Hora grande (24 h o 12 h según el sistema) y, debajo, la fecha corta en el idioma
    //! del reloj o, con el modo demo activo, la línea del modo demo.
    private function drawClock(dc as Dc, layout as RoundLayout) as Void {
        var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var time = ClockFormat.hoursMinutes(now.hour, now.min, System.getDeviceSettings().is24Hour);
        drawTime(dc, layout, time, GuardVisuals.colonAlpha(now.sec));
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
        Draw.centeredText(dc, layout.centerX, layout.dateY, Typography.label, date,
            Palette.TEXT_SECONDARY);
    }

    //! Hora "HH:MM" centrada en timeY, con los dos puntos dibujados aparte con la
    //! opacidad colonAlpha (milésimas, mezclada con el fondo): parpadean cada segundo
    //! entre 1 y 0,25 (GuardVisuals). Las tres piezas juntas miden lo mismo que la hora
    //! entera, así que no se mueve al parpadear.
    private function drawTime(dc as Dc, layout as RoundLayout, time as String,
            colonAlpha as Number) as Void {
        var colon = time.find(":");
        if (colon == null) {
            Draw.centeredText(dc, layout.centerX, layout.timeY, Typography.clock, time, Palette.TEXT);
            return;
        }
        var hours = time.substring(0, colon) as String;
        var minutes = time.substring(colon + 1, time.length()) as String;
        var separator = ":";
        var font = Typography.clock;
        var hoursWidth = dc.getTextWidthInPixels(hours, font);
        var colonWidth = dc.getTextWidthInPixels(separator, font);
        var left = layout.centerX
            - (hoursWidth + colonWidth + dc.getTextWidthInPixels(minutes, font)) / 2;
        var justify = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, layout.timeY, font, hours, justify);
        dc.drawText(left + hoursWidth + colonWidth, layout.timeY, font, minutes, justify);
        dc.setColor(ColorMath.blend(Palette.TEXT, Palette.BACKGROUND, colonAlpha),
            Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + hoursWidth, layout.timeY, font, separator, justify);
    }

    //! "ALERTA" en etiqueta pequeña y el porcentaje en el color del anillo, centrados
    //! juntos en scoreY.
    private function drawScore(dc as Dc, layout as RoundLayout, score as Number) as Void {
        var text = Lang.format(_percentFormat, [score]);
        var gap = layout.scaled(SCORE_GAP);
        var labelWidth = dc.getTextWidthInPixels(_alertLabel, Typography.label);
        var left = layout.centerX - (labelWidth + gap + dc.getTextWidthInPixels(text, SCORE_FONT)) / 2;
        var justify = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Palette.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, layout.scoreY, Typography.label, _alertLabel, justify);
        dc.setColor(AlertnessColors.colorForAlertness(score), Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + labelWidth + gap, layout.scoreY, SCORE_FONT, text, justify);
    }

    //! Píldora de estado: en pausa (gris), guardia activa (cian, con un punto cian claro
    //! y su "ping", GuardVisuals; "Calibrando…" mientras el detector aprende la línea
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
        // Ping: avance 0–1 dentro de su ciclo; -1 (sin ping) si no se anima.
        var ping = animate ? GuardVisuals.pingProgress(System.getTimer()) : -1.0f;
        Draw.statusPill(dc, layout.centerX, layout.pillY, text, Typography.label, color,
            Palette.SURFACE, Palette.BORDER_STRONG, active ? Palette.ACCENT_LIGHT : null, ping);
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

        var line = dc.getFontHeight(Typography.label);
        var cy = rect.centerY();
        Draw.centeredText(dc, layout.centerX, cy - line / 2, Typography.label, _bannerTitle,
            Palette.AMBER);
        Draw.centeredText(dc, layout.centerX, cy + line / 2, Typography.label, _bannerAction,
            Palette.TEXT);
    }

    //! Botón grande de 220×60 y radio 30 (fr165): "Iniciar guardia" (cian, texto oscuro)
    //! o "Pausar guardia" (fondo BORDER #1C222B y texto TEXT, como el diseño web). Con
    //! la guardia activa, mientras el botón tiene el foco (ButtonFocus: se acaba de
    //! pulsar) lleva un borde cian de FOCUS_BORDER px por dentro. Si el texto no cabe,
    //! baja la fuente. START y un toque en layout.buttonTouchRect hacen lo mismo
    //! (MainDelegate).
    private function drawButton(dc as Dc, layout as RoundLayout) as Void {
        var rect = layout.buttonRect;
        if (_guard.isActive()) {
            Draw.largeButton(dc, rect, _buttonPause, Typography.button, Palette.BORDER, Palette.TEXT);
            if (_focus.isHighlighted(System.getTimer())) {
                var pen = layout.scaled(FOCUS_BORDER);
                var inset = pen / 2;
                dc.setPenWidth(pen);
                dc.setColor(Palette.ACCENT, Graphics.COLOR_TRANSPARENT);
                dc.drawRoundedRectangle(rect.x + inset, rect.y + inset, rect.width - pen,
                    rect.height - pen, rect.height / 2 - inset);
                dc.setPenWidth(1);
            }
        } else {
            Draw.largeButton(dc, rect, _buttonStart, Typography.button, Palette.ACCENT,
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
        var titleHeight = dc.getFontHeight(Typography.label);
        // El ancho disponible se mide con el alto máximo (valor en BODY): la caja final
        // solo puede ser igual o más baja, así que también cabe.
        var height = 2 * pad + titleHeight + dc.getFontHeight(Typography.body);
        var top = layout.centerY - height / 2;
        var maxWidth = layout.safeWidthBetween(top, top + height);
        var valueFont = Draw.fittingFont(dc, _toastText, maxWidth - 2 * pad, Typography.body);
        var valueHeight = dc.getFontHeight(valueFont);
        height = 2 * pad + titleHeight + valueHeight;
        top = layout.centerY - height / 2;

        var textWidth = dc.getTextWidthInPixels(_toastText, valueFont);
        var titleWidth = dc.getTextWidthInPixels(_toastTitle, Typography.label);
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
        Draw.centeredText(dc, layout.centerX, top + pad + titleHeight / 2, Typography.label,
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
        Draw.centeredText(dc, layout.centerX, layout.dateY, Typography.label, _demoLine,
            Palette.ACCENT);
    }
}
