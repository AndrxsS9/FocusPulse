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

    //! Pista del anillo de nivel de alerta de la esfera principal (parte sin avance).
    //! Un punto más oscura que BORDER para que el avance destaque en el borde.
    const RING_TRACK = 0x1A1F27;

    //! Fondo de la píldora de estado en pausa o con un aviso (diseño web).
    const PILL = 0x1A1F27;

    //! Fondo cian tenue de la píldora "Guardia activa" (diseño web).
    const PILL_ACTIVE = 0x0F2A36;

    //! Borde marcado: contorno de controles y muestras de color.
    const BORDER_STRONG = 0x2E3743;

    // --- Texto ---------------------------------------------------------------

    //! Texto principal.
    const TEXT = 0xF5F7FA;

    //! Texto secundario (estados, ayudas, etiquetas).
    const TEXT_SECONDARY = 0x9AA4B2;

    //! Texto suave, entre TEXT y TEXT_SECONDARY: porcentaje de la batería (diseño web).
    const TEXT_SOFT = 0xC9D1DB;

    //! Negro puro: texto, borde y botón de las alertas de nivel 1 y 2, y color con el
    //! que se mezcla el fondo de la alerta en su pulso de brillo (diseño web).
    const BLACK = 0x000000;

    //! Blanco puro: solo para texto sobre RED_INTENSE (alerta de nivel 3), donde
    //! TEXT se queda en 4,47:1 y el blanco llega a 4,8:1.
    const WHITE = 0xFFFFFF;

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

    //! Ámbar claro: segundo contorno del orbe IA con el puntaje en la banda ámbar.
    const AMBER_LIGHT = 0xFFD27A;

    //! Rojo: nivel de alerta bajo (somnolencia) sobre fondo oscuro.
    const RED = 0xFF5A5A;

    //! Rojo claro: segundo contorno del orbe IA con el puntaje en la banda roja.
    const RED_LIGHT = 0xFF8A8A;

    //! Rojo intenso: fondo de la alerta de nivel 3 (alterna con RED_DARK).
    const RED_INTENSE = 0xE01E1E;

    //! Rojo oscuro: segundo color del parpadeo de la alerta de nivel 3.
    const RED_DARK = 0x6A0000;

    //! Naranja: fondo de la alerta de nivel 1.
    const ORANGE = 0xFF8A1F;

    //! Naranja intenso: fondo de la alerta de nivel 2 (entre ORANGE y RED_INTENSE).
    const ORANGE_DEEP = 0xFF5A1F;
}
