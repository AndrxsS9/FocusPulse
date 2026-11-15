import Toybox.Lang;
import Toybox.Math;

//! Curvas de las animaciones pequeñas de la esfera con la guardia activa (MainView),
//! con los valores del diseño web. Lógica pura: el tiempo entra como parámetro (ms de
//! System.getTimer()) y no se dibuja nada.
//!
//! - **Arco de escaneo**: un arco cian al 55 % de 46 px de largo y 3 px de trazo gira
//!   en sentido horario sobre un círculo de radio 164 px, una vuelta cada 2,8 s. Las
//!   medidas son píxeles del diseño (pantalla de 390 px); quien dibuja las escala.
//! - **Ping** del punto de "Guardia activa": un círculo detrás del punto crece de 1× a
//!   2,6× su radio y se desvanece de 0,8 a 0 de opacidad en 1,6 s, y vuelve a empezar.
module GuardVisuals {

    //! Arco de escaneo: radio y trazo (px del diseño), largo (px a lo largo del arco),
    //! duración de una vuelta (ms) y opacidad (milésimas).
    const SCAN_RADIUS = 164;
    const SCAN_PEN = 3;
    const SCAN_LENGTH_PX = 46;
    const SCAN_PERIOD_MS = 2800;
    const SCAN_ALPHA = 550;

    //! Ping: duración (ms), escala inicial y final del radio y opacidad inicial y final
    //! (milésimas).
    const PING_PERIOD_MS = 1600;
    const PING_SCALE_FROM = 1000;
    const PING_SCALE_TO = 2600;
    const PING_ALPHA_FROM = 800;
    const PING_ALPHA_TO = 0;

    //! Largo del arco de escaneo en grados (46 px sobre radio 164 ≈ 16°). No depende de
    //! la escala: largo y radio crecen juntos.
    function scanLengthDegrees() as Number {
        return (SCAN_LENGTH_PX * 180.0f / (Math.PI * SCAN_RADIUS) + 0.5f).toNumber();
    }

    //! Ángulo de la cabeza del arco en grados de drawArc (0° = 3 en punto, sentido
    //! antihorario), en 0..359: sale de las 12 (90°) y avanza en sentido horario.
    function scanHeadDegrees(nowMs as Number) as Number {
        var t = nowMs % SCAN_PERIOD_MS;
        if (t < 0) {
            t += SCAN_PERIOD_MS;
        }
        return normalizeDegrees(90 - t * 360 / SCAN_PERIOD_MS);
    }

    //! Avance del ping dentro de su ciclo, de 0 (recién empezado) a casi 1.
    function pingProgress(nowMs as Number) as Float {
        var t = nowMs % PING_PERIOD_MS;
        if (t < 0) {
            t += PING_PERIOD_MS;
        }
        return t / PING_PERIOD_MS.toFloat();
    }

    //! Escala del radio del ping (1 → 2,6) para un avance 0–1.
    function pingScale(progress as Float) as Float {
        return (PING_SCALE_FROM + (PING_SCALE_TO - PING_SCALE_FROM) * clamp01(progress)) / 1000.0f;
    }

    //! Opacidad del ping (milésimas, 800 → 0) para un avance 0–1.
    function pingAlpha(progress as Float) as Number {
        return (PING_ALPHA_FROM + (PING_ALPHA_TO - PING_ALPHA_FROM) * clamp01(progress) + 0.5f).toNumber();
    }

    //! Ángulo en 0..359.
    function normalizeDegrees(degrees as Number) as Number {
        var d = degrees % 360;
        return d < 0 ? d + 360 : d;
    }

    function clamp01(x as Float) as Float {
        return x < 0.0f ? 0.0f : (x > 1.0f ? 1.0f : x);
    }
}
