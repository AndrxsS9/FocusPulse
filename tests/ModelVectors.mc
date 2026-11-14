import Toybox.Lang;

//! GENERADO por ml/export_weights.py, no editar a mano.
//!
//! Ventanas del conjunto de prueba (datos SINTÉTICOS), 4 por clase, con las
//! probabilidades sin suavizar que calcula Python con los pesos v2.
//! classifierMatchesPythonProbabilities (StateClassifierTest.mc) comprueba que
//! StateClassifier.probabilitiesInto da lo mismo en el reloj.
(:test)
class ModelVectors {

    //! Versión de ClassifierWeights con la que se calcularon.
    static const VERSION = "v2";

    //! Características sin normalizar, en el orden de StateClassifier.FEATURE_*.
    static const FEATURES = [
        [9.582204f, 555.0f, 0.0f, 1.5501549f, 0.0f],
        [10.071698f, 845.0f, 0.0f, 1.7245362f, 0.0f],
        [10.143778f, 644.0f, 0.0f, 3.0201225f, 0.0f],
        [9.309606f, 587.0f, 0.0f, 1.5893008f, 0.0f],
        [7.115295f, 169.0f, 0.0f, 0.25256422f, 0.0f],
        [6.895843f, 128.0f, 0.0f, 0.19382666f, 0.0f],
        [7.478368f, 165.0f, 0.0f, 8.900354f, 0.0f],
        [6.58215f, 80.0f, 0.0f, 14.379345f, 0.0f],
        [7.1598825f, 14.0f, 0.0f, 66.214386f, 1.0f],
        [6.2563863f, 11.0f, 0.0f, 58.942017f, 1.0f],
        [7.5747433f, 361.0f, 0.0f, 24.131662f, 1.0f],
        [6.269551f, 7.0f, 0.0f, 30.732769f, 1.0f],
        [1.675675f, 8.0f, 0.0f, 0.027976455f, 0.0f],
        [1.9418448f, 11.0f, 19.0f, 0.01978234f, 0.0f],
        [1.8353935f, 8.0f, 27.0f, 0.027976455f, 0.0f],
        [2.637456f, 14.0f, 2.0f, 0.01978234f, 0.0f]
    ];

    //! Probabilidades de Activo, Normal, Cabeceo e Inerte.
    static const PROBABILITIES = [
        [0.98092353f, 0.014996325f, 0.0040535f, 0.00002665804f],
        [0.99921656f, 0.00019225234f, 0.0005890967f, 0.0000020661314f],
        [0.9959832f, 0.002701188f, 0.0013117844f, 0.00000386134f],
        [0.9748443f, 0.017690016f, 0.0073966417f, 0.00006905065f],
        [0.007018142f, 0.9636677f, 0.025111493f, 0.00420266f],
        [0.0028638314f, 0.9734049f, 0.019413374f, 0.0043178797f],
        [0.0010038498f, 0.96948487f, 0.027737765f, 0.0017735143f],
        [0.0000117054f, 0.9717662f, 0.024587683f, 0.0036344316f],
        [0.0000000000000033109366f, 0.27274314f, 0.7042448f, 0.02301211f],
        [0.000000000000003896025f, 0.22002737f, 0.67321396f, 0.106758654f],
        [0.000000042381863f, 0.0699163f, 0.7653539f, 0.16472974f],
        [0.00000000003158041f, 0.3499197f, 0.36486834f, 0.28521195f],
        [0.0000000012417115f, 0.05293458f, 0.0050577912f, 0.9420076f],
        [0.00000014190218f, 0.015154853f, 0.0000037505297f, 0.9848412f],
        [0.0000004452717f, 0.006221599f, 0.0000001349384f, 0.9937778f],
        [0.000000059917724f, 0.19875117f, 0.006618879f, 0.7946299f]
    ];
}
