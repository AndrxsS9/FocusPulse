import Toybox.Lang;

//! Escenarios de la fuente simulada (SimulatedAccelSource) y del modo demo.
//!
//! Vive en core porque la configuración del modo demo (DemoConfig) y el guion automático
//! (DemoScript) razonan sobre escenarios sin depender de la fuente que los genera.
module AccelScenario {

    enum Id {
        //! Movimiento normal: ruido ±70 mg (triangular) con Z ≈ 975 mg.
        NORMAL = 0,
        //! Tecleo activo: ±250 mg en X/Y y Z 960 ± 220 mg.
        TYPING = 1,
        //! Cabeceo: 3 s de movimiento normal, caída brusca de ~0,5 s hacia el brazo
        //! colgando y después quietud total.
        NOD = 2,
        //! Inactividad prolongada: brazo inerte, ±4 mg alrededor de (22, -18, 996).
        INACTIVITY = 3,
        //! Manual: X/Y/Z fijos (SimulatedAccelSource.setManual) con ruido de ±4 mg. Solo
        //! se elige desde el menú de depuración.
        MANUAL = 4,
        //! Mirar la hora y quedarse leyendo (negativo difícil, fase 10): giro rápido de la
        //! muñeca, 6 s con el brazo sostenido y la esfera inclinada, y vuelta al
        //! movimiento normal, cada 12 s. No debe dar cabeceo.
        GLANCE = 5
    }

    //! Número de escenarios (para recorrerlos en el selector de depuración).
    const COUNT = 6;

    //! true si value es un AccelScenario.Id válido (p. ej. al leerlo de Storage).
    function isValid(value as Object?) as Boolean {
        return value instanceof Number && value >= 0 && value < COUNT;
    }
}
