using Gtk;

namespace ViaShell {

    public class Application : Gtk.Application {

        private GLib.GenericArray<Gtk.Window> windows = new GLib.GenericArray<Gtk.Window> ();
        private ThemeManager themes;

        public Application () {
            Object (
                application_id: "com.github.viadev0081.viashell",
                flags: ApplicationFlags.FLAGS_NONE
            );
        }

        protected override void activate () {
            var display = Gdk.Display.get_default ();
            if (display == null) {
                warning ("No display available");
                return;
            }

            themes = new ThemeManager ();
            themes.start ();

            var distro = Distro.detect ();
            var media = new MediaService ();
            var notifications = new NotificationService ();

            build_windows (display, distro, media, notifications);

            // Перестраиваем панели при изменении набора мониторов
            var monitors = display.get_monitors ();
            monitors.items_changed.connect (() => {
                build_windows (display, distro, media, notifications);
            });
        }

        private void build_windows (
            Gdk.Display display,
            Distro distro,
            MediaService media,
            NotificationService notifications
        ) {
            // Закрываем старые окна
            foreach (var window in windows) {
                window.destroy ();
            }

            windows = new GLib.GenericArray<Gtk.Window> ();

            var monitors = display.get_monitors ();
            uint count = monitors.get_n_items ();

            for (uint i = 0; i < count; i++) {
                var monitor = monitors.get_item (i) as Gdk.Monitor;
                if (monitor == null) {
                    continue;
                }

                var panel = new Panel (
                    this, monitor, distro, media, notifications, themes
                );
                panel.present ();
                windows.add (panel);
            }
        }

        public static int main (string[] args) {
            var app = new Application ();
            return app.run (args);
        }
    }
}
