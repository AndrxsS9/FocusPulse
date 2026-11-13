import Toybox.Graphics;

//! Roles tipográficos de FocusPulse AI mapeados a fuentes del sistema.
//!
//! Las vistas piden un rol (Typography.TIME, Typography.BODY…) y no una fuente
//! concreta, para poder cambiar el mapeo en un solo lugar (p. ej. por una fuente
//! personalizada para la hora; ver docs/PENDIENTES.md).
//!
//! Ojo: las fuentes FONT_NUMBER_* solo traen dígitos y pocos signos (":", "-"),
//! así que no sirven para letras ni, posiblemente, para "%".
module Typography {

    //! Hora grande al centro de la pantalla principal (solo dígitos y ":").
    const TIME = Graphics.FONT_NUMBER_MEDIUM;

    //! Cifras destacadas: porcentaje de alerta, contadores (solo dígitos).
    const NUMBER = Graphics.FONT_NUMBER_MILD;

    //! Titular de la alerta a pantalla completa ("¡DESPIERTA!").
    const ALERT = Graphics.FONT_LARGE;

    //! Títulos de pantalla y de sección.
    const TITLE = Graphics.FONT_MEDIUM;

    //! Texto corrido, botones y píldoras de estado.
    const BODY = Graphics.FONT_SMALL;

    //! Etiquetas pequeñas: batería, unidades, ayudas.
    const LABEL = Graphics.FONT_XTINY;
}
