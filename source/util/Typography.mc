import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Roles tipográficos de FocusPulse AI con las fuentes propias del diseño web.
//!
//! Desde la 1.2.0 los textos del diseño se dibujan con fuentes de mapa de bits propias
//! (BMFont con antialias, resources/fonts/, generadas por scripts/make_fonts.ps1 a partir
//! de las TTF con licencia OFL de assets/fonts/):
//!
//!   - Space Grotesk Bold: la hora (76 px), "¡DESPIERTA!" (42 px) y los títulos (22 px);
//!   - Inter: textos (Medium 13 y 15 px), énfasis (SemiBold 13 y 15 px) y botones (Bold
//!     18 px, ExtraBold 22 px);
//!   - JetBrains Mono SemiBold: cifras con "%" (14 y 22 px).
//!
//! Las vistas piden un rol (Typography.clock, Typography.body…) y nunca una fuente
//! concreta. load() las carga UNA vez al arrancar la app (FocusPulseApp.onStart); hasta
//! entonces (p. ej. en las pruebas) cada rol apunta a la fuente del sistema más parecida.
//! Cada fuente lleva solo los glifos que necesita: clock solo tiene dígitos y ":",
//! alertTitle solo las letras de "¡DESPIERTA!" y "WAKE UP!", y las de cifras solo dígitos,
//! "%", "," y ".". Medidas y licencias: docs/DISENO.md §3.
module Typography {

    //! Hora grande y cuenta atrás del descanso: Space Grotesk Bold 76 px (dígitos y ":").
    var clock as FontType = Graphics.FONT_NUMBER_MEDIUM;

    //! "¡DESPIERTA!" / "WAKE UP!": Space Grotesk Bold 42 px (solo esas letras).
    var alertTitle as FontType = Graphics.FONT_MEDIUM;

    //! Títulos de pantalla: Space Grotesk Bold 22 px.
    var title as FontType = Graphics.FONT_SMALL;

    //! Texto corrido, fecha y filas: Inter Medium 15 px.
    var body as FontType = Graphics.FONT_TINY;

    //! Texto destacado (nivel de la alerta, valores, avisos): Inter SemiBold 15 px.
    var bodyStrong as FontType = Graphics.FONT_TINY;

    //! Etiquetas pequeñas ("ALERTA", motivo de la alerta, ayudas): Inter Medium 13 px.
    var label as FontType = Graphics.FONT_XTINY;

    //! Etiqueta destacada (píldora de estado): Inter SemiBold 13 px.
    var labelStrong as FontType = Graphics.FONT_XTINY;

    //! Botón grande de la esfera y de las pantallas secundarias: Inter Bold 18 px.
    var button as FontType = Graphics.FONT_SMALL;

    //! Botón "Estoy despierto" de la alerta: Inter ExtraBold 22 px.
    var alertButton as FontType = Graphics.FONT_SMALL;

    //! Porcentaje de alerta y cifras destacadas: JetBrains Mono SemiBold 22 px.
    var number as FontType = Graphics.FONT_SMALL;

    //! Batería y cifras de las filas: JetBrains Mono SemiBold 14 px.
    var numberSmall as FontType = Graphics.FONT_XTINY;

    //! Carga las fuentes propias. Se llama una sola vez, al arrancar la app.
    function load() as Void {
        clock = WatchUi.loadResource(Rez.Fonts.TimeBold76) as FontResource;
        alertTitle = WatchUi.loadResource(Rez.Fonts.AlertBold42) as FontResource;
        title = WatchUi.loadResource(Rez.Fonts.TitleBold22) as FontResource;
        body = WatchUi.loadResource(Rez.Fonts.InterMedium15) as FontResource;
        bodyStrong = WatchUi.loadResource(Rez.Fonts.InterSemiBold15) as FontResource;
        label = WatchUi.loadResource(Rez.Fonts.InterMedium13) as FontResource;
        labelStrong = WatchUi.loadResource(Rez.Fonts.InterSemiBold13) as FontResource;
        button = WatchUi.loadResource(Rez.Fonts.InterBold18) as FontResource;
        alertButton = WatchUi.loadResource(Rez.Fonts.InterExtraBold22) as FontResource;
        number = WatchUi.loadResource(Rez.Fonts.MonoSemiBold22) as FontResource;
        numberSmall = WatchUi.loadResource(Rez.Fonts.MonoSemiBold14) as FontResource;
    }

    //! Siguiente fuente más pequeña para un texto que no cabe (Draw.fittingFont), o null
    //! si no hay. Las de texto bajan dentro de la escala de Inter (botón de la alerta →
    //! botón → cuerpo destacado → etiqueta destacada, y cuerpo → etiqueta); el título baja
    //! al cuerpo destacado. Las de un solo uso (hora,
    //! "¡DESPIERTA!", cifras) no bajan: no hay otra fuente con sus glifos. Una fuente del
    //! sistema (FONT_XTINY..FONT_LARGE, numeradas de menor a mayor) baja a la anterior.
    function smaller(font as FontType) as FontType? {
        if (font instanceof Lang.Number) {
            var system = font as Number;
            return system > Graphics.FONT_XTINY && system <= Graphics.FONT_LARGE
                ? (system - 1) as FontDefinition : null;
        }
        if (font == alertButton) {
            return button;
        }
        if (font == button || font == title) {
            return bodyStrong;
        }
        if (font == bodyStrong) {
            return labelStrong;
        }
        if (font == body) {
            return label;
        }
        return null;
    }
}
