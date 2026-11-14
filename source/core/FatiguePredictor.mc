import Toybox.Lang;

//! Nivel de fatiga de la guardia.
module FatigueLevel {

    enum Id {
        LOW = 0,
        MODERATE = 1,
        HIGH = 2
    }
}

//! Predictor de fatiga **por reglas**: cada resultado se puede explicar con una frase.
//! No aprende ni usa pesos; mira los episodios (alertas del detector) de la guardia
//! actual.
//!
//! Entradas: los episodios (AlertLog) con su hora (startMs, en ms **desde el inicio de
//! la guardia**), su tiempo de respuesta (null si no se respondió) y su nivel máximo;
//! la duración de la guardia hasta ahora (nowMs, en la misma escala), la ventana y
//! desde cuándo contar (sinceMs: 0, o el final del último descanso completo).
//!
//! Reglas, en este orden:
//!
//! 1. **Episodios recientes** en la ventana (los últimos 30 min; 5 min en modo demo):
//!    0 → Bajo, 1–2 → Moderado, 3 o más → Alto. Un episodio justo en el borde
//!    (hace exactamente 30 min) cuenta.
//! 2. **Respuestas cada vez más lentas**: si las 3 últimas respuestas de la guardia son
//!    cada una más lenta que la anterior y la última tarda al menos 1 s más que la
//!    primera, la fatiga sube un nivel (Bajo → Moderado, Moderado → Alto). Las alertas
//!    sin respuesta no entran en la tendencia.
//! 3. **Nivel 3 de alerta**: si alguna alerta de la guardia llegó al nivel 3 (20 s sin
//!    respuesta, o 12 s en demo), la fatiga es al menos Moderada aunque ya no quede
//!    ningún episodio en la ventana.
//!
//! Las reglas 2 y 3 miran toda la guardia, no solo la ventana: si miraran solo la
//! ventana nunca cambiarían nada, porque un episodio en la ventana ya da Moderado y
//! tres dan Alto. Un **descanso completo** reinicia la cuenta: los episodios anteriores
//! a sinceMs no se consideran en ninguna regla.
//!
//! Lógica pura: sin WatchUi, Graphics ni Storage. Probado en tests/FatiguePredictorTest.mc.
module FatiguePredictor {

    //! Ventana de la regla 1 (ms): 30 min con el sensor real, 5 min en modo demo.
    const WINDOW_MS = 1800000;
    const WINDOW_DEMO_MS = 300000;

    //! Regla 1: episodios en la ventana para Moderado y para Alto.
    const MODERATE_EPISODES = 1;
    const HIGH_EPISODES = 3;

    //! Regla 2: respuestas que forman la tendencia y aumento mínimo entre la primera y la
    //! última (ms).
    const TREND_RESPONSES = 3;
    const TREND_MIN_INCREASE_MS = 1000;

    //! Regla 3: nivel de alerta que deja la fatiga al menos en Moderado.
    const MAX_ALERT_LEVEL = 3;

    //! Ventana del modo (ms).
    function windowMsFor(demo as Boolean) as Number {
        return demo ? WINDOW_DEMO_MS : WINDOW_MS;
    }

    //! Nivel de fatiga de la guardia en nowMs (ver las reglas arriba).
    function assess(episodes as AlertLog, nowMs as Number, windowMs as Number,
            sinceMs as Number) as FatigueLevel.Id {
        var level = levelForCount(recentEpisodes(episodes, nowMs, windowMs, sinceMs));
        if (isSlowing(episodes, sinceMs)) {
            level = raise(level);
        }
        if (reachedMaxLevel(episodes, sinceMs) && level == FatigueLevel.LOW) {
            level = FatigueLevel.MODERATE;
        }
        return level;
    }

    //! Regla 1: nivel según los episodios recientes.
    function levelForCount(count as Number) as FatigueLevel.Id {
        if (count >= HIGH_EPISODES) {
            return FatigueLevel.HIGH;
        }
        if (count >= MODERATE_EPISODES) {
            return FatigueLevel.MODERATE;
        }
        return FatigueLevel.LOW;
    }

    //! Episodios con inicio en [nowMs − windowMs, nowMs] y no antes de sinceMs.
    function recentEpisodes(episodes as AlertLog, nowMs as Number, windowMs as Number,
            sinceMs as Number) as Number {
        var from = nowMs - windowMs;
        if (from < sinceMs) {
            from = sinceMs;
        }
        var count = 0;
        for (var i = 0; i < episodes.size(); i++) {
            var start = episodes.get(i).startMs;
            if (start >= from && start <= nowMs) {
                count += 1;
            }
        }
        return count;
    }

    //! Regla 2: las TREND_RESPONSES últimas respuestas (desde sinceMs) van en aumento
    //! estricto y la última supera a la primera en TREND_MIN_INCREASE_MS o más.
    function isSlowing(episodes as AlertLog, sinceMs as Number) as Boolean {
        var times = new Array<Number>[TREND_RESPONSES];
        var found = 0;
        // De la más reciente hacia atrás, solo las respondidas.
        for (var i = episodes.size() - 1; i >= 0 && found < TREND_RESPONSES; i--) {
            var record = episodes.get(i);
            var response = record.responseMs;
            if (record.startMs >= sinceMs && response != null) {
                times[TREND_RESPONSES - 1 - found] = response;
                found += 1;
            }
        }
        if (found < TREND_RESPONSES) {
            return false;
        }
        for (var i = 1; i < TREND_RESPONSES; i++) {
            if (times[i] <= times[i - 1]) {
                return false;
            }
        }
        return times[TREND_RESPONSES - 1] - times[0] >= TREND_MIN_INCREASE_MS;
    }

    //! Regla 3: alguna alerta desde sinceMs llegó al nivel 3.
    function reachedMaxLevel(episodes as AlertLog, sinceMs as Number) as Boolean {
        for (var i = 0; i < episodes.size(); i++) {
            var record = episodes.get(i);
            if (record.startMs >= sinceMs && record.maxLevel >= MAX_ALERT_LEVEL) {
                return true;
            }
        }
        return false;
    }

    //! Un nivel más, sin pasar de Alto.
    function raise(level as FatigueLevel.Id) as FatigueLevel.Id {
        return level == FatigueLevel.LOW ? FatigueLevel.MODERATE : FatigueLevel.HIGH;
    }
}
