using Gtk;

namespace ViaShell {

    public class ClockWidget : Gtk.Box {

        private Gtk.Label time_label;
        private Gtk.Label date_label;

        public ClockWidget () {
            Object (
                orientation: Gtk.Orientation.VERTICAL,
                spacing: 2
            );

            this.add_css_class ("widget");
            this.add_css_class ("clock");

            // Время (вертикально по буквам для боковой панели)
            time_label = new Gtk.Label ("");
            time_label.add_css_class ("time");
            time_label.set_justify (Gtk.Justification.CENTER);
            this.append (time_label);

            // Дата
            date_label = new Gtk.Label ("");
            date_label.add_css_class ("date");
            date_label.set_justify (Gtk.Justification.CENTER);
            this.append (date_label);

            // Обновляем каждую секунду
            update_time ();
            GLib.Timeout.add_seconds (1, () => {
                update_time ();
                return GLib.Source.CONTINUE;
            });
        }

        private void update_time () {
            var now = new GLib.DateTime.now_local ();

            // Для вертикальной панели отображаем время компактно
            string hour = now.format ("%H");
            string minute = now.format ("%M");

            // Каждую цифру на новой строке для вертикальной панели
            time_label.set_markup (
                "<span font_weight='bold'>%s</span>\n<span font_weight='bold'>%s</span>".printf (hour, minute)
            );

            // Дата: день недели и число
            date_label.set_text (now.format ("%a\n%d"));
        }
    }
}
