import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

//! Alerta a pantalla completa "¡DESPIERTA!". Se apila sobre la esfera con pushView
//! cuando el detector emite un cabeceo o una inactividad (o desde la depuración) y
//! solo se cierra con "Estoy despierto" o START (AlertDelegate).
//!
//! De arriba abajo (fr165, 390×390):
//!   - ícono de vibración: un reloj con dos ondas a cada lado que se expanden y se
//!     desvanecen (y ≈ 70);
//!   - "¡DESPIERTA!" grande (Typography.ALERT; baja con Draw.fittingFont si no cabe);
//!   - "Nivel N de 3 · vibración suave/media/máxima" (LABEL);
//!   - el motivo: "Cabeceo / pérdida de tono muscular" o "Inactividad prolongada"
//!     (LABEL, partido en dos líneas si no cabe);
//!   - botón grande blanco "Estoy despierto" con texto oscuro
//!     (RoundLayout.alertButtonRect, 258×64 px; su área táctil, 280×86).
//!
//! Colores por nivel: AlertnessColors.alertBackgroundColor / alertTextColor (naranja,
//! naranja intenso y rojo intenso con texto blanco puro). Es la única pantalla con un
//! relleno claro de pantalla completa (docs/DISENO.md §1): debe ser imposible de
//! ignorar y dura pocos segundos.
//!
//! Animaciones (curvas en source/core/AlertVisuals.mc):
//!   - entrada de 300 ms: el color crece desde el centro y el botón rebota en escala;
//!   - pulso de brillo del fondo, más lento que 1 ciclo por segundo (seguro para
//!     personas fotosensibles); en el nivel 3 alterna rojo intenso y rojo oscuro;
//!   - sacudida de 2/4/6 px mientras el motor vibra (VibePatterns.isOnAt).
//!
//! Refresco: un Timer cada REFRESH_MS mientras se ve (onShow/onHide).
class AlertView extends WatchUi.View {

    //! Periodo de redibujo (ms): 20 cuadros por segundo, el mismo paso que la sacudida
    //! (AlertVisuals.SHAKE_STEP_MS), así cambia de lado en cada cuadro. La alerta dura
    //! pocos segundos: el costo en batería es pequeño.
    const REFRESH_MS = AlertVisuals.SHAKE_STEP_MS;

    //! Una onda del ícono tarda WAVE_PERIOD_MS en expandirse y desvanecerse; hay
    //! WAVES desfasadas entre sí.
    const WAVE_PERIOD_MS = 1200;
    const WAVES = 2;

    //! Ícono (milésimas del lado): centro vertical, cuerpo del reloj, radio de las ondas
    //! (de WAVE_FROM a WAVE_FROM + WAVE_SPAN) y medio ángulo de cada onda (grados).
    const ICON_Y = 180;
    const ICON_BODY_W = 60;
    const ICON_BODY_H = 85;
    const ICON_PEN = 10;
    const WAVE_FROM = 55;
    const WAVE_SPAN = 45;
    const WAVE_HALF_ANGLE = 35;

    //! Centro vertical de "¡DESPIERTA!" y separación con la línea de nivel (milésimas).
    const TITLE_Y = 320;
    const LINE_GAP = 4;

    //! Durante la entrada, los textos aparecen a partir de esta fracción (el disco ya
    //! cubre casi toda la pantalla).
    const ENTRANCE_TEXT_FROM = 0.5f;

    private var _alerts as AlertController;
    private var _layout as RoundLayout?;
    private var _timer as Timer.Timer? = null;

    private var _wakeUp as String = "";
    private var _levelLine as String = "";
    private var _reason as String = "";
    private var _imAwake as String = "";

    //! Medidas calculadas en onLayout con las fuentes reales.
    private var _titleFont as FontDefinition = Typography.ALERT;
    private var _levelY as Number = 0;
    private var _reasonY as Number = 0;

    function initialize(alerts as AlertController) {
        View.initialize();
        _alerts = alerts;
    }

    function onLayout(dc as Dc) as Void {
        var layout = new RoundLayout(dc.getWidth(), dc.getHeight());
        _layout = layout;
        var level = _alerts.level();
        _wakeUp = text(Rez.Strings.AlertWakeUp);
        _imAwake = text(Rez.Strings.ButtonImAwake);
        _levelLine = Lang.format(text(Rez.Strings.AlertLevelLineFormat),
            [levelText(level), vibrationText(level)]);
        _reason = text(_alerts.reason() == DrowsinessEvent.INACTIVITY
            ? Rez.Strings.AlertCauseInactivity : Rez.Strings.AlertCauseNod);

        // Título: la fuente más grande que quepa en la cuerda a su altura.
        var titleY = layout.scaled(TITLE_Y);
        var titleHeight = dc.getFontHeight(Typography.ALERT);
        _titleFont = Draw.fittingFont(dc, _wakeUp,
            layout.safeWidthBetween(titleY - titleHeight / 2, titleY + titleHeight / 2),
            Typography.ALERT);

        // Nivel justo debajo del título; el motivo, centrado entre el nivel y el botón.
        var labelHeight = dc.getFontHeight(Typography.LABEL);
        var gap = layout.scaled(LINE_GAP);
        _levelY = titleY + dc.getFontHeight(_titleFont) / 2 + labelHeight / 2 + gap;
        var reasonTop = _levelY + labelHeight / 2 + gap;
        _reasonY = (reasonTop + layout.alertButtonRect.y) / 2;

        // Motivo en una línea si cabe; si no, en dos (fitTextToArea necesita algo más de
        // dos alturas de fuente para dar dos líneas, docs/DISENO.md §3).
        var reasonWidth = layout.safeWidthBetween(_reasonY - labelHeight, _reasonY + labelHeight);
        if (dc.getTextWidthInPixels(_reason, Typography.LABEL) > reasonWidth) {
            var wrapped = Graphics.fitTextToArea(_reason, Typography.LABEL, reasonWidth,
                labelHeight * 5 / 2, true);
            if (wrapped != null) {
                _reason = wrapped;
            }
        }
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
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var layout = _layout;
        if (layout == null) {
            return;
        }
        var level = _alerts.level();
        var elapsed = _alerts.elapsedMs(System.getTimer());
        // Pulso de brillo lento (< 1 ciclo/s) y, en el nivel 3, rojo intenso ↔ rojo oscuro.
        var background = AlertnessColors.alertPulseColor(level, AlertVisuals.pulse(level, elapsed));
        var foreground = AlertnessColors.alertTextColor(level);
        // Sacudida sincronizada con los pulsos del motor.
        var dx = AlertVisuals.shakeOffset(level, elapsed);

        Draw.enableAntiAlias(dc);
        var progress = AlertVisuals.entranceProgress(elapsed);
        if (progress < 1.0f) {
            drawEntrance(dc, layout, elapsed, progress, background, foreground, dx);
            return;
        }
        Draw.clear(dc, background);
        drawContent(dc, layout, elapsed, dx, background, foreground, 1.0f);
    }

    //! Entrada (ENTRANCE_MS): el color de la alerta crece desde el centro como un disco,
    //! el botón entra con un pequeño rebote de escala y los textos aparecen a mitad de
    //! camino, cuando el disco ya los cubre.
    private function drawEntrance(dc as Dc, layout as RoundLayout, elapsed as Number,
            progress as Float, background as Number, foreground as Number, dx as Number) as Void {
        var scale = AlertVisuals.entranceScale(elapsed);
        Draw.clear(dc, Palette.BACKGROUND);
        dc.setColor(background, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(layout.centerX, layout.centerY, (layout.radius * scale).toNumber() + 1);
        if (progress >= ENTRANCE_TEXT_FROM) {
            drawContent(dc, layout, elapsed, dx, background, foreground, scale);
        }
    }

    //! Contenido de la alerta desplazado dx píxeles en horizontal, con el botón a la
    //! escala buttonScale (1 fuera de la entrada).
    private function drawContent(dc as Dc, layout as RoundLayout, elapsed as Number,
            dx as Number, background as Number, foreground as Number, buttonScale as Float) as Void {
        var cx = layout.centerX + dx;
        drawIcon(dc, layout, cx, elapsed, background, foreground);
        Draw.centeredText(dc, cx, layout.scaled(TITLE_Y), _titleFont, _wakeUp, foreground);
        Draw.centeredText(dc, cx, _levelY, Typography.LABEL, _levelLine, foreground);
        Draw.centeredText(dc, cx, _reasonY, Typography.LABEL, _reason, foreground);

        var b = layout.alertButtonRect;
        var w = (b.width * buttonScale).toNumber();
        var h = (b.height * buttonScale).toNumber();
        if (h < 2) {
            return;
        }
        Draw.largeButton(dc, new Rect(b.centerX() - w / 2 + dx, b.centerY() - h / 2, w, h),
            _imAwake, Typography.BODY, Palette.TEXT, Palette.BACKGROUND);
    }

    //! Ícono de vibración: el contorno de un reloj y, a cada lado, WAVES ondas (arcos)
    //! que salen del reloj, crecen y se desvanecen hacia el color de fondo.
    private function drawIcon(dc as Dc, layout as RoundLayout, cx as Number,
            elapsed as Number, background as Number, foreground as Number) as Void {
        var cy = layout.scaled(ICON_Y);
        var w = layout.scaled(ICON_BODY_W);
        var h = layout.scaled(ICON_BODY_H);
        var pen = layout.scaled(ICON_PEN);
        if (pen < 2) {
            pen = 2;
        }
        dc.setColor(foreground, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pen);
        dc.drawRoundedRectangle(cx - w / 2, cy - h / 2, w, h, w / 3);

        var from = layout.scaled(WAVE_FROM);
        var span = layout.scaled(WAVE_SPAN);
        for (var i = 0; i < WAVES; i++) {
            var phase = ((elapsed + i * WAVE_PERIOD_MS / WAVES) % WAVE_PERIOD_MS)
                / WAVE_PERIOD_MS.toFloat();
            var radius = from + (span * phase).toNumber();
            var alpha = (1000 * (1.0f - phase)).toNumber();
            dc.setColor(ColorMath.blend(foreground, background, alpha), Graphics.COLOR_TRANSPARENT);
            // drawArc: 0° = 3 en punto, sentido antihorario. Derecha e izquierda.
            dc.drawArc(cx, cy, radius, Graphics.ARC_COUNTER_CLOCKWISE,
                360 - WAVE_HALF_ANGLE, WAVE_HALF_ANGLE);
            dc.drawArc(cx, cy, radius, Graphics.ARC_COUNTER_CLOCKWISE,
                180 - WAVE_HALF_ANGLE, 180 + WAVE_HALF_ANGLE);
        }
        dc.setPenWidth(1);
    }

    private function levelText(level as Number) as String {
        if (level <= 1) {
            return text(Rez.Strings.AlertLevel1);
        }
        return text(level == 2 ? Rez.Strings.AlertLevel2 : Rez.Strings.AlertLevel3);
    }

    private function vibrationText(level as Number) as String {
        if (level <= 1) {
            return text(Rez.Strings.AlertVibrationSoft);
        }
        return text(level == 2 ? Rez.Strings.AlertVibrationMedium : Rez.Strings.AlertVibrationMax);
    }

    private function text(id as ResourceId) as String {
        return WatchUi.loadResource(id) as String;
    }
}

//! Entrada de la alerta.
//!
//! - START (onKey, KEY_ENTER) y un toque en el área táctil de "Estoy despierto"
//!   (RoundLayout.alertButtonTouchRect) descartan la alerta (callback onDismiss).
//! - BACK **no** la descarta: se consume y no hace nada, para que un roce del botón o
//!   un deslizamiento no cierre por accidente una alerta que busca despertar a alguien.
//! - Menú (mantener UP) también se consume: no se abre nada encima de la alerta.
//!
//! Igual que la esfera: en el fr165 START y los toques llegan primero a onSelect; se
//! devuelve false para decidir en onKey y onTap (docs/DISENO.md §6).
class AlertDelegate extends WatchUi.BehaviorDelegate {

    private var _onDismiss as Method() as Void;
    private var _layout as RoundLayout;

    function initialize(onDismiss as Method() as Void) {
        BehaviorDelegate.initialize();
        _onDismiss = onDismiss;
        var settings = System.getDeviceSettings();
        _layout = new RoundLayout(settings.screenWidth, settings.screenHeight);
    }

    function onSelect() as Boolean {
        return false;
    }

    function onKey(keyEvent as KeyEvent) as Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_ENTER) {
            _onDismiss.invoke();
            return true;
        }
        // BACK (KEY_ESC) y el resto de teclas no hacen nada mientras la alerta está abierta.
        return true;
    }

    function onTap(clickEvent as ClickEvent) as Boolean {
        var point = clickEvent.getCoordinates();
        if (_layout.hitsAlertButton(point[0], point[1])) {
            _onDismiss.invoke();
        }
        return true;
    }

    //! BACK no descarta la alerta.
    function onBack() as Boolean {
        return true;
    }

    function onMenu() as Boolean {
        return true;
    }

    function onNextPage() as Boolean {
        return true;
    }

    function onPreviousPage() as Boolean {
        return true;
    }
}
