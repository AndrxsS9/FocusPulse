import Toybox.Lang;
import Toybox.Math;

//! Geometría de la pantalla redonda calculada a partir de su tamaño real.
//!
//! Nada de números fijos para 390×390: todas las medidas salen del lado menor
//! de la pantalla (`size`) en milésimas, para que el diseño escale a otros
//! relojes redondos. Se construye con dc.getWidth()/dc.getHeight():
//!
//!     var layout = new RoundLayout(dc.getWidth(), dc.getHeight());
//!
//! No depende de Graphics ni WatchUi (solo recibe números), así que se prueba
//! con Toybox.Test. Esquema y valores para el fr165: docs/DISENO.md.
class RoundLayout {

    //! Tamaño mínimo (px) de cualquier área táctil.
    static const MIN_TOUCH = 44;

    // Proporciones en milésimas del lado menor de la pantalla.
    const RING_MARGIN = 18;      // borde de pantalla → borde exterior del anillo
    const RING_WIDTH = 30;       // grosor del anillo de nivel de alerta
    const CONTENT_PADDING = 20;  // borde interior del anillo → contenido
    const ORB_RADIUS = 250;      // orbe IA detrás de la hora
    const TOP_Y = 130;           // batería / título de la pantalla
    const TIME_Y = 335;          // hora grande (centro del orbe IA)
    const DATE_Y = 470;          // fecha corta bajo la hora
    const SCORE_Y = 558;         // "ALERTA" + porcentaje de alerta
    const PILL_Y = 648;          // píldora de estado
    const BUTTON_TOP = 720;      // borde superior del botón grande
    const BUTTON_HEIGHT = 140;
    const BUTTON_MAX_WIDTH = 580;
    const TOUCH_PADDING = 30;    // margen extra del área táctil del botón
    const FOOTER_Y = 905;        // indicador de página
    const ALERT_BUTTON_TOP = 670;       // "Estoy despierto" en la alerta a pantalla completa
    const ALERT_BUTTON_HEIGHT = 165;
    const ALERT_BUTTON_MAX_WIDTH = 720;
    const FATIGUE_TOP = 520;            // aviso de fatiga: ocupa el puntaje y la píldora
    const FATIGUE_BOTTOM = 705;

    var width as Number;
    var height as Number;

    //! Lado menor de la pantalla; base de todas las proporciones.
    var size as Number;
    var centerX as Number;
    var centerY as Number;

    //! Radio de la pantalla.
    var radius as Number;

    //! Grosor del anillo y radio de su línea central (lo que pide drawArc).
    var ringWidth as Number;
    var ringRadius as Number;

    //! Radio del borde interior del anillo.
    var ringInnerRadius as Number;

    //! Radio del círculo seguro para texto y controles (dentro del anillo).
    var contentRadius as Number;

    var orbRadius as Number;

    //! Centros verticales de cada zona de la pantalla principal.
    var topY as Number;
    var timeY as Number;
    var dateY as Number;
    var scoreY as Number;
    var pillY as Number;
    var footerY as Number;

    //! Botón grande ("Iniciar guardia") y su área táctil, algo mayor.
    var buttonRect as Rect;
    var buttonTouchRect as Rect;

    //! Botón "Estoy despierto" de la alerta y su área táctil. Más alto y más ancho que
    //! el de la esfera (la alerta no tiene píldora ni marca debajo): fr165 258×64 px (área táctil 280×86).
    var alertButtonRect as Rect;
    var alertButtonTouchRect as Rect;

    //! Aviso de fatiga de la esfera ("Micro-sueños repetidos…"): de debajo de la fecha
    //! al botón, tan ancho como permite el círculo seguro. fr165: 300×72 px.
    var fatigueBannerRect as Rect;

    function initialize(screenWidth as Number, screenHeight as Number) {
        width = screenWidth;
        height = screenHeight;
        size = screenWidth < screenHeight ? screenWidth : screenHeight;
        centerX = screenWidth / 2;
        centerY = screenHeight / 2;
        radius = size / 2;

        ringWidth = max(scaled(RING_WIDTH), 4);
        var ringOuter = radius - scaled(RING_MARGIN);
        ringRadius = ringOuter - ringWidth / 2;
        ringInnerRadius = ringOuter - ringWidth;
        contentRadius = ringInnerRadius - scaled(CONTENT_PADDING);
        orbRadius = scaled(ORB_RADIUS);

        topY = toScreenY(TOP_Y);
        timeY = toScreenY(TIME_Y);
        dateY = toScreenY(DATE_Y);
        scoreY = toScreenY(SCORE_Y);
        pillY = toScreenY(PILL_Y);
        footerY = toScreenY(FOOTER_Y);

        var buttonHeight = max(scaled(BUTTON_HEIGHT), MIN_TOUCH);
        var buttonTop = toScreenY(BUTTON_TOP);
        var buttonWidth = stadiumWidth(buttonTop + buttonHeight / 2, buttonHeight);
        var maxWidth = scaled(BUTTON_MAX_WIDTH);
        if (buttonWidth > maxWidth) {
            buttonWidth = maxWidth;
        }
        buttonRect = new Rect(centerX - buttonWidth / 2, buttonTop, buttonWidth, buttonHeight);
        var pad = scaled(TOUCH_PADDING);
        buttonTouchRect = buttonRect.inflate(pad, pad).withMinSize(MIN_TOUCH);

        var alertHeight = max(scaled(ALERT_BUTTON_HEIGHT), MIN_TOUCH);
        var alertTop = toScreenY(ALERT_BUTTON_TOP);
        var alertWidth = stadiumWidth(alertTop + alertHeight / 2, alertHeight);
        var alertMax = scaled(ALERT_BUTTON_MAX_WIDTH);
        if (alertWidth > alertMax) {
            alertWidth = alertMax;
        }
        alertButtonRect = new Rect(centerX - alertWidth / 2, alertTop, alertWidth, alertHeight);
        alertButtonTouchRect = alertButtonRect.inflate(pad, pad).withMinSize(MIN_TOUCH);

        var bannerTop = toScreenY(FATIGUE_TOP);
        var bannerBottom = toScreenY(FATIGUE_BOTTOM);
        var bannerWidth = safeWidthBetween(bannerTop, bannerBottom);
        fatigueBannerRect = new Rect(centerX - bannerWidth / 2, bannerTop, bannerWidth,
            bannerBottom - bannerTop);
    }

    //! Convierte milésimas del lado menor a píxeles.
    function scaled(permille as Number) as Number {
        return size * permille / 1000;
    }

    //! Mitad de la cuerda horizontal de un círculo de radio r (centrado en la
    //! pantalla) a la altura y. 0 si la altura queda fuera del círculo.
    function halfChord(y as Number, r as Number) as Number {
        var dy = absolute(y - centerY);
        if (dy >= r) {
            return 0;
        }
        return Math.sqrt(r * r - dy * dy).toNumber();
    }

    //! Ancho disponible para texto a la altura y sin tocar el anillo.
    function safeWidthAt(y as Number) as Number {
        return 2 * halfChord(y, contentRadius);
    }

    //! Ancho disponible para una caja que va de top a bottom: la cuerda se
    //! estrecha al alejarse del centro, así que manda el borde más lejano.
    function safeWidthBetween(top as Number, bottom as Number) as Number {
        var atTop = safeWidthAt(top);
        var atBottom = safeWidthAt(bottom);
        return atTop < atBottom ? atTop : atBottom;
    }

    //! Ancho máximo de una píldora/botón con extremos redondos (alto h,
    //! centrada en midY) cuyo contorno quede dentro de contentRadius.
    //! Los centros de los semicírculos deben quedar a contentRadius - h/2.
    function stadiumWidth(midY as Number, h as Number) as Number {
        var reach = contentRadius - h / 2;
        var dy = absolute(midY - centerY);
        if (reach <= 0 || dy >= reach) {
            return h;
        }
        var halfFlat = Math.sqrt(reach * reach - dy * dy).toNumber();
        return 2 * halfFlat + h;
    }

    //! true si el toque (x, y) cae en el área táctil del botón grande. Es mayor que el
    //! botón dibujado para perdonar toques imprecisos (docs/DISENO.md §6).
    function hitsButton(x as Number, y as Number) as Boolean {
        return buttonTouchRect.contains(x, y);
    }

    //! true si el toque (x, y) cae en el aviso de fatiga y no en el área táctil del
    //! botón grande (que se solapa unos píxeles con su borde inferior y tiene prioridad).
    function hitsFatigueBanner(x as Number, y as Number) as Boolean {
        return fatigueBannerRect.contains(x, y) && !hitsButton(x, y);
    }

    //! true si el toque (x, y) cae en el área táctil de "Estoy despierto".
    function hitsAlertButton(x as Number, y as Number) as Boolean {
        return alertButtonTouchRect.contains(x, y);
    }

    private function toScreenY(permille as Number) as Number {
        return (height - size) / 2 + scaled(permille);
    }

    private function absolute(value as Number) as Number {
        return value < 0 ? -value : value;
    }

    private function max(a as Number, b as Number) as Number {
        return a > b ? a : b;
    }
}
