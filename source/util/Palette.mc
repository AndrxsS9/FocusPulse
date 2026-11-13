//! Paleta de colores de FocusPulse AI (tokens de diseño).
//!
//! Pensada para la pantalla AMOLED del Forerunner 165: fondo casi negro
//! (menos consumo y menos riesgo de quemado) con texto claro y acentos de color
//! en superficies pequeñas. Solo contiene constantes; la elección de color según
//! el nivel de alerta vive en source/core/AlertnessColors.mc.
//!
//! Uso y contraste de cada token: docs/DISENO.md.
module Palette {

    // --- Superficies ---------------------------------------------------------

    //! Fondo de todas las pantallas (salvo la alerta a pantalla completa).
    const BACKGROUND = 0x07090C;

    //! Superficie elevada: relleno de píldoras y tarjetas pequeñas.
    const SURFACE = 0x11151B;

    //! Borde tenue: pista del anillo de progreso, separadores.
    const BORDER = 0x1C222B;

    //! Borde marcado: contorno de controles y muestras de color.
    const BORDER_STRONG = 0x2E3743;

    // --- Texto ---------------------------------------------------------------

    //! Texto principal.
    const TEXT = 0xF5F7FA;

    //! Texto secundario (estados, ayudas, etiquetas).
    const TEXT_SECONDARY = 0x9AA4B2;

    // --- Acentos -------------------------------------------------------------

    //! Acento cian: marca, guardia activa, nivel de alerta alto (bien despierto).
    const ACCENT = 0x4CC9F0;

    //! Cian claro: brillo del orbe IA y detalles sobre el cian.
    const ACCENT_LIGHT = 0x8BDDF5;

    //! Violeta: tercer anillo del orbe IA.
    const VIOLET = 0xC3A6FF;

    // --- Estados -------------------------------------------------------------

    //! Ámbar: nivel de alerta medio (atención).
    const AMBER = 0xFFB020;

    //! Rojo: nivel de alerta bajo (somnolencia) sobre fondo oscuro.
    const RED = 0xFF5A5A;

    //! Rojo intenso: fondo de la alerta de nivel 3.
    const RED_INTENSE = 0xE01E1E;

    //! Naranja: fondo de la alerta de nivel 1.
    const ORANGE = 0xFF8A1F;

    //! Naranja intenso: fondo de la alerta de nivel 2 (entre ORANGE y RED_INTENSE).
    const ORANGE_DEEP = 0xF2620F;
}
