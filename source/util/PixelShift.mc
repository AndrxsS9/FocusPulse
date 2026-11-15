import Toybox.Lang;

//! Desplazamiento anti quemado (burn-in) de la pantalla AMOLED.
//!
//! La hora, la batería, la fecha, el anillo y el botón de la esfera ocupan siempre los
//! mismos píxeles; en guardias largas, eso es lo que quema un AMOLED. Cada minuto la
//! esfera entera se mueve a la siguiente posición de un ciclo de STEPS posiciones
//! alrededor del centro, a 2 px como mucho en cada eje (2,8 px en diagonal):
//!
//!     (0,0) → (2,0) → (2,2) → (0,2) → (−2,2) → (−2,0) → (−2,−2) → (0,−2) → (2,−2) → (0,0)…
//!
//! - Entre dos posiciones seguidas (también al cerrar el ciclo) hay 2 px como mucho por
//!   eje: el salto no se nota.
//! - La media de las posiciones es (0, 0): ningún lado del anillo pasa más tiempo
//!   encendido que el otro.
//! - Se mueve todo junto (RoundLayout.shiftTo), así que el diseño redondo no cambia: el
//!   anillo exterior queda a 7 px del borde y 2,8 px no lo sacan de la pantalla.
//!
//! El paso sale del reloj (minutos Unix), no de un contador: sigue avanzando con la app
//! en pausa y no necesita timer. No aplica a la alerta, que dura pocos segundos.
//! Lógica pura: no depende de WatchUi ni Graphics.
module PixelShift {

    //! Duración de cada posición (s).
    const STEP_SECONDS = 60;

    //! Desplazamiento (px) de cada posición del ciclo.
    const XS = [0, 2, 2, 0, -2, -2, -2, 0, 2];
    const YS = [0, 0, 2, 2, 2, 0, -2, -2, -2];

    //! Posiciones del ciclo (un ciclo dura STEPS minutos).
    const STEPS = 9;

    //! Posición del ciclo (0..STEPS-1) en el instante nowSec (segundos Unix).
    function stepAt(nowSec as Number) as Number {
        var step = (nowSec / STEP_SECONDS) % STEPS;
        return step < 0 ? step + STEPS : step;
    }

    function offsetX(step as Number) as Number {
        return (XS as Array<Number>)[step % STEPS];
    }

    function offsetY(step as Number) as Number {
        return (YS as Array<Number>)[step % STEPS];
    }
}
