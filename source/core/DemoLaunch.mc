import Toybox.Lang;

//! Arranque directo en la demo (ajustes "Iniciar en modo demo" y "Guion automático al
//! abrir", los dos apagados por defecto). Pensado para la sustentación en el simulador:
//! `scripts\run.ps1 -Demo` y `-DemoAuto` los activan antes de abrir la app.
//!
//! | Iniciar en modo demo | Guion automático al abrir | Al abrir la app |
//! |---|---|---|
//! | no | no | como siempre (el modo demo, el que se recordaba) |
//! | sí | no | modo demo activo, guardia en pausa |
//! | — | sí | modo demo activo y, a los SCRIPT_DELAY_MS, el guion automático |
//!
//! Con los dos apagados no se apaga el modo demo: sigue el que se recordaba (DemoStore).
//! El guion solo arranca si a los 3 s la guardia sigue en pausa y nadie inició el guion:
//! si el usuario ya tomó el control, no se le pisa.
//!
//! Lógica pura: solo lee Settings y recibe el estado como parámetros.
module DemoLaunch {

    //! Espera entre abrir la app y arrancar el guion automático (ms): deja ver la
    //! esfera en pausa antes de que empiece.
    const SCRIPT_DELAY_MS = 3000;

    //! true si al abrir la app hay que activar el modo demo.
    function enablesDemo(settings as Settings) as Boolean {
        return settings.demoOnStart || settings.demoAutoScript;
    }

    //! true si al abrir la app hay que programar el guion automático.
    function schedulesScript(settings as Settings) as Boolean {
        return settings.demoAutoScript;
    }

    //! true si, al cumplirse la espera, el guion debe arrancar: la guardia sigue en
    //! pausa, el guion no corre ya y el modo demo sigue activo.
    function startsScriptNow(demoEnabled as Boolean, guardActive as Boolean,
            scriptRunning as Boolean) as Boolean {
        return demoEnabled && !guardActive && !scriptRunning;
    }
}
