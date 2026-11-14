import Toybox.Lang;

//! Umbrales del detector que cambian con el ajuste "Sensibilidad" (fase 11).
//!
//! | Umbral | Baja | Media (siempre) | Alta |
//! |---|---|---|---|
//! | Sacudida que abre una caída | 440 mg | 400 mg | 340 mg |
//! | Inclinación de la caída | 45° | 35° | 28° |
//! | Inactividad prolongada | 90 s | 60 s | 45 s |
//! | Inactividad en modo demo | 12 s | 8 s | 6 s |
//!
//! Media son los valores de las fases 6–10 (DrowsinessDetector.NOD_JERK_MIN, …). La
//! inactividad escala ×1,5 en Baja y ×0,75 en Alta, también en modo demo. En Baja la
//! sacudida queda por debajo del pico del cabeceo simulado (≈ 464 mg), para que la demo
//! siga funcionando con cualquier sensibilidad. Lo que no cambia: el límite de sacudida
//! "calmada" (50 mg), los 5 s para llegar a la quietud y el refractario, que no son de
//! sensibilidad sino de cómo se mide.
//!
//! Lógica pura; los valores y su efecto en el dataset sintético están en
//! docs/DETECTOR.md §3.6.
class DetectorThresholds {

    //! Sacudida mínima (mg) que abre una caída candidata, por sensibilidad.
    static const NOD_JERK_MIN = [440, 400, 340];

    //! Cambio de inclinación mínimo (grados) de la caída, por sensibilidad.
    static const NOD_TILT_MIN = [45.0f, 35.0f, 28.0f];

    //! Quietud continua (ms) que dispara la inactividad, por sensibilidad.
    static const INACTIVITY_MS = [90000, 60000, 45000];
    static const INACTIVITY_DEMO_MS = [12000, 8000, 6000];

    var nodJerkMin as Number;
    var nodTiltMin as Float;
    var inactivityMs as Number;
    var inactivityDemoMs as Number;

    function initialize(level as SensitivityLevel.Id) {
        var i = level as Number;
        if (i < 0 || i >= SensitivityLevel.COUNT) {
            i = SensitivityLevel.MEDIUM as Number;
        }
        nodJerkMin = (NOD_JERK_MIN as Array<Number>)[i];
        nodTiltMin = (NOD_TILT_MIN as Array<Float>)[i];
        inactivityMs = (INACTIVITY_MS as Array<Number>)[i];
        inactivityDemoMs = (INACTIVITY_DEMO_MS as Array<Number>)[i];
    }
}
