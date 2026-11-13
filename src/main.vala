using Gtk;

namespace ViaShell {

    public class Application : Gtk.Application {

        private GLib.GenericArray<Gtk.Window> windows = new GLib.GenericArray<Gtk.Window> ();

        public Application () {
            Object (
                application_id: "com.github.viadev0081.viashell",
                flags: ApplicationFlags.FLAGS_NONE
            );
        }

        protected override void activate () {
            load_css ();

            var display = Gdk.Display.get_default ();
            if (display == null) {
                warning ("No display available");
                return;
            }

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

                var panel = new Panel (this, monitor, distro, media, notifications);
                panel.present ();
                windows.add (panel);
            }
        }

        private void load_css () {
            var provider = new Gtk.CssProvider ();

            string config_css = GLib.Path.build_filename (
                GLib.Environment.get_user_config_dir (), "viashell", "style.css"
            );

            string[] css_paths = {
                "./style/style.css",
                "./style.css",
            };

            // Ищем тему рядом с исполняемым файлом (build/src/../../style/style.css)
            try {
                string exe = GLib.FileUtils.read_link ("/proc/self/exe");
                string exe_dir = GLib.Path.get_dirname (exe);
                css_paths += GLib.Path.build_filename (
                    exe_dir, "..", "..", "style", "style.css"
                );
                css_paths += GLib.Path.build_filename (
                    exe_dir, "..", "..", "..", "style", "style.css"
                );
            } catch (GLib.Error e) {
                // /proc недоступен — обойдёмся стандартными путями
            }

            css_paths += config_css;
            css_paths += GLib.Path.build_filename ("/usr/share/viashell", "style.css");
            css_paths += GLib.Path.build_filename ("/usr/local/share/viashell", "style.css");

            foreach (var path in css_paths) {
                var file = GLib.File.new_for_path (path);
                if (file.query_exists ()) {
                    try {
                        provider.load_from_file (file);
                        Gtk.StyleContext.add_provider_for_display (
                            Gdk.Display.get_default (),
                            provider,
                            Gtk.STYLE_PROVIDER_PRIORITY_USER + 100
                        );
                        stdout.printf ("CSS loaded: %s\n", path);
                        return;
                    } catch (GLib.Error e) {
                        warning ("CSS load error %s: %s", path, e.message);
                    }
                }
            }
            warning ("No CSS found");
        }

        public static int main (string[] args) {
            var app = new Application ();
            return app.run (args);
        }
    }
}
