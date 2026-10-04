using Gtk;
using GtkLayerShell;

namespace ViaShell {

    public class Panel : Gtk.Window {

        private Gtk.Box main_box;

        // Виджеты
        private ClockWidget clock_widget;
        private CpuWidget cpu_widget;
        private MemoryWidget memory_widget;
        private VolumeWidget volume_widget;
        private BrightnessWidget brightness_widget;
        private BatteryWidget battery_widget;

        public Panel (Gtk.Application app) {
            Object (application: app);

            // Инициализация Layer Shell
            GtkLayerShell.init_for_window (this);
            GtkLayerShell.set_layer (this, GtkLayerShell.Layer.TOP);
            GtkLayerShell.set_namespace (this, "quickshell");

            // Привязка к левому краю
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);

            // Отступы для "плавающего" эффекта
            GtkLayerShell.set_margin (this, GtkLayerShell.Edge.LEFT, 8);
            GtkLayerShell.set_margin (this, GtkLayerShell.Edge.TOP, 8);
            GtkLayerShell.set_margin (this, GtkLayerShell.Edge.BOTTOM, 8);

            // Эксклюзивная зона
            GtkLayerShell.auto_exclusive_zone_enable (this);

            setup_ui ();
        }

        private void setup_ui () {
            // CSS класс для окна
            this.add_css_class ("panel-window");

            // Основной вертикальный контейнер
            main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            main_box.add_css_class ("panel");
            main_box.set_valign (Gtk.Align.FILL);
            main_box.set_vexpand (true);

            // === Верхняя группа ===
            var top_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            top_box.add_css_class ("modules-top");
            top_box.set_valign (Gtk.Align.START);
            top_box.set_vexpand (false);

            // Workspaces placeholder (можно расширить позже)
            var workspace_label = new Gtk.Label ("⬤");
            workspace_label.add_css_class ("workspace-indicator");
            top_box.append (workspace_label);

            // === Центральная группа ===
            var center_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            center_box.add_css_class ("modules-center");
            center_box.set_valign (Gtk.Align.CENTER);
            center_box.set_vexpand (true);

            // CPU
            cpu_widget = new CpuWidget ();
            center_box.append (cpu_widget);

            // RAM
            memory_widget = new MemoryWidget ();
            center_box.append (memory_widget);

            // Разделитель
            var sep1 = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
            sep1.add_css_class ("separator");
            center_box.append (sep1);

            // Volume
            volume_widget = new VolumeWidget ();
            center_box.append (volume_widget);

            // Brightness
            brightness_widget = new BrightnessWidget ();
            center_box.append (brightness_widget);

            // === Нижняя группа ===
            var bottom_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            bottom_box.add_css_class ("modules-bottom");
            bottom_box.set_valign (Gtk.Align.END);
            bottom_box.set_vexpand (false);

            // Battery
            battery_widget = new BatteryWidget ();
            bottom_box.append (battery_widget);

            // Разделитель
            var sep2 = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
            sep2.add_css_class ("separator");
            bottom_box.append (sep2);

            // Clock
            clock_widget = new ClockWidget ();
            bottom_box.append (clock_widget);

            // Собираем всё
            main_box.append (top_box);
            main_box.append (center_box);
            main_box.append (bottom_box);

            this.set_child (main_box);
        }
    }
}
