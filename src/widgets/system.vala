using Gtk;

namespace ViaShell {

    private class MeterRow : Gtk.Box {
        public Gtk.ProgressBar bar;
        public Gtk.Label value_label;
        private Gtk.Label name_label;

        public MeterRow (string name) {
            Object (
                orientation: Gtk.Orientation.VERTICAL,
                spacing: 4
            );
            this.add_css_class ("meter-row");

            var top = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            name_label = new Gtk.Label (name);
            name_label.add_css_class ("meter-name");
            name_label.set_halign (Gtk.Align.START);
            name_label.set_hexpand (true);

            value_label = new Gtk.Label ("--");
            value_label.add_css_class ("meter-value");
            value_label.set_halign (Gtk.Align.END);

            top.append (name_label);
            top.append (value_label);
            this.append (top);

            bar = new Gtk.ProgressBar ();
            bar.add_css_class ("vs-bar");
            bar.set_show_text (false);
            bar.set_hexpand (true);
            this.append (bar);
        }

        public void set_custom (double percent, string text) {
            double p = percent < 0 ? 0 : (percent > 100 ? 100 : percent);
            bar.set_fraction (p / 100.0);
            value_label.set_text (text);
        }

        public void set_percent (double percent) {
            set_custom (percent, "%.0f%%".printf (percent));
        }
    }

    private class HeroCard : Gtk.Box {
        public Gtk.Label value_label;
        public Gtk.Label sub_label;
        public Gtk.Label icon_label;
        public Gtk.ProgressBar bar;

        public HeroCard (
            string title,
            uint32 icon = 0,
            bool with_bar = true
        ) {
            Object (
                orientation: Gtk.Orientation.VERTICAL,
                spacing: 8
            );
            this.add_css_class ("hero-card");

            var top = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);

            icon_label = new Gtk.Label (icon != 0 ? Icons.get (icon) : "");
            icon_label.add_css_class ("hero-icon");
            icon_label.set_valign (Gtk.Align.CENTER);
            if (icon != 0) {
                top.append (icon_label);
            }

            var texts = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            texts.set_hexpand (true);

            var title_label = new Gtk.Label (title);
            title_label.add_css_class ("hero-label");
            title_label.set_halign (Gtk.Align.START);

            sub_label = new Gtk.Label ("");
            sub_label.add_css_class ("hero-sub");
            sub_label.set_halign (Gtk.Align.START);
            sub_label.set_ellipsize (Pango.EllipsizeMode.END);

            texts.append (title_label);
            texts.append (sub_label);

            value_label = new Gtk.Label ("--");
            value_label.add_css_class ("hero-value");
            value_label.set_valign (Gtk.Align.CENTER);

            top.append (texts);
            top.append (value_label);
            this.append (top);

            bar = new Gtk.ProgressBar ();
            bar.add_css_class ("vs-bar");
            bar.set_show_text (false);
            bar.set_hexpand (true);
            if (with_bar) {
                this.append (bar);
            }
        }
    }

    public class SystemPopup : Gtk.Popover {

        private Gtk.Stack stack;

        private HeroCard cpu_hero;
        private Gtk.Box core_box;
        private MeterRow[] core_rows = {};

        private HeroCard mem_hero;
        private MeterRow mem_used_row;
        private MeterRow mem_free_row;
        private Gtk.Label mem_detail;

        private HeroCard volume_hero;
        private Gtk.Scale volume_scale;
        private Gtk.ToggleButton mute_button;
        private Gtk.Label mute_label;
        private Gtk.Label mute_icon;

        private HeroCard brightness_hero;
        private Gtk.Scale brightness_scale;
        private Gtk.Label brightness_hint;

        private HeroCard battery_hero;
        private Gtk.Label power_hint;
        private Gtk.Button mode_saver;
        private Gtk.Button mode_balanced;
        private Gtk.Button mode_performance;

        private bool updating = false;
        private uint timer_id = 0;
        private int tick = 0;

        private uint volume_timeout = 0;
        private int pending_volume = 0;
        private uint brightness_timeout = 0;
        private int pending_brightness = 0;

        public SystemPopup () {
            this.add_css_class ("vs-popover");
            this.add_css_class ("system-popover");
            this.set_has_arrow (false);
            this.set_position (Gtk.PositionType.RIGHT);

            var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
            root.add_css_class ("system-content");
            root.set_size_request (430, 476);

            var title = new Gtk.Label ("Системный монитор");
            title.add_css_class ("popup-title");
            title.set_halign (Gtk.Align.START);
            root.append (title);

            stack = new Gtk.Stack ();
            stack.set_transition_type (Gtk.StackTransitionType.CROSSFADE);
            stack.set_transition_duration (160);
            stack.set_vexpand (true);

            stack.add_titled (
                build_cpu_page (), "cpu",
                "%s  ЦП".printf (Icons.get (Icons.CPU))
            );

            stack.add_titled (
                build_memory_page (), "memory",
                "%s  ОЗУ".printf (Icons.get (Icons.MEMORY))
            );

            stack.add_titled (
                build_sound_page (), "sound",
                "%s  Звук".printf (Icons.get (Icons.VOLUME_HIGH))
            );

            stack.add_titled (
                build_brightness_page (), "brightness",
                "%s  Свет".printf (Icons.get (Icons.BRIGHTNESS))
            );

            stack.add_titled (
                build_battery_page (), "battery",
                "%s  Батарея".printf (Icons.get (Icons.BATTERY))
            );

            var switcher = new Gtk.StackSwitcher ();
            switcher.set_stack (stack);
            switcher.add_css_class ("vs-tabs");
            switcher.set_halign (Gtk.Align.CENTER);

            root.append (switcher);
            root.append (stack);
            this.set_child (root);

            this.show.connect (() => {
                update_all ();
                start_timer ();
            });

            this.hide.connect (() => {
                stop_timer ();
            });
        }

        /* ------------------------------------------------------------------ */
        /*  Страницы                                                          */
        /* ------------------------------------------------------------------ */
        private Gtk.Widget build_cpu_page () {
            var page = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
            page.add_css_class ("tab-page");

            cpu_hero = new HeroCard ("Общая нагрузка", Icons.CPU);
            cpu_hero.sub_label.set_text ("Средняя загрузка всех ядер");
            page.append (cpu_hero);

            var section = new Gtk.Label ("Ядра процессора");
            section.add_css_class ("section-title");
            section.set_halign (Gtk.Align.START);
            page.append (section);

            core_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);

            var scroll = new Gtk.ScrolledWindow ();
            scroll.add_css_class ("core-scroll");
            scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            scroll.set_vexpand (true);
            scroll.set_child (core_box);
            page.append (scroll);

            return page;
        }

        private Gtk.Widget build_memory_page () {
            var page = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
            page.add_css_class ("tab-page");

            mem_hero = new HeroCard ("Оперативная память", Icons.MEMORY);
            page.append (mem_hero);

            mem_used_row = new MeterRow ("Используется");
            mem_free_row = new MeterRow ("Свободно");
            page.append (mem_used_row);
            page.append (mem_free_row);

            mem_detail = new Gtk.Label ("");
            mem_detail.add_css_class ("detail-label");
            mem_detail.set_halign (Gtk.Align.START);
            page.append (mem_detail);

            var filler = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            filler.set_vexpand (true);
            page.append (filler);

            return page;
        }

        private Gtk.Widget build_sound_page () {
            var page = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            page.add_css_class ("tab-page");

            volume_hero = new HeroCard ("Громкость", Icons.VOLUME_HIGH, false);
            volume_hero.sub_label.set_text ("Основное аудиоустройство");
            page.append (volume_hero);

            var card = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            card.add_css_class ("control-card");

            volume_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 1);
            volume_scale.add_css_class ("vs-slider");
            volume_scale.set_draw_value (false);
            volume_scale.set_hexpand (true);
            volume_scale.set_increments (5, 10);
            volume_scale.set_digits (0);
            volume_scale.value_changed.connect (() => {
                on_volume_changed ();
            });

            card.append (volume_scale);

            mute_button = new Gtk.ToggleButton ();
            mute_button.add_css_class ("mute-button");
            var mute_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            mute_box.set_halign (Gtk.Align.CENTER);
            mute_icon = new Gtk.Label (Icons.get (Icons.VOLUME_HIGH));
            mute_icon.add_css_class ("button-icon");
            mute_label = new Gtk.Label ("Выключить звук");
            mute_box.append (mute_icon);
            mute_box.append (mute_label);
            mute_button.set_child (mute_box);
            mute_button.toggled.connect (() => {
                on_mute_toggled ();
            });

            card.append (mute_button);

            page.append (card);

            var filler = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            filler.set_vexpand (true);
            page.append (filler);

            return page;
        }

        private Gtk.Widget build_brightness_page () {
            var page = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            page.add_css_class ("tab-page");

            brightness_hero = new HeroCard ("Яркость экрана", Icons.BRIGHTNESS, false);
            page.append (brightness_hero);

            var card = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
            card.add_css_class ("control-card");

            brightness_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 1);
            brightness_scale.add_css_class ("vs-slider");
            brightness_scale.set_draw_value (false);
            brightness_scale.set_hexpand (true);
            brightness_scale.set_increments (5, 10);
            brightness_scale.set_digits (0);
            brightness_scale.value_changed.connect (() => {
                on_brightness_changed ();
            });

            card.append (brightness_scale);

            brightness_hint = new Gtk.Label ("");
            brightness_hint.add_css_class ("detail-label");
            brightness_hint.set_halign (Gtk.Align.START);
            card.append (brightness_hint);

            page.append (card);

            var filler = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            filler.set_vexpand (true);
            page.append (filler);

            return page;
        }

        private Gtk.Widget build_battery_page () {
            var page = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            page.add_css_class ("tab-page");

            battery_hero = new HeroCard ("Батарея", Icons.BATTERY);
            page.append (battery_hero);

            var section = new Gtk.Label ("Режим питания");
            section.add_css_class ("section-title");
            section.set_halign (Gtk.Align.START);
            page.append (section);

            var modes = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            modes.add_css_class ("power-modes");
            modes.set_homogeneous (true);

            mode_saver = build_mode_button ("Экономия", Icons.LEAF, "power-saver");
            mode_balanced = build_mode_button ("Баланс", Icons.BALANCE, "balanced");
            mode_performance = build_mode_button ("Максимум", Icons.ROCKET, "performance");

            modes.append (mode_saver);
            modes.append (mode_balanced);
            modes.append (mode_performance);
            page.append (modes);

            power_hint = new Gtk.Label ("");
            power_hint.add_css_class ("detail-label");
            power_hint.set_halign (Gtk.Align.START);
            page.append (power_hint);

            var filler = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            filler.set_vexpand (true);
            page.append (filler);

            return page;
        }

        private Gtk.Button build_mode_button (
            string label,
            uint32 icon,
            string profile
        ) {
            var button = new Gtk.Button ();
            button.add_css_class ("power-mode");
            button.set_tooltip_text (label);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            box.set_halign (Gtk.Align.CENTER);

            var icon_label = new Gtk.Label (Icons.get (icon));
            icon_label.add_css_class ("mode-icon");
            var text_label = new Gtk.Label (label);
            text_label.add_css_class ("mode-label");

            box.append (icon_label);
            box.append (text_label);
            button.set_child (box);

            button.clicked.connect (() => {
                if (!SystemInfo.has_power_profiles ()) {
                    return;
                }

                SystemInfo.set_power_profile (profile);
                set_mode_ui (profile);

                GLib.Timeout.add (350, () => {
                    update_power_profile ();
                    return GLib.Source.REMOVE;
                });
            });

            return button;
        }

        /* ------------------------------------------------------------------ */
        /*  Обновление                                                        */
        /* ------------------------------------------------------------------ */
        private void start_timer () {
            if (timer_id != 0) {
                return;
            }

            timer_id = GLib.Timeout.add (1000, () => {
                tick++;
                update_cpu ();
                update_memory ();
                if (tick % 3 == 0) {
                    update_sound ();
                    update_brightness ();
                }
                if (tick % 5 == 0) {
                    update_battery ();
                    update_power_profile ();
                }
                return GLib.Source.CONTINUE;
            });
        }

        private void stop_timer () {
            if (timer_id != 0) {
                GLib.Source.remove (timer_id);
                timer_id = 0;
            }
            if (volume_timeout != 0) {
                GLib.Source.remove (volume_timeout);
                volume_timeout = 0;
            }
            if (brightness_timeout != 0) {
                GLib.Source.remove (brightness_timeout);
                brightness_timeout = 0;
            }
        }

        private void update_all () {
            update_cpu ();
            update_memory ();
            update_sound ();
            update_brightness ();
            update_battery ();
            update_power_profile ();
        }

        private void update_cpu () {
            double usage = SystemInfo.get_cpu_usage ();
            cpu_hero.value_label.set_text ("%.0f%%".printf (usage));
            cpu_hero.bar.set_fraction (usage / 100.0);
            cpu_hero.sub_label.set_text (
                "%d ядер · средняя загрузка".printf (SystemInfo.get_cpu_core_count ())
            );

            ensure_core_rows ();

            var cores = SystemInfo.get_cpu_core_usages ();
            for (int i = 0; i < core_rows.length && i < cores.length; i++) {
                core_rows[i].set_percent (cores[i]);
            }
        }

        private void ensure_core_rows () {
            int count = SystemInfo.get_cpu_core_count ();
            if (count == core_rows.length && core_rows.length > 0) return;

            clear_box (core_box);
            core_rows = {};

            for (int i = 0; i < count; i++) {
                var row = new MeterRow ("Ядро %d".printf (i + 1));
                core_box.append (row);
                core_rows += row;
            }
        }

        private void update_memory () {
            double total, used, free, available;
            SystemInfo.get_memory_info (out total, out used, out free, out available);

            double used_pct = total > 0 ? (used / total) * 100.0 : 0.0;
            double free_pct = total > 0 ? (free / total) * 100.0 : 0.0;

            mem_hero.value_label.set_text ("%.0f%%".printf (used_pct));
            mem_hero.sub_label.set_text (
                "%s используется из %s".printf (format_size (used), format_size (total))
            );
            mem_hero.bar.set_fraction (used_pct / 100.0);

            mem_used_row.set_custom (used_pct, format_size (used));
            mem_free_row.set_custom (free_pct, format_size (free));
            mem_detail.set_text (
                "Доступно: %s   ·   Всего: %s".printf (
                    format_size (available), format_size (total)
                )
            );
        }

        private void update_sound () {
            int volume;
            bool muted;
            SystemInfo.get_volume_state (out volume, out muted);

            updating = true;
            volume_scale.set_value (volume);
            updating = false;

            volume_hero.value_label.set_text (muted ? "Выкл" : "%d%%".printf (volume));
            volume_hero.sub_label.set_text (muted ? "Звук выключен" : "Основное аудиоустройство");
            volume_hero.icon_label.set_text (Icons.get (volume_icon (volume, muted)));

            updating = true;
            mute_button.set_active (muted);
            updating = false;
            update_mute_ui (muted);
        }

        private void update_mute_ui (bool muted) {
            mute_label.set_text (muted ? "Включить звук" : "Выключить звук");
            mute_icon.set_text (Icons.get (muted ? Icons.VOLUME_MUTE : Icons.VOLUME_HIGH));

            if (muted) {
                mute_button.add_css_class ("muted");
            }
            else {
                mute_button.remove_css_class ("muted");
            }
        }

        private void on_volume_changed () {
            if (updating) {
                return;
            }

            int value = (int) Math.round (volume_scale.get_value ());
            volume_hero.value_label.set_text ("%d%%".printf (value));
            volume_hero.icon_label.set_text (Icons.get (volume_icon (value, false)));

            if (mute_button.get_active ()) {
                updating = true;
                mute_button.set_active (false);
                updating = false;
                update_mute_ui (false);
                SystemInfo.set_muted (false);
            }

            pending_volume = value;
            if (volume_timeout != 0) {
                GLib.Source.remove (volume_timeout);
            }

            volume_timeout = GLib.Timeout.add (90, () => {
                volume_timeout = 0;
                SystemInfo.set_volume (pending_volume);
                return GLib.Source.REMOVE;
            });
        }

        private void on_mute_toggled () {
            if (updating) {
                return;
            }

            bool muted = mute_button.get_active ();
            SystemInfo.set_muted (muted);
            update_mute_ui (muted);

            volume_hero.value_label.set_text (
                muted ? "Выкл" : "%d%%".printf ((int) Math.round (volume_scale.get_value ()))
            );

            volume_hero.icon_label.set_text (
                Icons.get (volume_icon ((int) Math.round (volume_scale.get_value ()), muted))
            );
        }

        private void update_brightness () {
            int brightness = SystemInfo.get_brightness ();

            updating = true;
            brightness_scale.set_value (brightness);
            updating = false;

            brightness_hero.value_label.set_text ("%d%%".printf (brightness));
            brightness_hero.icon_label.set_text (Icons.get (
                brightness > 55 ? Icons.BRIGHTNESS : Icons.BRIGHTNESS_LOW
            ));

            bool available = SystemInfo.has_brightness_control ();
            brightness_scale.set_sensitive (available);

            if (available) {
                brightness_hint.set_text ("Перетащите ползунок, чтобы изменить подсветку");
                brightness_hero.sub_label.set_text ("Подсветка дисплея");
            }
            else {
                brightness_hint.set_text ("Установите brightnessctl для управления яркостью");
                brightness_hero.sub_label.set_text ("Устройство подсветки не найдено");
            }
        }

        private void on_brightness_changed () {
            if (updating) {
                return;
            }
            if (!SystemInfo.has_brightness_control ()) {
                return;
            }

            int value = (int) Math.round (brightness_scale.get_value ());
            brightness_hero.value_label.set_text ("%d%%".printf (value));
            brightness_hero.icon_label.set_text (Icons.get (
                value > 55 ? Icons.BRIGHTNESS : Icons.BRIGHTNESS_LOW
            ));

            pending_brightness = value;
            if (brightness_timeout != 0) GLib.Source.remove (brightness_timeout);
            brightness_timeout = GLib.Timeout.add (90, () => {
                brightness_timeout = 0;
                SystemInfo.set_brightness (pending_brightness);
                return GLib.Source.REMOVE;
            });
        }

        private void update_battery () {
            int level = SystemInfo.get_battery_level ();
            string status = SystemInfo.get_battery_status ();
            bool charging = SystemInfo.is_battery_charging ();

            if (level < 0) {
                battery_hero.value_label.set_text ("AC");
                battery_hero.sub_label.set_text ("Питание от сети");
                battery_hero.icon_label.set_text (Icons.get (Icons.POWER_PLUG));
                battery_hero.bar.set_fraction (1.0);
            }
            else {
                battery_hero.value_label.set_text ("%d%%".printf (level));
                battery_hero.sub_label.set_text (battery_status_text (status, charging));
                battery_hero.icon_label.set_text (
                    Icons.get (Icons.battery_for (level, charging))
                );
                battery_hero.bar.set_fraction (level / 100.0);
            }
        }

        private void update_power_profile () {
            bool available = SystemInfo.has_power_profiles ();
            mode_saver.set_sensitive (available);
            mode_balanced.set_sensitive (available);
            mode_performance.set_sensitive (available);

            if (!available) {
                set_mode_ui ("");
                power_hint.set_text (
                    "power-profiles-daemon не найден — режимы недоступны"
                );
                return;
            }

            string profile = SystemInfo.get_power_profile ();
            set_mode_ui (profile);
            power_hint.set_text (
                "Текущий режим: %s".printf (power_profile_text (profile))
            );
        }

        private void set_mode_ui (string profile) {
            set_mode_button_active (mode_saver, profile == "power-saver");
            set_mode_button_active (mode_balanced, profile == "balanced");
            set_mode_button_active (mode_performance, profile == "performance");
        }

        private static void set_mode_button_active (Gtk.Button button, bool active) {
            if (active) {
                button.add_css_class ("active");
            }
            else {
                button.remove_css_class ("active");
            }
        }

        /* ------------------------------------------------------------------ */
        /*  Утилиты                                                           */
        /* ------------------------------------------------------------------ */
        private static uint32 volume_icon (int volume, bool muted) {
            if (muted || volume <= 0) {
                return Icons.VOLUME_MUTE;
            }
            if (volume > 66) {
                return Icons.VOLUME_HIGH;
            }
            if (volume > 33) {
                return Icons.VOLUME_MEDIUM;
            }

            return Icons.VOLUME_LOW;
        }

        private static string format_size (double mib) {
            if (mib >= 1024.0) {
                return "%.1f ГиБ".printf (mib / 1024.0);
            }
            return "%.0f МиБ".printf (mib);
        }

        private static string battery_status_text (string status, bool charging) {
            switch (status) {
                case "Charging": return "Заряжается";
                case "Discharging": return "Разряжается";
                case "Full": return "Полностью заряжена";
                case "Not charging": return "Не заряжается";
                default: return charging ? "Заряжается" : "Работает от батареи";
            }
        }

        private static string power_profile_text (string profile) {
            switch (profile) {
                case "power-saver": return "энергосбережение";
                case "balanced": return "сбалансированный";
                case "performance": return "максимальная производительность";
                default: return "неизвестно";
            }
        }

        private static void clear_box (Gtk.Box box) {
            Gtk.Widget? child = box.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                box.remove (child);
                child = next;
            }
        }

        public override void dispose () {
            stop_timer ();
            base.dispose ();
        }
    }

    public class SystemWidget : Gtk.Box {

        private PanelButton button;
        private Gtk.Label cpu_value;
        private Gtk.Label mem_value;
        private Gtk.Label vol_value;
        private Gtk.Label bright_value;
        private Gtk.Label batt_value;

        private Gtk.Label cpu_icon;
        private Gtk.Label mem_icon;
        private Gtk.Label vol_icon;
        private Gtk.Label bright_icon;
        private Gtk.Label batt_icon;

        private SystemPopup system_popup;

        public SystemWidget () {
            Object (
                orientation: Gtk.Orientation.VERTICAL,
                spacing: 0
            );

            this.set_valign (Gtk.Align.FILL);
            this.set_vexpand (false);

            button = new PanelButton ("system-button", "Мониторинг системы");
            button.set_vexpand (false);
            button.set_halign (Gtk.Align.FILL);

            var grid = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            grid.add_css_class ("summary-grid");
            grid.set_homogeneous (false);
            grid.set_valign (Gtk.Align.CENTER);
            grid.set_vexpand (false);

            cpu_icon = add_summary_row (grid, Icons.CPU, "cpu");
            cpu_value = get_last_value ();

            mem_icon = add_summary_row (grid, Icons.MEMORY, "memory");
            mem_value = get_last_value ();

            vol_icon = add_summary_row (grid, Icons.VOLUME_HIGH, "volume");
            vol_value = get_last_value ();

            bright_icon = add_summary_row (grid, Icons.BRIGHTNESS, "brightness");
            bright_value = get_last_value ();

            batt_icon = add_summary_row (grid, Icons.BATTERY, "battery");
            batt_value = get_last_value ();

            button.set_child (grid);
            this.append (button);

            system_popup = new SystemPopup ();
            button.set_panel_popover (system_popup);

            update_summary ();
            GLib.Timeout.add_seconds (2, () => {
                update_summary ();
                return GLib.Source.CONTINUE;
            });
        }

        private Gtk.Label last_value;

        public void open_menu () {
            button.set_active (true);
        }

        private Gtk.Label get_last_value () {
            return last_value;
        }

        private Gtk.Label add_summary_row (
            Gtk.Box parent,
            uint32 icon,
            string css_class
        ) {
            var row = new Gtk.Box (Gtk.Orientation.VERTICAL, 1);
            row.add_css_class ("summary-row");
            row.add_css_class (css_class);
            row.set_valign (Gtk.Align.CENTER);

            var icon_label = new Gtk.Label (Icons.get (icon));
            icon_label.add_css_class ("summary-icon");
            icon_label.set_halign (Gtk.Align.CENTER);

            var value_label = new Gtk.Label ("--");
            value_label.add_css_class ("summary-value");
            value_label.set_halign (Gtk.Align.CENTER);

            row.append (icon_label);
            row.append (value_label);
            parent.append (row);

            last_value = value_label;
            return icon_label;
        }

        private void update_summary () {
            double cpu = SystemInfo.get_cpu_usage ();
            cpu_value.set_text ("%.0f%%".printf (cpu));

            // Прайминг дельт, чтобы вкладка ЦП сразу показывала актуальную нагрузку
            SystemInfo.get_cpu_core_usages ();

            cpu_value.remove_css_class ("warn");
            cpu_value.remove_css_class ("critical");

            if (cpu > 85) {
                cpu_value.add_css_class ("critical");
            }
            else if (cpu > 60) {
                cpu_value.add_css_class ("warn");
            }

            double memory = SystemInfo.get_memory_usage ();
            mem_value.set_text ("%.0f%%".printf (memory));
            mem_value.remove_css_class ("warn");
            mem_value.remove_css_class ("critical");

            if (memory > 85) {
                mem_value.add_css_class ("critical");
            }
            else if (memory > 60) {
                mem_value.add_css_class ("warn");
            }

            int volume;
            bool muted;
            SystemInfo.get_volume_state (out volume, out muted);

            vol_icon.set_text (Icons.get (
                muted || volume <= 0 ? Icons.VOLUME_MUTE :
                volume > 66 ? Icons.VOLUME_HIGH :
                volume > 33 ? Icons.VOLUME_MEDIUM : Icons.VOLUME_LOW
            ));

            vol_value.set_text (muted ? "M" : "%d%%".printf (volume));

            int brightness = SystemInfo.get_brightness ();
            bright_icon.set_text (Icons.get (
                brightness > 55 ? Icons.BRIGHTNESS : Icons.BRIGHTNESS_LOW
            ));

            bright_value.set_text ("%d%%".printf (brightness));

            int level = SystemInfo.get_battery_level ();
            bool charging = SystemInfo.is_battery_charging ();

            if (level < 0) {
                batt_icon.set_text (Icons.get (Icons.POWER_PLUG));
                batt_value.set_text ("AC");
                batt_value.remove_css_class ("critical");
            }
            else {
                batt_icon.set_text (Icons.get (Icons.battery_for (level, charging)));
                batt_value.set_text ("%d%%".printf (level));
                if (level <= 15 && !charging) {
                    batt_value.add_css_class ("critical");
                }
                else {
                    batt_value.remove_css_class ("critical");
                }
            }
        }
    }
}
