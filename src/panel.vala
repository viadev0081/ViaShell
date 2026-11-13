using Gtk;
using GtkLayerShell;

namespace ViaShell {

    public class Panel : Gtk.Window {

        private Gtk.Box bar;
        private Gtk.MenuButton logo_button;
        private WorkspacesWidget workspaces;
        private SystemWidget system_widget;
        private ClockWidget clock_widget;

        public Panel (
            Gtk.Application app,
            Gdk.Monitor monitor,
            Distro distro,
            MediaService media,
            NotificationService notifications
        ) {
            Object (application: app);

            this.add_css_class ("panel-window");
            this.set_decorated (false);

            // Инициализация Layer Shell
            GtkLayerShell.init_for_window (this);
            GtkLayerShell.set_monitor (this, monitor);
            GtkLayerShell.set_layer (this, GtkLayerShell.Layer.TOP);
            GtkLayerShell.set_namespace (this, "viashell");
            // ON_DEMAND позволяет поповерам получать ввод, не забирая фокус постоянно
            GtkLayerShell.set_keyboard_mode (this, GtkLayerShell.KeyboardMode.ON_DEMAND);

            // Привязка к левому краю
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);

            // Отступы для "плавающего" эффекта
            GtkLayerShell.set_margin (this, GtkLayerShell.Edge.LEFT, 5);
            GtkLayerShell.set_margin (this, GtkLayerShell.Edge.TOP, 5);
            GtkLayerShell.set_margin (this, GtkLayerShell.Edge.BOTTOM, 5);

            // Эксклюзивная зона только у панели
            GtkLayerShell.auto_exclusive_zone_enable (this);

            setup_ui (distro, media, notifications, monitor);

            GLib.Timeout.add (2000, () => {
                logo_button.popup ();
                return GLib.Source.REMOVE;
            });
        }

        private void setup_ui (
            Distro distro,
            MediaService media,
            NotificationService notifications,
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

            // === Верхняя группа: логотип дистрибутива + рабочие столы ===
            var top_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
            top_box.add_css_class ("modules-top");
            top_box.set_valign (Gtk.Align.START);
            top_box.set_vexpand (false);

            logo_button = build_logo_button (distro, media, notifications);
            top_box.append (logo_button);

            var divider = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
            divider.add_css_class ("bar-divider");
            top_box.append (divider);

            workspaces = new WorkspacesWidget (monitor.get_connector ());
            top_box.append (workspaces);

            // === Центральная группа: сводка системы ===
            var center_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            center_box.add_css_class ("modules-center");
            center_box.set_valign (Gtk.Align.CENTER);
            center_box.set_vexpand (true);

            system_widget = new SystemWidget ();
            system_widget.set_vexpand (true);
            center_box.append (system_widget);

            // === Нижняя группа: часы + календарь ===
            var bottom_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            bottom_box.add_css_class ("modules-bottom");
            bottom_box.set_valign (Gtk.Align.END);
            bottom_box.set_vexpand (false);

            clock_widget = new ClockWidget ();
            bottom_box.append (clock_widget);

            bar.append (top_box);
            bar.append (center_box);
            bar.append (bottom_box);

            this.set_child (bar);

            GLib.Timeout.add (1600, () => {
                int tm, tn, cm, cn, bm, bn, wm, wn;
                top_box.measure (Gtk.Orientation.VERTICAL, -1, out tm, out tn, null, null);
                center_box.measure (Gtk.Orientation.VERTICAL, -1, out cm, out cn, null, null);
                bottom_box.measure (Gtk.Orientation.VERTICAL, -1, out bm, out bn, null, null);
                workspaces.measure (Gtk.Orientation.VERTICAL, -1, out wm, out wn, null, null);
                stderr.printf ("DBG2 bar h=%d top %d min=%d nat=%d center %d min=%d nat=%d bottom %d min=%d nat=%d ws %d min=%d nat=%d\n",
                    bar.get_height (),
                    top_box.get_height (), tm, tn,
                    center_box.get_height (), cm, cn,
                    bottom_box.get_height (), bm, bn,
                    workspaces.get_height (), wm, wn);
                return GLib.Source.REMOVE;
            });
        }

        private Gtk.MenuButton build_logo_button (
            Distro distro,
            MediaService media,
            NotificationService notifications
        ) {
            var button = new Gtk.MenuButton ();
            button.add_css_class ("logo-button");
            button.set_has_frame (false);
            button.set_direction (Gtk.ArrowType.RIGHT);
            button.set_tooltip_text (distro.name);

            var logo = new Gtk.Label ("");
            logo.add_css_class ("logo-glyph");
            logo.set_markup (
                "<span foreground='%s'>%s</span>".printf (
                    distro.colour, GLib.Markup.escape_text (Icons.get (distro.glyph))
                )
            );

            logo.set_halign (Gtk.Align.CENTER);
            logo.set_valign (Gtk.Align.CENTER);

            button.set_child (logo);

            var menu = new LauncherMenu (distro, media, notifications);
            button.set_popover (menu);

            return button;
        }
    }
}
