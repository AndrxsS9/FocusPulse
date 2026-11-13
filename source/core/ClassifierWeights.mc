import Toybox.Lang;

//! Pesos del clasificador de estado (StateClassifier): regresión logística multiclase.
//!
//! Este archivo es solo datos y está pensado para generarse desde Python en la fase de
//! IA (ml/), con el mismo formato que scikit-learn:
//!
//!     x' = (x − FEATURE_MEAN) / FEATURE_SCALE            # StandardScaler.mean_, .scale_
//!     z  = COEF · x' + INTERCEPT                        # LogisticRegression.coef_, .intercept_
//!     p  = softmax(z)                                   # multi_class="multinomial"
//!
//! - Filas de COEF e INTERCEPT: clases en el orden de DrowsinessClass (Activo, Normal,
//!   Cabeceo, Inerte).
//! - Columnas de COEF, FEATURE_MEAN y FEATURE_SCALE: características en el orden de
//!   StateClassifier.FEATURE_* (ln(varianza + 1), sacudida del lote en mg, segundos de
//!   quietud con tope de 30, cambio de inclinación en grados con tope de 90, caída
//!   pendiente 0/1). Quien genere el archivo debe calcularlas igual.
//!
//! **v1:** pesos ajustados a mano con los escenarios simulados; la escala solo pone las
//! características en rangos parecidos (media 0). Ver docs/DETECTOR.md.
module ClassifierWeights {

    //! Identificador de los pesos (se muestra en la depuración y en las pruebas).
    const VERSION = "v1-manual";

    const FEATURE_MEAN = [0.0f, 0.0f, 0.0f, 0.0f, 0.0f];
    const FEATURE_SCALE = [3.0f, 400.0f, 10.0f, 30.0f, 1.0f];

    //! Una fila por clase: Activo, Normal, Cabeceo, Inerte. Normal es la referencia
    //! (todo 0); las demás se comparan con ella:
    //! - Activo: varianza y sacudida altas (frontera ≈ 5 600 mg² con sacudida de 400 mg);
    //!   lo frenan la quietud, la inclinación y una caída pendiente.
    //! - Cabeceo: sobre todo la caída pendiente; la inclinación ayuda, pero sola (girar
    //!   la muñeca para mirar la hora) no supera a Normal.
    //! - Inerte: varianza baja (frontera ≈ 100 mg², el umbral de quietud) y la quietud
    //!   acumulada.
    const COEF = [
        [4.0f, 2.5f, -2.0f, -2.0f, -2.0f],
        [0.0f, 0.0f, 0.0f, 0.0f, 0.0f],
        [0.0f, 0.0f, -1.0f, 1.5f, 6.0f],
        [-7.5f, 0.0f, 1.5f, 0.0f, 0.0f]
    ];

    const INTERCEPT = [-14.0f, 0.0f, -5.0f, 11.5f];
}
