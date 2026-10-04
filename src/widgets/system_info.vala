namespace ViaShell {

    public class SystemInfo {

        // Предыдущие значения для расчёта CPU
        private static uint64 prev_total = 0;
        private static uint64 prev_idle = 0;

        /**
         * Получить использование CPU в процентах
         */
        public static double get_cpu_usage () {
            try {
                string contents;
                GLib.FileUtils.get_contents ("/proc/stat", out contents);

                var lines = contents.split ("\n");
                if (lines.length == 0) return 0.0;

                var first_line = lines[0]; // "cpu  user nice system idle iowait irq softirq steal"
                var parts = first_line.split_set (" ");

                // Фильтруем пустые строки
                uint64[] values = {};
                foreach (var part in parts) {
                    if (part != "cpu" && part.strip () != "") {
                        values += uint64.parse (part.strip ());
                    }
                }

                if (values.length < 4) return 0.0;

                uint64 user = values[0];
                uint64 nice = values[1];
                uint64 system = values[2];
                uint64 idle = values[3];
                uint64 iowait = values.length > 4 ? values[4] : 0;
                uint64 irq = values.length > 5 ? values[5] : 0;
                uint64 softirq = values.length > 6 ? values[6] : 0;
                uint64 steal = values.length > 7 ? values[7] : 0;

                uint64 total_idle = idle + iowait;
                uint64 total = user + nice + system + idle + iowait + irq + softirq + steal;

                uint64 total_diff = total - prev_total;
                uint64 idle_diff = total_idle - prev_idle;

                prev_total = total;
                prev_idle = total_idle;

                if (total_diff == 0) return 0.0;

                return (1.0 - ((double) idle_diff / (double) total_diff)) * 100.0;
            } catch (GLib.Error e) {
                warning ("Failed to read CPU info: %s", e.message);
                return 0.0;
            }
        }

        /**
         * Получить использование памяти в процентах
         */
        public static double get_memory_usage () {
            try {
                string contents;
                GLib.FileUtils.get_contents ("/proc/meminfo", out contents);

                var lines = contents.split ("\n");

                uint64 mem_total = 0;
                uint64 mem_available = 0;

                foreach (var line in lines) {
                    if (line.has_prefix ("MemTotal:")) {
                        mem_total = parse_meminfo_value (line);
                    } 
                    else if (line.has_prefix ("MemAvailable:")) {
                        mem_available = parse_meminfo_value (line);
                    }
                }

                if (mem_total == 0) return 0.0;

                uint64 mem_used = mem_total - mem_available;
                return ((double) mem_used / (double) mem_total) * 100.0;
            } catch (GLib.Error e) {
                warning ("Failed to read memory info: %s", e.message);
                return 0.0;
            }
        }

        /**
         * Получить уровень громкости (0-100)
         * Использует wpctl (WirePlumber) или pactl
         */
        public static int get_volume () {
            try {
                string stdout_buf;
                string stderr_buf;
                int exit_status;

                // Пробуем wpctl (WirePlumber)
                GLib.Process.spawn_command_line_sync (
                    "wpctl get-volume @DEFAULT_AUDIO_SINK@",
                    out stdout_buf, out stderr_buf, out exit_status
                );

                if (exit_status == 0 && stdout_buf != null) {
                    // Формат: "Volume: 0.50" или "Volume: 0.50 [MUTED]"
                    var parts = stdout_buf.strip ().split (" ");
                    if (parts.length >= 2) {
                        double vol = double.parse (parts[1]);
                        return (int) (vol * 100.0);
                    }
                }
            } catch (GLib.Error e) {
                // wpctl не найден, пробуем pactl
            }

            try {
                string stdout_buf;
                string stderr_buf;
                int exit_status;

                GLib.Process.spawn_command_line_sync (
                    "pactl get-sink-volume @DEFAULT_SINK@",
                    out stdout_buf, out stderr_buf, out exit_status
                );

                if (exit_status == 0 && stdout_buf != null) {
                    // Ищем процент
                    var regex = new GLib.Regex ("""(\d+)%""");
                    GLib.MatchInfo match_info;
                    if (regex.match (stdout_buf, 0, out match_info)) {
                        return int.parse (match_info.fetch (1));
                    }
                }
            } catch (GLib.Error e) {
                warning ("Failed to get volume: %s", e.message);
            }

            return 0;
        }

        /**
         * Проверить, замьючен ли звук
         */
        public static bool is_muted () {
            try {
                string stdout_buf;
                string stderr_buf;
                int exit_status;

                GLib.Process.spawn_command_line_sync (
                    "wpctl get-volume @DEFAULT_AUDIO_SINK@",
                    out stdout_buf, out stderr_buf, out exit_status
                );

                if (exit_status == 0 && stdout_buf != null) {
                    return stdout_buf.contains ("[MUTED]");
                }
            } catch (GLib.Error e) {
                // fallback
            }

            try {
                string stdout_buf;
                string stderr_buf;
                int exit_status;

                GLib.Process.spawn_command_line_sync (
                    "pactl get-sink-mute @DEFAULT_SINK@",
                    out stdout_buf, out stderr_buf, out exit_status
                );

                if (exit_status == 0 && stdout_buf != null) {
                    return stdout_buf.contains ("yes");
                }
            } catch (GLib.Error e) {
                warning ("Failed to check mute: %s", e.message);
            }

            return false;
        }

        /**
         * Получить яркость (0-100)
         */
        public static int get_brightness () {
            // Пробуем brightnessctl
            try {
                string stdout_buf;
                string stderr_buf;
                int exit_status;

                GLib.Process.spawn_command_line_sync (
                    "brightnessctl -m",
                    out stdout_buf, out stderr_buf, out exit_status
                );

                if (exit_status == 0 && stdout_buf != null) {
                    // Формат: device,class,current,max,percentage
                    // Пример: "intel_backlight,backlight,500,1000,50%"
                    var parts = stdout_buf.strip ().split (",");
                    if (parts.length >= 4) {
                        int current = int.parse (parts[2]);
                        int max_val = int.parse (parts[3]);
                        if (max_val > 0) {
                            return (int) (((double) current / (double) max_val) * 100.0);
                        }
                    }
                }
            } catch (GLib.Error e) {
                // brightnessctl не найден
            }

            // Пробуем через sysfs напрямую
            try {
                string base_path = "/sys/class/backlight/";
                var dir = GLib.Dir.open (base_path);
                string? name = null;

                while ((name = dir.read_name ()) != null) {
                    string brightness_path = GLib.Path.build_filename (base_path, name, "brightness");
                    string max_path = GLib.Path.build_filename (base_path, name, "max_brightness");

                    if (GLib.FileUtils.test (brightness_path, GLib.FileTest.EXISTS)) {
                        string brightness_str, max_str;
                        GLib.FileUtils.get_contents (brightness_path, out brightness_str);
                        GLib.FileUtils.get_contents (max_path, out max_str);

                        int current = int.parse (brightness_str.strip ());
                        int max_val = int.parse (max_str.strip ());

                        if (max_val > 0) {
                            return (int) (((double) current / (double) max_val) * 100.0);
                        }
                    }
                }
            } catch (GLib.Error e) {
                warning ("Failed to get brightness: %s", e.message);
            }

            return 100; // По умолчанию
        }

        /**
         * Получить уровень заряда батареи (0-100)
         */
        public static int get_battery_level () {
            try {
                string base_path = "/sys/class/power_supply/";
                var dir = GLib.Dir.open (base_path);
                string? name = null;

                while ((name = dir.read_name ()) != null) {
                    string type_path = GLib.Path.build_filename (base_path, name, "type");

                    if (GLib.FileUtils.test (type_path, GLib.FileTest.EXISTS)) {
                        string type_str;
                        GLib.FileUtils.get_contents (type_path, out type_str);

                        if (type_str.strip () == "Battery") {
                            string capacity_path = GLib.Path.build_filename (base_path, name, "capacity");
                            if (GLib.FileUtils.test (capacity_path, GLib.FileTest.EXISTS)) {
                                string capacity_str;
                                GLib.FileUtils.get_contents (capacity_path, out capacity_str);
                                return int.parse (capacity_str.strip ());
                            }
                        }
                    }
                }
            } catch (GLib.Error e) {
                warning ("Failed to get battery level: %s", e.message);
            }

            return -1; // Нет батареи
        }

        /**
         * Проверить, заряжается ли батарея
         */
        public static bool is_battery_charging () {
            try {
                string base_path = "/sys/class/power_supply/";
                var dir = GLib.Dir.open (base_path);
                string? name = null;

                while ((name = dir.read_name ()) != null) {
                    string type_path = GLib.Path.build_filename (base_path, name, "type");

                    if (GLib.FileUtils.test (type_path, GLib.FileTest.EXISTS)) {
                        string type_str;
                        GLib.FileUtils.get_contents (type_path, out type_str);

                        if (type_str.strip () == "Battery") {
                            string status_path = GLib.Path.build_filename (base_path, name, "status");
                            if (GLib.FileUtils.test (status_path, GLib.FileTest.EXISTS)) {
                                string status_str;
                                GLib.FileUtils.get_contents (status_path, out status_str);
                                return status_str.strip () == "Charging";
                            }
                        }
                    }
                }
            } catch (GLib.Error e) {
                warning ("Failed to get battery status: %s", e.message);
            }

            return false;
        }

        private static uint64 parse_meminfo_value (string line) {
            var parts = line.split_set (": \t");
            foreach (var part in parts) {
                var stripped = part.strip ();
                if (stripped != "" && stripped != "kB" && !stripped.has_prefix ("Mem")) {
                    return uint64.parse (stripped);
                }
            }
            return 0;
        }
    }
}
