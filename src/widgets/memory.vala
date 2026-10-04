using Gtk;

namespace ViaShell {

    public class MemoryWidget : Gtk.Box {

        private Gtk.Label icon_label;
        private Gtk.Label value_label;
        private Gtk.LevelBar level_bar;

        public MemoryWidget () {
            Object (
                orientation: Gtk.Orientation.VERTICAL,
                spacing: 4
            );

            this.add_css_class ("widget");
            this.add_css_class ("memory");

            // Иконка
            icon_label = new Gtk.Label ("󰘚");  // nerd font RAM icon
            icon_label.add_css_class ("widget-icon");
            this.append (icon_label);

            // Вертикальная полоска
            level_bar = new Gtk.LevelBar ();
            level_bar.set_min_value (0);
            level_bar.set_max_value (100);
            level_bar.set_value (0);
            level_bar.set_orientation (Gtk.Orientation.VERTICAL);
            level_bar.set_inverted (true);
            level_bar.add_css_class ("vertical-bar");
            level_bar.set_size_request (6, 40);

            level_bar.remove_offset_value (Gtk.LEVEL_BAR_OFFSET_LOW);
            level_bar.remove_offset_value (Gtk.LEVEL_BAR_OFFSET_HIGH);
            level_bar.remove_offset_value (Gtk.LEVEL_BAR_OFFSET_FULL);

            level_bar.add_offset_value ("low", 30);
            level_bar.add_offset_value ("medium", 60);
            level_bar.add_offset_value ("high", 85);
            level_bar.add_offset_value ("critical", 100);

            this.append (level_bar);

            // Значение
            value_label = new Gtk.Label ("0%");
            value_label.add_css_class ("widget-value");
            this.append (value_label);

            // Обновляем каждые 3 секунды
            update_value ();
            GLib.Timeout.add_seconds (3, () => {
                update_value ();
                return GLib.Source.CONTINUE;
            });
        }

        private void update_value () {
            double usage = SystemInfo.get_memory_usage ();
            int usage_int = (int) Math.round (usage);

            value_label.set_text ("%d%%".printf (usage_int));
            level_bar.set_value (usage);

            this.remove_css_class ("warning");
            this.remove_css_class ("critical");

            if (usage > 85) {
                this.add_css_class ("critical");
            } 
            else if (usage > 60) {
                this.add_css_class ("warning");
            }
        }
    }
}
