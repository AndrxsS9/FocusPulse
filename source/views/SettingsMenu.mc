import Toybox.Lang;
import Toybox.WatchUi;

//! Pantalla "Ajustes" (menú principal → Ajustes). Es un Menu2, como el menú principal:
//! ítems a todo el ancho de la pantalla redonda (objetivos táctiles grandes), y cada uno
//! muestra su valor actual en el subtítulo.
//!
//! - Sensibilidad (Baja / Media / Alta) y Vibración (Apagada / Suave / Normal / Fuerte):
//!   submenú con las opciones y el foco en la actual (como "Escenario").
//! - Sonido (solo si el reloj tiene Attention.playTone), Animaciones reducidas,
//!   Confirmación por IA y Grabar actividad: interruptores.
//!
//! Cada cambio se guarda en Application.Properties (AppSettings.save) y se aplica en el
//! acto (GuardController.applySettings), igual que un cambio desde Garmin Connect.
//!
//! **Aviso de alerta solo visual.** Si la vibración queda apagada (aquí o en el reloj) y
//! no hay sonido, el subtítulo de Vibración lo dice ("Apagada · solo visual") y, en el
//! cambio que lleva a ese estado, se abre la pantalla de aviso (NoFeedbackView).
module SettingsMenu {

    const ITEM_SENSITIVITY = :sensitivity;
    const ITEM_VIBRATION = :vibration;
    const ITEM_SOUND = :sound;
    const ITEM_REDUCED = :reducedAnimations;
    const ITEM_AI = :aiConfirmation;
    const ITEM_RECORD = :recordActivity;

    //! Textos de las opciones, en el orden de SensitivityLevel y VibrationLevel.
    const SENSITIVITY_NAMES = [Rez.Strings.SettingValueLow, Rez.Strings.SettingValueMedium,
        Rez.Strings.SettingValueHigh];
    const VIBRATION_NAMES = [Rez.Strings.SettingVibrationOff, Rez.Strings.SettingVibrationSoft,
        Rez.Strings.SettingVibrationNormal, Rez.Strings.SettingVibrationStrong];

    function open(guard as GuardController) as Void {
        var menu = build(guard, null);
        WatchUi.pushView(menu, new SettingsMenuDelegate(guard, menu), WatchUi.SLIDE_LEFT);
    }

    //! Menú con los valores actuales; focus es el ítem seleccionado (null: el primero).
    function build(guard as GuardController, focus as Symbol?) as WatchUi.Menu2 {
        var settings = guard.settings();
        var items = [] as Array<WatchUi.MenuItem>;
        items.add(new WatchUi.MenuItem(DemoText.text(Rez.Strings.SettingSensitivity),
            sensitivityName(settings.sensitivity), ITEM_SENSITIVITY, {}));
        items.add(new WatchUi.MenuItem(DemoText.text(Rez.Strings.SettingVibration),
            vibrationSubLabel(guard), ITEM_VIBRATION, {}));
        if (Haptics.hasToneHardware()) {
            items.add(toggle(Rez.Strings.SettingSound, ITEM_SOUND, settings.sound));
        }
        items.add(toggle(Rez.Strings.SettingReducedAnimations, ITEM_REDUCED, settings.reducedAnimations));
        items.add(toggle(Rez.Strings.SettingAiConfirmation, ITEM_AI, settings.aiConfirmation));
        items.add(toggle(Rez.Strings.SettingRecordActivityShort, ITEM_RECORD, settings.recordActivity));

        var focusIndex = 0;
        for (var i = 0; i < items.size(); i++) {
            if (items[i].getId() == focus) {
                focusIndex = i;
            }
        }
        var menu = new WatchUi.Menu2({
            :title => DemoText.text(Rez.Strings.SettingsTitle),
            :focus => focusIndex
        });
        for (var i = 0; i < items.size(); i++) {
            menu.addItem(items[i]);
        }
        return menu;
    }

    //! Interruptor con "Activado" / "Desactivado" de subtítulo.
    function toggle(label as ResourceId, id as Symbol, enabled as Boolean) as WatchUi.ToggleMenuItem {
        return new WatchUi.ToggleMenuItem(DemoText.text(label),
            {
                :enabled => DemoText.text(Rez.Strings.SettingValueOn),
                :disabled => DemoText.text(Rez.Strings.SettingValueOff)
            },
            id, enabled, {});
    }

    function sensitivityName(level as SensitivityLevel.Id) as String {
        return DemoText.text((SENSITIVITY_NAMES as Array<ResourceId>)[level as Number]);
    }

    function vibrationName(level as VibrationLevel.Id) as String {
        return DemoText.text((VIBRATION_NAMES as Array<ResourceId>)[level as Number]);
    }

    //! Subtítulo de Vibración: el valor, y "· solo visual" si la alerta no vibraría ni
    //! sonaría.
    function vibrationSubLabel(guard as GuardController) as String {
        var name = vibrationName(guard.settings().vibration);
        if (!guard.isVisualOnlyAlert()) {
            return name;
        }
        return Lang.format(DemoText.text(Rez.Strings.WarningSubFormat),
            [name, DemoText.text(Rez.Strings.WarningVisualOnlyTag)]);
    }

    //! Guarda y aplica settings (una copia ya modificada de los ajustes en uso) y pone al
    //! día los subtítulos de menu. Devuelve true si con este cambio la alerta pasó a ser
    //! solo visual (quien llama abre el aviso).
    function commit(guard as GuardController, menu as WatchUi.Menu2, settings as Settings) as Boolean {
        var wasVisualOnly = guard.isVisualOnlyAlert();
        AppSettings.save(settings);
        guard.applySettings(settings);
        setSubLabel(menu, ITEM_SENSITIVITY, sensitivityName(settings.sensitivity));
        setSubLabel(menu, ITEM_VIBRATION, vibrationSubLabel(guard));
        return !wasVisualOnly && guard.isVisualOnlyAlert();
    }

    function setSubLabel(menu as WatchUi.Menu2, id as Symbol, text as String) as Void {
        var index = menu.findItemById(id);
        if (index >= 0) {
            var item = menu.getItem(index);
            if (item != null) {
                item.setSubLabel(text);
            }
        }
    }

    //! Abre el aviso de alerta solo visual.
    function openWarning() as Void {
        WatchUi.pushView(new NoFeedbackView(), new NoFeedbackDelegate(), WatchUi.SLIDE_LEFT);
    }

    //! Submenú de opciones (sensibilidad o vibración) con el foco en la actual.
    function openChoices(guard as GuardController, parentMenu as WatchUi.Menu2,
            parentItem as WatchUi.MenuItem) as Void {
        var isSensitivity = parentItem.getId() == ITEM_SENSITIVITY;
        var names = (isSensitivity ? SENSITIVITY_NAMES : VIBRATION_NAMES) as Array<ResourceId>;
        var current = isSensitivity ? guard.settings().sensitivity as Number
            : guard.settings().vibration as Number;
        var menu = new WatchUi.Menu2({
            :title => DemoText.text(isSensitivity ? Rez.Strings.SettingSensitivity
                : Rez.Strings.SettingVibration),
            :focus => current
        });
        for (var i = 0; i < names.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(DemoText.text(names[i]), null, i, {}));
        }
        WatchUi.pushView(menu, new SettingsChoiceDelegate(guard, parentMenu, isSensitivity),
            WatchUi.SLIDE_LEFT);
    }
}

//! Entrada de la pantalla Ajustes.
class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _guard as GuardController;
    private var _menu as WatchUi.Menu2;

    function initialize(guard as GuardController, menu as WatchUi.Menu2) {
        Menu2InputDelegate.initialize();
        _guard = guard;
        _menu = menu;
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id == SettingsMenu.ITEM_SENSITIVITY || id == SettingsMenu.ITEM_VIBRATION) {
            SettingsMenu.openChoices(_guard, _menu, item);
            return;
        }
        // Los interruptores ya cambiaron de estado al tocarlos.
        var enabled = (item as WatchUi.ToggleMenuItem).isEnabled();
        var settings = _guard.settings().copy();
        if (id == SettingsMenu.ITEM_SOUND) {
            settings.sound = enabled;
        } else if (id == SettingsMenu.ITEM_REDUCED) {
            settings.reducedAnimations = enabled;
        } else if (id == SettingsMenu.ITEM_AI) {
            settings.aiConfirmation = enabled;
        } else if (id == SettingsMenu.ITEM_RECORD) {
            settings.recordActivity = enabled;
        } else {
            return;
        }
        if (SettingsMenu.commit(_guard, _menu, settings)) {
            SettingsMenu.openWarning();
        }
    }
}

//! Elige una opción de sensibilidad o de vibración, la guarda, actualiza los subtítulos
//! de Ajustes y vuelve (abriendo el aviso si la alerta pasó a ser solo visual).
class SettingsChoiceDelegate extends WatchUi.Menu2InputDelegate {

    private var _guard as GuardController;
    private var _parentMenu as WatchUi.Menu2;
    private var _isSensitivity as Boolean;

    function initialize(guard as GuardController, parentMenu as WatchUi.Menu2,
            isSensitivity as Boolean) {
        Menu2InputDelegate.initialize();
        _guard = guard;
        _parentMenu = parentMenu;
        _isSensitivity = isSensitivity;
    }

    function onSelect(item as MenuItem) as Void {
        var value = item.getId() as Number;
        var settings = _guard.settings().copy();
        if (_isSensitivity) {
            settings.sensitivity = Settings.sensitivityFrom(value);
        } else {
            settings.vibration = Settings.vibrationFrom(value);
        }
        var warn = SettingsMenu.commit(_guard, _parentMenu, settings);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        if (warn) {
            SettingsMenu.openWarning();
        }
    }
}
