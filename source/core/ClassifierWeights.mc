import Toybox.Lang;

//! GENERADO por ml/export_weights.py, no editar a mano. Para cambiarlo, vuelve a
//! entrenar con scripts\train.ps1 (ver ml/README.md y docs/IA.md).
//!
//! Pesos v2 del clasificador de estado (StateClassifier): regresión logística
//! multinomial con 4 clases, entrenada el 2026-11-14 con semilla 20261114 sobre
//! 17376 ventanas de 48 usuarios (528 secuencias).
//! Exactitud en la prueba (usuarios separados, salida suavizada): 93.3 %.
//!
//! **Datos SINTÉTICOS** (ml/generate_dataset.py, a partir de las firmas del simulador):
//! las métricas no son precisión en muñecas reales.
//!
//! La estandarización (StandardScaler) ya va plegada en los pesos, así que el reloj
//! calcula directamente, con x sin normalizar:
//!
//!     z = COEF · x + INTERCEPT,   p = softmax(z)
//!
//! - Filas: clases en el orden de DrowsinessClass (Activo, Normal, Cabeceo, Inerte).
//! - Columnas: características en el orden de StateClassifier.FEATURE_*
//!   (ln_varianza, sacudida_lote, quietud_s, inclinacion_deg, caida_pendiente).
//!
//! Los pesos v1 (a mano) siguen en ClassifierWeightsV1.mc como referencia.
module ClassifierWeights {

    //! Identificador de los pesos.
    const VERSION = "v2";

    //! Fecha del entrenamiento y semilla del dataset y de la división.
    const TRAINED_ON = "2026-11-14";
    const SEED = 20261114;

    //! Tamaño del dataset sintético.
    const DATASET_WINDOWS = 17376;
    const DATASET_USERS = 48;

    //! Exactitud en el conjunto de prueba (0–1), como la ve el reloj (con la EMA).
    const TEST_ACCURACY = 0.93317866f;

    //! Falsos cabeceos en los negativos difíciles de la prueba (mirar la hora, apoyar el
    //! brazo): fracción de episodios con al menos una ventana tomada por Cabeceo
    //! (12 de 48) y fracción de ventanas.
    const FALSE_NOD_RATE = 0.25f;
    const FALSE_NOD_WINDOW_RATE = 0.035683203f;

    //! Una fila por clase: Activo, Normal, Cabeceo, Inerte.
    const COEF = [
        [2.0670521f, 0.004321216f, 0.26801062f, -0.23154828f, -6.378718f],
        [0.08256078f, -0.0075985566f, -0.017406555f, 0.07182521f, -1.0287946f],
        [-0.43059772f, 0.0016180276f, -0.32513365f, 0.10843931f, 2.6035395f],
        [-1.7190152f, 0.001659313f, 0.074529566f, 0.051283766f, 4.8039727f]
    ];

    const INTERCEPT = [-16.800564f, 4.1797457f, 2.6167488f, 10.00407f];
}
