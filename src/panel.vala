using Gtk;
using GtkLayerShell;

namespace ViaShell {

    public class Panel : Gtk.Window {

        private Gtk.Box bar;
        private PanelButton logo_button;
        private WorkspacesWidget workspaces;
        private SystemWidget system_widget;
        private ClockWidget clock_widget;
        private Gtk.Label mode_label;

        private IniConfig config;

        public Panel (
            Gtk.Application app,
            Gdk.Monitor monitor,
            Distro distro,
            MediaService media,
            NotificationService notifications,
            ThemeManager themes
        ) {
            Object (application: app);

            this.add_css_class ("panel-window");
            this.set_decorated (false);

            // Конфиг: какие элементы показывать на панели
            string config_path = GLib.Path.build_filename (
                GLib.Environment.get_user_config_dir (), "viashell", "config.ini"
            );
            config = new IniConfig ();
            config.load (config_path);

            // Инициализация Layer Shell
            GtkLayerShell.init_for_window (this);
            GtkLayerShell.set_monitor (this, monitor);
            GtkLayerShell.set_layer (this, GtkLayerShell.Layer.TOP);
            GtkLayerShell.set_namespace (this, "viashell");
            // ON_DEMAND позволяет поповерам получать ввод, не забирая фокус постоянно
            GtkLayerShell.set_keyboard_mode (this, GtkLayerShell.KeyboardMode.ON_DEMAND);

            // Привязка к краям
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);

            // Без отступов — панель вплотную к краю экрана
            GtkLayerShell.set_margin (this, GtkLayerShell.Edge.LEFT, 0);
            GtkLayerShell.set_margin (this, GtkLayerShell.Edge.TOP, 0);
            GtkLayerShell.set_margin (this, GtkLayerShell.Edge.BOTTOM, 0);

            // Эксклюзивная зона только у панели
            GtkLayerShell.auto_exclusive_zone_enable (this);

            setup_ui (distro, media, notifications, themes, monitor);

            // Режимы sway/swayfx (default / resizing …) опрашиваются таймаутом
            if (Sway.is_available ()) {
                Sway.start_mode_watcher ();
                update_mode_label (Sway.get_current_mode ());
                GLib.Timeout.add (500, () => {
                    update_mode_label (Sway.get_current_mode ());
                    return GLib.Source.CONTINUE;
                });
            }

            string? debug = GLib.Environment.get_variable ("VIASHELL_DEBUG");
            if (debug == "menu") {
                GLib.Timeout.add (1200, () => {
                    logo_button.set_active (true);

                    return GLib.Source.REMOVE;
                });
            }
            else if (debug == "calendar") {
                GLib.Timeout.add (1200, () => {
                    clock_widget.open_menu ();

                    return GLib.Source.REMOVE;
                });
            }
            else if (debug == "system") {
                GLib.Timeout.add (1200, () => {
                    system_widget.open_menu ();

                    return GLib.Source.REMOVE;
                });
            }
            else if (debug == "theme") {
                GLib.Timeout.add (1200, () => {
                    logo_button.set_active (true);
                    GLib.Timeout.add (1000, () => {
                        themes.set_theme (1);
                        return GLib.Source.REMOVE;
                    });

                    return GLib.Source.REMOVE;
                });
            }
        }

        private void setup_ui (
            Distro distro,
            MediaService media,
            NotificationService notifications,
            ThemeManager themes,
            Gdk.Monitor monitor
        ) {
            // Фиксированная ширина вертикальной панели
            this.set_default_size (64, -1);

            bar = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            bar.add_css_class ("bar");
            bar.set_valign (Gtk.Align.FILL);
            bar.set_vexpand (true);
            bar.set_halign (Gtk.Align.FILL);
            bar.set_size_request (64, -1);

            // === Верхняя группа: логотип, режим sway, рабочие столы ===
            var top_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            top_box.add_css_class ("modules-top");
            top_box.set_valign (Gtk.Align.START);
            top_box.set_vexpand (false);
            top_box.set_halign (Gtk.Align.FILL);

            bool have_top = false;

            if (config.get_bool ("panel", "logo", true)) {
                logo_button = build_logo_button (distro, media, notifications, themes);
                top_box.append (logo_button);
                have_top = true;
            }

            // Чип текущего режима sway/swayfx (default, resizing …)
            if (Sway.is_available () && config.get_bool ("panel", "mode", true)) {
                mode_label = new Gtk.Label ("default");
                mode_label.add_css_class ("mode-chip");
                mode_label.set_halign (Gtk.Align.CENTER);
                top_box.append (mode_label);
                have_top = true;
            }

            if (have_top && config.get_bool ("panel", "workspaces", true)) {
                var divider = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
                divider.add_css_class ("bar-divider");
                top_box.append (divider);
            }

            if (config.get_bool ("panel", "workspaces", true)) {
                workspaces = new WorkspacesWidget (monitor.get_connector ());
                top_box.append (workspaces);
                have_top = true;
            }

            // === Центральная группа: сводка системы ===
            var center_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            center_box.add_css_class ("modules-center");
            center_box.set_valign (Gtk.Align.CENTER);
            center_box.set_vexpand (true);

            if (config.get_bool ("panel", "system", true)) {
                system_widget = new SystemWidget ();
                system_widget.set_vexpand (false);
                center_box.append (system_widget);
            }

            // === Нижняя группа: часы ===
            var bottom_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            bottom_box.add_css_class ("modules-bottom");
            bottom_box.set_valign (Gtk.Align.END);
            bottom_box.set_vexpand (false);

            if (config.get_bool ("panel", "clock", true)) {
                clock_widget = new ClockWidget ();
                bottom_box.append (clock_widget);
            }

            bar.append (top_box);
            bar.append (center_box);
            bar.append (bottom_box);

            this.set_child (bar);
        }

        private void update_mode_label (string mode) {
            if (mode_label == null) {
                return;
            }
            string text = mode == "resizing" ? "resizing" : "default";
            mode_label.set_text (text);
        }

        private void on_sway_mode_changed (string mode) {
            update_mode_label (mode);
        }

        private PanelButton build_logo_button (
            Distro distro,
            MediaService media,
            NotificationService notifications,
            ThemeManager themes
        ) {
            var button = new PanelButton ("logo-button", distro.name);

            var logo = new Gtk.Label ("");
            logo.add_css_class ("logo-glyph");
            logo.set_markup (
                "<span foreground='%s'>%s</span>".printf (
                    themes.accent_color (), GLib.Markup.escape_text (Icons.get (distro.glyph))
                )
            );

            logo.set_halign (Gtk.Align.CENTER);
            logo.set_valign (Gtk.Align.CENTER);

            // Кнопка с логотипом — по центру панели, фиксированного размера
            button.set_child (logo);
            button.set_halign (Gtk.Align.CENTER);
            button.set_hexpand (false);
            button.set_size_request (44, 44);

            var menu = new LauncherMenu (distro, media, notifications, themes, config);
            button.set_panel_popover (menu);

            return button;
        }
    }
}
