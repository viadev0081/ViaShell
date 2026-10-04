using Gtk;

namespace ViaShell {

    public class BatteryWidget : Gtk.Box {

        private Gtk.Label icon_label;
        private Gtk.Label value_label;
        private bool has_battery = true;

        public BatteryWidget () {
            Object (
                orientation: Gtk.Orientation.VERTICAL,
                spacing: 4
            );

            this.add_css_class ("widget");
            this.add_css_class ("battery");

            // Иконка
            icon_label = new Gtk.Label ("󰁹");
            icon_label.add_css_class ("widget-icon");
            this.append (icon_label);

            // Значение
            value_label = new Gtk.Label ("");
            value_label.add_css_class ("widget-value");
            this.append (value_label);

            // Обновление каждые 30 секунд
            update_value ();
            GLib.Timeout.add_seconds (30, () => {
                update_value ();
                return GLib.Source.CONTINUE;
            });
        }

        private void update_value () {
            int level = SystemInfo.get_battery_level ();
            bool charging = SystemInfo.is_battery_charging ();

            if (level < 0) {
                // Нет батареи
                has_battery = false;
                icon_label.set_text ("󰚥");  // power plug
                value_label.set_text ("AC");
                this.set_visible (false);  // Скрываем если нет батареи
                return;
            }

            has_battery = true;
            this.set_visible (true);
            value_label.set_text ("%d%%".printf (level));

            // Убираем все status-классы
            this.remove_css_class ("charging");
            this.remove_css_class ("warning");
            this.remove_css_class ("critical");

            if (charging) {
                icon_label.set_text ("󰂄");  // charging
                this.add_css_class ("charging");
            } 
            else if (level > 90) {
                icon_label.set_text ("󰁹");
            } 
            else if (level > 70) {
                icon_label.set_text ("󰂁");
            } 
            else if (level > 50) {
                icon_label.set_text ("󰁿");
            } 
            else if (level > 30) {
                icon_label.set_text ("󰁽");
                this.add_css_class ("warning");
            } 
            else if (level > 15) {
                icon_label.set_text ("󰁻");
                this.add_css_class ("warning");
            } 
            else {
                icon_label.set_text ("󰂃");
                this.add_css_class ("critical");
            }
        }
    }
}
