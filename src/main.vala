using Gtk;

namespace ViaShell {

    public class Application : Gtk.Application {

        public Application () {
            Object (
                application_id: "com.github.quickshell",
                flags: ApplicationFlags.FLAGS_NONE
            );
        }

        protected override void activate () {
            load_css ();
            var panel = new Panel (this);
            panel.present ();
        }

        private void load_css () {
            var provider = new Gtk.CssProvider ();

            string[] css_paths = {
                "./style/style.css",
                "./style.css",
                GLib.Path.build_filename (
                    GLib.Environment.get_home_dir (),
                    ".config", "quickshell", "style.css"
                ),
                GLib.Path.build_filename (
                    "/usr/share/quickshell", "style.css"
                ),
                GLib.Path.build_filename (
                    "/usr/local/share/quickshell", "style.css"
                ),
            };

            foreach (var path in css_paths) {
                var file = GLib.File.new_for_path (path);
                if (file.query_exists ()) {
                    try {
                        provider.load_from_file (file);
                        Gtk.StyleContext.add_provider_for_display (
                            Gdk.Display.get_default (),
                            provider,
                            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
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
