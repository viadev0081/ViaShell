using GLib;

namespace ViaShell {

    /*
     * Простейший парсер INI-конфига.
     * Формат:
     *   [секция]
     *   ключ = значение
     *   # или ; — комментарий
     *
     * Используется, чтобы включать и выключать элементы панели и меню
     * без перекомпиляции. Файл ищется в ~/.config/viashell/config.ini.
     */
    public class IniConfig : GLib.Object {

        private HashTable<string, HashTable<string, string>> sections =
            new HashTable<string, HashTable<string, string>> (str_hash, str_equal);

        public bool load (string path) {
            if (!FileUtils.test (path, FileTest.EXISTS)) {
                return false;
            }

            string contents;
            try {
                FileUtils.get_contents (path, out contents);
            } catch (GLib.Error e) {
                warning ("IniConfig: не удалось прочитать %s: %s", path, e.message);
                return false;
            }

            string? current_section = null;
            foreach (var raw_line in contents.split ("\n")) {
                var line = raw_line.strip ();
                if (line == "" || line.has_prefix ("#") || line.has_prefix (";")) {
                    continue;
                }

                if (line.has_prefix ("[") && line.has_suffix ("]")) {
                    current_section = line.substring (1, line.length - 2).strip ();
                    if (!sections.contains (current_section)) {
                        sections[current_section] =
                            new HashTable<string, string> (str_hash, str_equal);
                    }
                    continue;
                }

                if (current_section == null) {
                    continue;
                }

                int eq = line.index_of ("=");
                if (eq < 0) {
                    continue;
                }

                string key = line.substring (0, eq).strip ();
                string value = line.substring (eq + 1).strip ();
                sections[current_section][key] = value;
            }

            return true;
        }

        public bool get_bool (string section, string key, bool default_value = false) {
            if (!sections.contains (section)) {
                return default_value;
            }
            var table = sections[section];
            if (!table.contains (key)) {
                return default_value;
            }

            string v = table[key].down ();
            return v == "1" || v == "true" || v == "yes" || v == "on";
        }

        public string get_string (string section, string key, string default_value = "") {
            if (!sections.contains (section)) {
                return default_value;
            }
            var table = sections[section];
            if (!table.contains (key)) {
                return default_value;
            }
            return table[key];
        }
    }
}
