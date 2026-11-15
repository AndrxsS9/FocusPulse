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
//!   - ícono de vibración: un círculo con un teléfono vibrando dentro y dos ondas
//!     circulares que crecen de 1× a 1,25× y se desvanecen (y ≈ 70);
//!   - "¡DESPIERTA!" grande (Typography.ALERT; baja con Draw.fittingFont si no cabe);
//!   - "Nivel N de 3 · vibración suave/media/máxima" (LABEL);
//!   - el motivo: "Cabeceo / pérdida de tono muscular" o "Inactividad prolongada"
//!     (LABEL, partido en dos líneas si no cabe);
//!   - botón grande blanco "Estoy despierto" con borde negro de 3 px y texto negro en
//!     los tres niveles (RoundLayout.alertButtonRect, 258×64 px; su área táctil, 280×86).
//!
//! Colores por nivel (diseño web): AlertnessColors.alertBackgroundColor /
//! alertTextColor: naranja #FF8A1F y naranja intenso #FF5A1F con texto negro, y rojo
//! #E01E1E ↔ #6A0000 con texto blanco puro. Es la única pantalla con un
//! relleno claro de pantalla completa (docs/DISENO.md §1): debe ser imposible de
//! ignorar y dura pocos segundos.
//!
//! Animaciones (curvas en source/core/AlertVisuals.mc):
//!   - entrada de 300 ms: el color crece desde el centro y el botón rebota en escala;
//!   - pulso del fondo (AlertVisuals.pulse, siempre por debajo de 3 Hz): opacidad
//!     1 → 0,72 → 1 mezclando con negro en 1,4 s (nivel 1) y 0,7 s (nivel 2, hasta
//!     0,88 por contraste); en el nivel 3, parpadeo rojo intenso ↔ rojo oscuro cada 0,5 s;
//!   - ondas del ícono: 2 anillos de 3 px del color del texto (AlertVisuals.ripple*);
//!   - sacudida de 2/4/6 px mientras el motor vibra (VibePatterns.isOnAt con el patrón
//!     del ajuste de vibración); con la vibración apagada no se sacude y la línea de
//!     nivel dice "sin vibración".
//!   - con **animaciones reducidas** (ajuste): sin sacudida, pulso el doble de lento y
//!     10 cuadros por segundo. Color y textos no cambian.
//!
//! Escalamiento (fase 9): la vista lee el nivel de AlertController en cada cuadro. Si
//! sube, sin cerrarse ni volver a abrirse cambia el color (el del nivel nuevo crece
//! desde el centro sobre el anterior en TRANSITION_MS), el texto "Nivel N de 3 ·
//! vibración …", el ritmo del pulso y la amplitud de la sacudida, que se cuenta desde
//! el inicio del nivel porque Haptics vuelve a empezar el patrón en ese momento.
//!
//! Refresco: un Timer cada REFRESH_MS mientras se ve (onShow/onHide). Cada tick avisa
//! también a la guardia (onTick) para que escale la alerta a tiempo aunque no lleguen
//! lotes (alerta de prueba con la guardia en pausa).
class AlertView extends WatchUi.View {

    //! Periodo de redibujo (ms): 20 cuadros por segundo, el mismo paso que la sacudida
    //! (AlertVisuals.SHAKE_STEP_MS), así cambia de lado en cada cuadro. La alerta dura
    //! pocos segundos: el costo en batería es pequeño.
    const REFRESH_MS = AlertVisuals.SHAKE_STEP_MS;

    //! Con animaciones reducidas no hay sacudida: 10 cuadros por segundo bastan para el
    //! pulso lento y las ondas del ícono.
    const REFRESH_REDUCED_MS = 100;

    //! Ícono (milésimas del lado; fr165 en px): centro vertical (71), radio del círculo
    //! (28) y grosor de su trazo y de las ondas (3); teléfono de 12×20 con trazo de 2 y,
    //! a cada lado, una barra de vibración de 10 px de alto a 13 px del centro.
    const ICON_Y = 182;
    const ICON_RADIUS = 72;
    const ICON_PEN = 8;
    const PHONE_W = 31;
    const PHONE_H = 51;
    const PHONE_PEN = 6;
    const BAR_OFFSET = 33;
    const BAR_HEIGHT = 26;

    //! Borde negro del botón "Estoy despierto" (milésimas del lado; fr165: 3 px).
    const BUTTON_BORDER = 8;

    //! Centro vertical de "¡DESPIERTA!" y separación con la línea de nivel (milésimas).
    const TITLE_Y = 320;
    const LINE_GAP = 4;

    //! Durante la entrada, los textos aparecen a partir de esta fracción (el disco ya
    //! cubre casi toda la pantalla).
    const ENTRANCE_TEXT_FROM = 0.5f;

    //! Al subir de nivel, el color nuevo crece desde el centro en este tiempo (ms), como
    //! en la entrada pero sin el rebote del botón.
    const TRANSITION_MS = AlertVisuals.ENTRANCE_MS;

    private var _alerts as AlertController;
    private var _onTick as Method() as Void;

    //! Vibración efectiva de la alerta: la del ajuste, u OFF si el reloj no vibra.
    private var _vibration as VibrationLevel.Id;

    //! Ajuste "Animaciones reducidas".
    private var _reduced as Boolean;

    //! Nivel con el que se formateó _levelLine (se rehace al subir).
    private var _shownLevel as Number = 0;
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

    //! onTick: se llama en cada cuadro antes de dibujar (GuardController.onAlertTick).
    //! vibration: la vibración que de verdad suena (OFF si está apagada o sin motor).
    //! reduced: ajuste "Animaciones reducidas".
    function initialize(alerts as AlertController, onTick as Method() as Void,
            vibration as VibrationLevel.Id, reduced as Boolean) {
        View.initialize();
        _alerts = alerts;
        _onTick = onTick;
        _vibration = vibration;
        _reduced = reduced;
    }

    function onLayout(dc as Dc) as Void {
        var layout = new RoundLayout(dc.getWidth(), dc.getHeight());
        _layout = layout;
        _wakeUp = text(Rez.Strings.AlertWakeUp);
        _imAwake = text(Rez.Strings.ButtonImAwake);
        updateLevelLine();
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
        timer.start(method(:onTick), _reduced ? REFRESH_REDUCED_MS : REFRESH_MS, true);
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
        _onTick.invoke();
        WatchUi.requestUpdate();
    }

    //! "Nivel N de 3 · vibración …" del nivel actual; solo se rehace si cambió.
    private function updateLevelLine() as Void {
        var level = _alerts.level();
        if (level == _shownLevel) {
            return;
        }
        _levelLine = Lang.format(text(Rez.Strings.AlertLevelLineFormat),
            [levelText(level), vibrationText(level)]);
        _shownLevel = level;
    }

    function onUpdate(dc as Dc) as Void {
        var layout = _layout;
        if (layout == null) {
            return;
        }
        updateLevelLine();
        var level = _alerts.level();
        var now = System.getTimer();
        var elapsed = _alerts.elapsedMs(now);
        // Pulso, sacudida y ondas cuentan desde el inicio del nivel: Haptics vuelve a
        // empezar el patrón al subir, así que la sacudida sigue a los pulsos del motor.
        var levelElapsed = _alerts.levelElapsedMs(now);
        // Pulso de brillo lento (< 1 ciclo/s) y, en el nivel 3, rojo intenso ↔ rojo oscuro.
        var background = AlertnessColors.alertPulseColor(level,
            AlertVisuals.pulse(level, _reduced, levelElapsed));
        var foreground = AlertnessColors.alertTextColor(level);
        var dx = AlertVisuals.shakeOffset(level, _vibration, _reduced, levelElapsed);

        Draw.enableAntiAlias(dc);
        var progress = AlertVisuals.entranceProgress(elapsed);
        if (progress < 1.0f) {
            drawEntrance(dc, layout, elapsed, progress, background, foreground, dx);
            return;
        }
        if (level > _alerts.startLevel() && levelElapsed < TRANSITION_MS) {
            drawLevelTransition(dc, layout, level, levelElapsed, background, foreground, dx);
            return;
        }
        Draw.clear(dc, background);
        drawContent(dc, layout, levelElapsed, dx, background, foreground, 1.0f);
    }

    //! Subida de nivel: el color del nivel nuevo crece desde el centro sobre el del
    //! anterior. Los textos cambian al color del nivel nuevo cuando el disco ya cubre
    //! casi todo (ENTRANCE_TEXT_FROM); antes conservan el del anterior, para que el
    //! contraste no caiga ni un cuadro.
    private function drawLevelTransition(dc as Dc, layout as RoundLayout, level as Number,
            levelElapsed as Number, background as Number, foreground as Number, dx as Number) as Void {
        var t = levelElapsed / TRANSITION_MS.toFloat();
        Draw.clear(dc, AlertnessColors.alertBackgroundColor(level - 1));
        dc.setColor(background, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(layout.centerX, layout.centerY, (layout.radius * t).toNumber() + 1);
        if (t < ENTRANCE_TEXT_FROM) {
            var previous = AlertnessColors.alertBackgroundColor(level - 1);
            drawContent(dc, layout, levelElapsed, dx, previous,
                AlertnessColors.alertTextColor(level - 1), 1.0f);
            return;
        }
        drawContent(dc, layout, levelElapsed, dx, background, foreground, 1.0f);
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
        // Botón blanco con borde y texto negros en los tres niveles (diseño web).
        var rect = new Rect(b.centerX() - w / 2 + dx, b.centerY() - h / 2, w, h);
        Draw.largeButton(dc, rect, _imAwake, Typography.BODY, Palette.WHITE, Palette.BLACK);
        var pen = layout.scaled(BUTTON_BORDER);
        var inset = pen / 2;
        dc.setPenWidth(pen);
        dc.setColor(Palette.BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(rect.x + inset, rect.y + inset, rect.width - pen,
            rect.height - pen, rect.height / 2 - inset);
        dc.setPenWidth(1);
    }

    //! Ícono de vibración del diseño web: un círculo con un teléfono dentro y una barra
    //! a cada lado, y AlertVisuals.RIPPLES ondas: anillos de 3 px del color del texto
    //! que crecen de 1× a 1,25× el radio del círculo y se desvanecen hacia el fondo en
    //! 1,1 s, la segunda 0,55 s después. Sin vibración no hay ondas.
    private function drawIcon(dc as Dc, layout as RoundLayout, cx as Number,
            elapsed as Number, background as Number, foreground as Number) as Void {
        var cy = layout.scaled(ICON_Y);
        var radius = layout.scaled(ICON_RADIUS);
        var pen = layout.scaled(ICON_PEN);
        if (pen < 2) {
            pen = 2;
        }

        dc.setPenWidth(pen);
        var waves = _vibration == VibrationLevel.OFF ? 0 : AlertVisuals.RIPPLES;
        for (var i = 0; i < waves; i++) {
            var progress = AlertVisuals.rippleProgress(i, elapsed);
            if (progress < 0.0f) {
                continue;
            }
            dc.setColor(ColorMath.blend(foreground, background, AlertVisuals.rippleAlpha(progress)),
                Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, radius * AlertVisuals.rippleScale(progress));
        }
        dc.setColor(foreground, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, radius);

        // Teléfono y barras de vibración.
        var w = layout.scaled(PHONE_W);
        var h = layout.scaled(PHONE_H);
        dc.setPenWidth(layout.scaled(PHONE_PEN));
        dc.drawRoundedRectangle(cx - w / 2, cy - h / 2, w, h, w / 4);
        var bar = layout.scaled(BAR_OFFSET);
        var barHalf = layout.scaled(BAR_HEIGHT) / 2;
        dc.drawLine(cx - bar, cy - barHalf, cx - bar, cy + barHalf);
        dc.drawLine(cx + bar, cy - barHalf, cx + bar, cy + barHalf);
        dc.setPenWidth(1);
    }

    private function levelText(level as Number) as String {
        if (level <= 1) {
            return text(Rez.Strings.AlertLevel1);
        }
        return text(level == 2 ? Rez.Strings.AlertLevel2 : Rez.Strings.AlertLevel3);
    }

    private function vibrationText(level as Number) as String {
        if (_vibration == VibrationLevel.OFF) {
            return text(Rez.Strings.AlertVibrationOff);
        }
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
