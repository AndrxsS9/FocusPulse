import Toybox.Lang;

//! Resumen de una guardia: lo que muestra la vista "Resumen de la guardia" al pausar y
//! lo que guarda el historial (SessionHistory).
//!
//! | Campo | Qué es |
//! |---|---|
//! | dateSec | Inicio de la guardia (segundos Unix, Time.now().value()). |
//! | durationMs | De iniciar a pausar, descansos incluidos. |
//! | episodes | Alertas abiertas por el detector (respondidas o no). |
//! | avgResponseMs | Media de las respuestas; null si no se respondió ninguna. |
//! | maxLevel | Nivel de alerta más alto alcanzado (0 sin episodios, 1–3). |
//! | fatigue | Fatiga al terminar (FatiguePredictor). |
//! | demo | true si la guardia corrió (aunque fuera en parte) en modo demo. |
//!
//! Regla para mostrarlo (y guardarlo): **no** si la guardia duró menos de 1 min y no
//! tuvo episodios; una guardia así es casi seguro un toque de prueba y llenaría el
//! historial de ruido. Con un episodio, se muestra aunque haya durado segundos.
//!
//! Persistencia: toStorage() da un arreglo plano de 7 valores simples (barato en
//! memoria y en Storage) y fromStorage() lo valida campo a campo: cualquier valor
//! ausente, de otro tipo o fuera de rango descarta el resumen (null). Lógica pura.
class GuardSummary {

    //! Duración mínima para mostrar una guardia sin episodios (ms).
    static const MIN_DURATION_MS = 60000;

    //! Tamaño del arreglo guardado y valor de "sin respuesta media".
    static const STORAGE_SIZE = 7;
    static const NO_RESPONSE = -1;

    var dateSec as Number;
    var durationMs as Number;
    var episodes as Number;
    var avgResponseMs as Number?;
    var maxLevel as Number;
    var fatigue as FatigueLevel.Id;
    var demo as Boolean;

    function initialize(dateSec as Number, durationMs as Number, episodes as Number,
            avgResponseMs as Number?, maxLevel as Number, fatigue as FatigueLevel.Id,
            demo as Boolean) {
        self.dateSec = dateSec;
        self.durationMs = durationMs < 0 ? 0 : durationMs;
        self.episodes = episodes < 0 ? 0 : episodes;
        self.avgResponseMs = avgResponseMs;
        self.maxLevel = maxLevel;
        self.fatigue = fatigue;
        self.demo = demo;
    }

    //! Resumen a partir de los episodios de la guardia.
    static function fromEpisodes(dateSec as Number, durationMs as Number, log as AlertLog,
            fatigue as FatigueLevel.Id, demo as Boolean) as GuardSummary {
        var average = log.answeredCount() > 0 ? log.averageResponseMs() : null;
        return new GuardSummary(dateSec, durationMs, log.size(), average, log.maxLevel(),
            fatigue, demo);
    }

    //! true si una guardia así merece resumen e historial: 1 min o más, o algún episodio.
    static function shouldShow(durationMs as Number, episodes as Number) as Boolean {
        return durationMs >= MIN_DURATION_MS || episodes > 0;
    }

    function isWorthShowing() as Boolean {
        return shouldShow(durationMs, episodes);
    }

    //! [fecha, duración, episodios, respuesta media (−1 si no hay), nivel máx., fatiga, demo]
    function toStorage() as Array<Number or Boolean> {
        var average = avgResponseMs;
        return [dateSec, durationMs, episodes, average != null ? average : NO_RESPONSE,
            maxLevel, fatigue as Number, demo] as Array<Number or Boolean>;
    }

    //! Resumen leído de Storage, o null si el dato no es válido.
    static function fromStorage(data as Object?) as GuardSummary? {
        if (!(data instanceof Array)) {
            return null;
        }
        var values = data as Array<Object?>;
        if (values.size() != STORAGE_SIZE) {
            return null;
        }
        for (var i = 0; i < STORAGE_SIZE - 1; i++) {
            if (!(values[i] instanceof Number)) {
                return null;
            }
        }
        if (!(values[6] instanceof Boolean)) {
            return null;
        }
        var date = values[0] as Number;
        var duration = values[1] as Number;
        var episodes = values[2] as Number;
        var average = values[3] as Number;
        var maxLevel = values[4] as Number;
        var fatigue = values[5] as Number;
        if (date < 0 || duration < 0 || episodes < 0 || average < NO_RESPONSE
                || maxLevel < 0 || maxLevel > AlertnessColors.MAX_ALERT_LEVEL
                || fatigue < (FatigueLevel.LOW as Number) || fatigue > (FatigueLevel.HIGH as Number)) {
            return null;
        }
        return new GuardSummary(date, duration, episodes, average == NO_RESPONSE ? null : average,
            maxLevel, fatigue as FatigueLevel.Id, values[6] as Boolean);
    }
}
