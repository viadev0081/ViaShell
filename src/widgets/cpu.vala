using Gtk;

namespace ViaShell {

    public class CpuWidget : Gtk.Box {

        private Gtk.Label icon_label;
        private Gtk.Label value_label;
        private Gtk.LevelBar level_bar;

        public CpuWidget () {
            Object (
                orientation: Gtk.Orientation.VERTICAL,
                spacing: 4
            );

            this.add_css_class ("widget");
            this.add_css_class ("cpu");

            // Иконка
            icon_label = new Gtk.Label ("󰍛");  // nerd font CPU icon
            icon_label.add_css_class ("widget-icon");
            this.append (icon_label);

            // Вертикальная полоска уровня
            level_bar = new Gtk.LevelBar ();
            level_bar.set_min_value (0);
            level_bar.set_max_value (100);
            level_bar.set_value (0);
            level_bar.set_orientation (Gtk.Orientation.VERTICAL);
            level_bar.set_inverted (true);
            level_bar.add_css_class ("vertical-bar");
            level_bar.set_size_request (6, 40);

            // Убираем стандартные offset'ы
            level_bar.remove_offset_value (Gtk.LEVEL_BAR_OFFSET_LOW);
            level_bar.remove_offset_value (Gtk.LEVEL_BAR_OFFSET_HIGH);
            level_bar.remove_offset_value (Gtk.LEVEL_BAR_OFFSET_FULL);

            level_bar.add_offset_value ("low", 30);
            level_bar.add_offset_value ("medium", 60);
            level_bar.add_offset_value ("high", 85);
            level_bar.add_offset_value ("critical", 100);

            this.append (level_bar);

            // Значение в процентах
            value_label = new Gtk.Label ("0%");
            value_label.add_css_class ("widget-value");
            this.append (value_label);

            // Первый вызов — инициализация (пропускаем первое значение)
            SystemInfo.get_cpu_usage ();

            // Обновляем каждые 2 секунды
            GLib.Timeout.add_seconds (2, () => {
                update_value ();
                return GLib.Source.CONTINUE;
            });

            // Начальное обновление через 1 секунду
            GLib.Timeout.add_seconds (1, () => {
                update_value ();
                return GLib.Source.REMOVE;
            });
        }

        private void update_value () {
            double usage = SystemInfo.get_cpu_usage ();
            int usage_int = (int) Math.round (usage);

            value_label.set_text ("%d%%".printf (usage_int));
            level_bar.set_value (usage);

            // Обновляем CSS классы для цвета
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
