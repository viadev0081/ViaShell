using Gtk;

namespace ViaShell {

    public class BrightnessWidget : Gtk.Box {

        private Gtk.Label icon_label;
        private Gtk.Label value_label;

        public BrightnessWidget () {
            Object (
                orientation: Gtk.Orientation.VERTICAL,
                spacing: 4
            );

            this.add_css_class ("widget");
            this.add_css_class ("brightness");

            // Иконка
            icon_label = new Gtk.Label ("󰃟");  // brightness icon
            icon_label.add_css_class ("widget-icon");
            this.append (icon_label);

            // Значение
            value_label = new Gtk.Label ("0%");
            value_label.add_css_class ("widget-value");
            this.append (value_label);

            // Scroll для изменения яркости
            var scroll_controller = new Gtk.EventControllerScroll (
                Gtk.EventControllerScrollFlags.VERTICAL
            );
            scroll_controller.scroll.connect (on_scroll);
            this.add_controller (scroll_controller);

            // Обновление
            update_value ();
            GLib.Timeout.add_seconds (5, () => {
                update_value ();
                return GLib.Source.CONTINUE;
            });
        }

        private bool on_scroll (double dx, double dy) {
            try {
                if (dy < 0) {
                    GLib.Process.spawn_command_line_async ("brightnessctl set 5%+");
                } 
                else if (dy > 0) {
                    GLib.Process.spawn_command_line_async ("brightnessctl set 5%-");
                }
                GLib.Timeout.add (200, () => {
                    update_value ();
                    return GLib.Source.REMOVE;
                });
            } catch (GLib.Error e) {
                warning ("Failed to change brightness: %s", e.message);
            }
            return true;
        }

        private void update_value () {
            int brightness = SystemInfo.get_brightness ();

            value_label.set_text ("%d%%".printf (brightness));

            if (brightness > 75) {
                icon_label.set_text ("󰃠");  // bright
            } 
            else if (brightness > 40) {
                icon_label.set_text ("󰃟");  // medium
            } 
            else {
                icon_label.set_text ("󰃞");  // dim
            }
        }
    }
}
