import Toybox.Lang;
import Toybox.WatchUi;

//! Textos localizados del modo demo, compartidos por el menú principal, la esfera y el
//! menú de depuración.
module DemoText {

    //! Nombre completo del escenario ("Tecleo activo", "Inactividad prolongada"…).
    function scenarioName(scenario as AccelScenario.Id) as String {
        switch (scenario) {
            case AccelScenario.TYPING:
                return text(Rez.Strings.DemoActiveTyping);
            case AccelScenario.NOD:
                return text(Rez.Strings.DemoSimulateNod);
            case AccelScenario.INACTIVITY:
                return text(Rez.Strings.DemoProlongedInactivity);
            case AccelScenario.MANUAL:
                return text(Rez.Strings.DemoManual);
            case AccelScenario.GLANCE:
                return text(Rez.Strings.DemoGlance);
            default:
                return text(Rez.Strings.DemoNormalMovement);
        }
    }

    //! Nombre corto para la línea de la esfera ("Tecleo activo", "Inactividad"…).
    function scenarioShortName(scenario as AccelScenario.Id) as String {
        switch (scenario) {
            case AccelScenario.TYPING:
                return text(Rez.Strings.DemoShortTyping);
            case AccelScenario.NOD:
                return text(Rez.Strings.DemoShortNod);
            case AccelScenario.INACTIVITY:
                return text(Rez.Strings.DemoShortInactivity);
            case AccelScenario.MANUAL:
                return text(Rez.Strings.DemoShortManual);
            case AccelScenario.GLANCE:
                return text(Rez.Strings.DemoShortGlance);
            default:
                return text(Rez.Strings.DemoShortNormal);
        }
    }

    function text(id as ResourceId) as String {
        return WatchUi.loadResource(id) as String;
    }
}
