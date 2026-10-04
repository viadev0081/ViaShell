using Gtk;

namespace ViaShell {

    public class VolumeWidget : Gtk.Box {

        private Gtk.Label icon_label;
        private Gtk.Label value_label;

        public VolumeWidget () {
            Object (
                orientation: Gtk.Orientation.VERTICAL,
                spacing: 4
            );

            this.add_css_class ("widget");
            this.add_css_class ("volume");

            // Иконка
            icon_label = new Gtk.Label ("󰕾");
            icon_label.add_css_class ("widget-icon");
            this.append (icon_label);

            // Значение
            value_label = new Gtk.Label ("0%");
            value_label.add_css_class ("widget-value");
            this.append (value_label);

            // Scroll для изменения громкости
            var scroll_controller = new Gtk.EventControllerScroll (
                Gtk.EventControllerScrollFlags.VERTICAL
            );
            scroll_controller.scroll.connect (on_scroll);
            this.add_controller (scroll_controller);

            // Клик для mute/unmute
            var click_controller = new Gtk.GestureClick ();
            click_controller.pressed.connect (() => {
                toggle_mute ();
            });
            this.add_controller (click_controller);

            // Обновление каждые 2 секунды
            update_value ();
            GLib.Timeout.add_seconds (2, () => {
                update_value ();
                return GLib.Source.CONTINUE;
            });
        }

        private bool on_scroll (double dx, double dy) {
            try {
                if (dy < 0) {
                    GLib.Process.spawn_command_line_async ("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+");
                } 
                else if (dy > 0) {
                    GLib.Process.spawn_command_line_async ("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-");
                }
                // Обновляем через небольшую задержку
                GLib.Timeout.add (100, () => {
                    update_value ();
                    return GLib.Source.REMOVE;
                });
            } catch (GLib.Error e) {
                warning ("Failed to change volume: %s", e.message);
            }
            return true;
        }

        private void toggle_mute () {
            try {
                GLib.Process.spawn_command_line_async ("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle");
                GLib.Timeout.add (100, () => {
                    update_value ();
                    return GLib.Source.REMOVE;
                });
            } catch (GLib.Error e) {
                warning ("Failed to toggle mute: %s", e.message);
            }
        }

        private void update_value () {
            int volume = SystemInfo.get_volume ();
            bool muted = SystemInfo.is_muted ();

            if (muted) {
                icon_label.set_text ("󰖁");  // Muted icon
                value_label.set_text ("M");
                this.add_css_class ("muted");
            } 
            else {
                this.remove_css_class ("muted");
                if (volume > 66) {
                    icon_label.set_text ("󰕾");
                } 
                else if (volume > 33) {
                    icon_label.set_text ("󰖀");
                } 
                else if (volume > 0) {
                    icon_label.set_text ("󰕿");
                } 
                else {
                    icon_label.set_text ("󰖁");
                }
                value_label.set_text ("%d%%".printf (volume));
            }
        }
    }
}
