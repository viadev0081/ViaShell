using Gtk;

namespace ViaShell {

    /*
     * Управление цветовыми схемами интерфейса.
     * Базовый CSS лежит в style/style.css, а @define-color подставляется
     * сюда — поэтому тему можно менять на лету без перезапуска панели.
     */
    public class ThemeManager : GLib.Object {

        public signal void changed ();

        public string[] keys = {
            "catppuccin",
            "tokyonight",
            "kanagawa",
            "nordic",
            "rose-pine"
        };

        public string[] labels = {
            "Catppuccin",
            "Tokyo Night",
            "Kanagawa",
            "Nordic",
            "Rosé Pine"
        };

        private Gtk.CssProvider provider;
        private string css_template = "";
        private int index = 0;

        public int current {
            get {
                return index;
            }
        }

        /*
         * Акцентный цвет темы — используется для логотипа и чипов,
         * чтобы при переключении на kanagawa/nordic/rose-pine не
         * оставались цвета из catppuccin.
         */
        public string accent_color () {
            switch (index) {
                case 1: return "#7aa2f7"; // Tokyo Night
                case 2: return "#7fb4ca"; // Kanagawa
                case 3: return "#81a1c1"; // Nordic
                case 4: return "#9ccfd8"; // Rosé Pine
                default: return "#89b4fa"; // Catppuccin
            }
        }

        public ThemeManager () {
            load_state ();
            css_template = load_template ();
        }

        public void start () {
            var display = Gdk.Display.get_default ();
            if (display == null) {
                warning ("ThemeManager: нет дисплея");
                return;
            }

            provider = new Gtk.CssProvider ();
            provider.parsing_error.connect ((section, error) => {
                warning ("CSS: %s", error.message);
            });

            apply ();

            Gtk.StyleContext.add_provider_for_display (
                display, provider, Gtk.STYLE_PROVIDER_PRIORITY_USER + 100
            );
        }

        public void set_theme (int new_index) {
            if (new_index < 0 || new_index >= keys.length) {
                return;
            }
            if (new_index == index) {
                return;
            }

            index = new_index;
            save_state ();
            apply ();
            changed ();
        }

        private void apply () {
            if (provider == null) {
                return;
            }

            string css = definitions () + "\n" + css_template;
            provider.load_from_data (css.data);
        }

        /* ------------------------------------------------------------------ */
        /*  Поиск и подготовка CSS                                            */
        /* ------------------------------------------------------------------ */
        private string load_template () {
            string? path = find_css_path ();
            if (path == null) {
                warning ("Не найден style.css");
                return "";
            }

            string contents;
            try {
                GLib.FileUtils.get_contents (path, out contents);
            }
            catch (GLib.Error e) {
                warning ("Не удалось прочитать %s: %s", path, e.message);
                return "";
            }

            // Убираем определения из файла — их подставит выбранная тема.
            var builder = new StringBuilder ();
            foreach (var line in contents.split ("\n")) {
                if (line.strip ().has_prefix ("@define-color")) {
                    continue;
                }
                builder.append (line);
                builder.append ("\n");
            }

            stdout.printf ("CSS loaded: %s\n", path);
            return builder.str;
        }

        private static string? find_css_path () {
            string config_css = GLib.Path.build_filename (
                GLib.Environment.get_user_config_dir (), "viashell", "style.css"
            );

            string[] paths = {
                "./style/style.css",
                "./style.css",
            };

            // style.css рядом с исполняемым файлом (build/src/../../style/style.css)
            try {
                string exe = GLib.FileUtils.read_link ("/proc/self/exe");
                string exe_dir = GLib.Path.get_dirname (exe);
                paths += GLib.Path.build_filename (
                    exe_dir, "..", "..", "style", "style.css"
                );
                paths += GLib.Path.build_filename (
                    exe_dir, "..", "..", "..", "style", "style.css"
                );
            }
            catch (GLib.Error e) {
                // /proc недоступен — обойдёмся стандартными путями
            }

            paths += config_css;
            paths += GLib.Path.build_filename ("/usr/share/viashell", "style.css");
            paths += GLib.Path.build_filename ("/usr/local/share/viashell", "style.css");

            foreach (var path in paths) {
                var file = GLib.File.new_for_path (path);
                if (file.query_exists ()) {
                    return path;
                }
            }

            return null;
        }

        /* ------------------------------------------------------------------ */
        /*  Сохранение выбранной темы                                         */
        /* ------------------------------------------------------------------ */
        private void load_state () {
            string path = state_path ();
            string contents;

            try {
                GLib.FileUtils.get_contents (path, out contents);
            }
            catch (GLib.Error e) {
                return;
            }

            string value = contents.strip ();
            for (int i = 0; i < keys.length; i++) {
                if (keys[i] == value) {
                    index = i;
                    return;
                }
            }
        }

        private void save_state () {
            string path = state_path ();
            try {
                GLib.FileUtils.set_contents (path, keys[index]);
            }
            catch (GLib.Error e) {
                warning ("Не удалось сохранить тему: %s", e.message);
            }
        }

        private static string state_path () {
            string dir = GLib.Path.build_filename (
                GLib.Environment.get_user_config_dir (), "viashell"
            );
            GLib.DirUtils.create_with_parents (dir, 0755);
            return GLib.Path.build_filename (dir, "theme");
        }

        /* ------------------------------------------------------------------ */
        /*  Палитры                                                           */
        /* ------------------------------------------------------------------ */
        private string definitions () {
            switch (index) {
                case 1: return TOKYO_NIGHT;
                case 2: return KANAGAWA;
                case 3: return NORDIC;
                case 4: return ROSE_PINE;
                default: return CATPPUCCIN;
            }
        }

        private const string CATPPUCCIN =
            "@define-color base      #1e1e2e;\n" +
            "@define-color mantle    #181825;\n" +
            "@define-color crust     #11111b;\n" +
            "@define-color text      #cdd6f4;\n" +
            "@define-color subtext   #a6adc8;\n" +
            "@define-color overlay   #6c7086;\n" +
            "@define-color surface   #313244;\n" +
            "@define-color surface2  #45475a;\n" +
            "@define-color lavender  #b4befe;\n" +
            "@define-color blue      #89b4fa;\n" +
            "@define-color sapphire  #74c7ec;\n" +
            "@define-color mauve     #cba6f7;\n" +
            "@define-color pink      #f5c2e7;\n" +
            "@define-color red       #f38ba8;\n" +
            "@define-color peach     #fab387;\n" +
            "@define-color yellow    #f9e2af;\n" +
            "@define-color green     #a6e3a1;\n" +
            "@define-color teal      #94e2d5;\n";

        private const string TOKYO_NIGHT =
            "@define-color base      #1a1b26;\n" +
            "@define-color mantle    #16161e;\n" +
            "@define-color crust     #13131a;\n" +
            "@define-color text      #c0caf5;\n" +
            "@define-color subtext   #a9b1d6;\n" +
            "@define-color overlay   #565f89;\n" +
            "@define-color surface   #292e42;\n" +
            "@define-color surface2  #3b4261;\n" +
            "@define-color lavender  #7aa2f7;\n" +
            "@define-color blue      #7aa2f7;\n" +
            "@define-color sapphire  #2ac3de;\n" +
            "@define-color mauve     #bb9af7;\n" +
            "@define-color pink      #ff75a0;\n" +
            "@define-color red       #f7768e;\n" +
            "@define-color peach     #ff9e64;\n" +
            "@define-color yellow    #e0af68;\n" +
            "@define-color green     #9ece6a;\n" +
            "@define-color teal      #73daca;\n";

        private const string KANAGAWA =
            "@define-color base      #1f1f28;\n" +
            "@define-color mantle    #16161d;\n" +
            "@define-color crust     #0d0c15;\n" +
            "@define-color text      #dcd7ba;\n" +
            "@define-color subtext   #c8c093;\n" +
            "@define-color overlay   #727169;\n" +
            "@define-color surface   #2a2a37;\n" +
            "@define-color surface2  #363646;\n" +
            "@define-color lavender  #7e9cd8;\n" +
            "@define-color blue      #7fb4ca;\n" +
            "@define-color sapphire  #6a9589;\n" +
            "@define-color mauve     #957fb8;\n" +
            "@define-color pink      #d27e99;\n" +
            "@define-color red       #e46876;\n" +
            "@define-color peach     #ffa066;\n" +
            "@define-color yellow    #e6c384;\n" +
            "@define-color green     #98bb6c;\n" +
            "@define-color teal      #7aa89f;\n";

        private const string NORDIC =
            "@define-color base      #2e3440;\n" +
            "@define-color mantle    #292e39;\n" +
            "@define-color crust     #242933;\n" +
            "@define-color text      #eceff4;\n" +
            "@define-color subtext   #d8dee9;\n" +
            "@define-color overlay   #616e88;\n" +
            "@define-color surface   #3b4252;\n" +
            "@define-color surface2  #434c5e;\n" +
            "@define-color lavender  #88c0d0;\n" +
            "@define-color blue      #81a1c1;\n" +
            "@define-color sapphire  #5e81ac;\n" +
            "@define-color mauve     #b48ead;\n" +
            "@define-color pink      #d08770;\n" +
            "@define-color red       #bf616a;\n" +
            "@define-color peach     #d08770;\n" +
            "@define-color yellow    #ebcb8b;\n" +
            "@define-color green     #a3be8c;\n" +
            "@define-color teal      #8fbcbb;\n";

        private const string ROSE_PINE =
            "@define-color base      #191724;\n" +
            "@define-color mantle    #1f1d2e;\n" +
            "@define-color crust     #14121f;\n" +
            "@define-color text      #e0def4;\n" +
            "@define-color subtext   #908caa;\n" +
            "@define-color overlay   #6e6a86;\n" +
            "@define-color surface   #26233a;\n" +
            "@define-color surface2  #403d52;\n" +
            "@define-color lavender  #c4a7e7;\n" +
            "@define-color blue      #9ccfd8;\n" +
            "@define-color sapphire  #31748f;\n" +
            "@define-color mauve     #c4a7e7;\n" +
            "@define-color pink      #ebbcba;\n" +
            "@define-color red       #eb6f92;\n" +
            "@define-color peach     #f6c177;\n" +
            "@define-color yellow    #f6c177;\n" +
            "@define-color green     #9ccfd8;\n" +
            "@define-color teal      #31748f;\n";
    }
}
