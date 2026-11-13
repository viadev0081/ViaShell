namespace ViaShell {

    public class SystemInfo {

        // Предыдущие значения для расчёта нагрузки CPU
        private static uint64 prev_total = 0;
        private static uint64 prev_idle = 0;
        private static uint64[] prev_core_total = {};
        private static uint64[] prev_core_idle = {};

        /* ------------------------------------------------------------------ */
        /*  CPU                                                               */
        /* ------------------------------------------------------------------ */
        public static double get_cpu_usage () {
            try {
                string contents;
                GLib.FileUtils.get_contents ("/proc/stat", out contents);

                var lines = contents.split ("\n");
                if (lines.length == 0) {
                    return 0.0;
                }

                var parts = lines[0].split_set (" \t");

                uint64[] values = {};
                foreach (var part in parts) {
                    if (part != "cpu" && part.strip () != "") {
                        values += uint64.parse (part.strip ());
                    }
                }

                if (values.length < 4) {
                    return 0.0;
                }

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

                if (prev_total == 0) {
                    prev_total = total;
                    prev_idle = total_idle;
                    return total > 0 ? (1.0 - ((double) total_idle / (double) total)) * 100.0 : 0.0;
                }

                uint64 total_diff = total - prev_total;
                uint64 idle_diff = total_idle - prev_idle;

                prev_total = total;
                prev_idle = total_idle;

                if (total_diff == 0) {
                    return 0.0;
                }

                return (1.0 - ((double) idle_diff / (double) total_diff)) * 100.0;
            } catch (GLib.Error e) {
                warning ("Failed to read CPU info: %s", e.message);
                return 0.0;
            }
        }

        public static int get_cpu_core_count () {
            int count = 0;
            try {
                string contents;
                GLib.FileUtils.get_contents ("/proc/stat", out contents);
                foreach (var line in contents.split ("\n")) {
                    if (line.has_prefix ("cpu") && line.length > 3 &&
                        line[3] >= '0' && line[3] <= '9') {
                        count++;
                    }
                }
            } catch (GLib.Error e) {
                warning ("Failed to count CPU cores: %s", e.message);
            }

            return count > 0 ? count : 1;
        }

        public static double[] get_cpu_core_usages () {
            double[] result = {};
            uint64[] totals = {};
            uint64[] idles = {};

            try {
                string contents;
                GLib.FileUtils.get_contents ("/proc/stat", out contents);

                foreach (var line in contents.split ("\n")) {
                    if (!line.has_prefix ("cpu") || line.length <= 3) {
                        continue;
                    }

                    if (line[3] < '0' || line[3] > '9') {
                        continue;
                    }

                    var parts = line.split_set (" \t");
                    uint64[] values = {};
                    for (int i = 1; i < parts.length; i++) {
                        if (parts[i].strip () != "") {
                            values += uint64.parse (parts[i].strip ());
                        }
                    }

                    if (values.length < 4) {
                        continue;
                    }

                    uint64 idle = values[3] + (values.length > 4 ? values[4] : 0);
                    uint64 total = 0;
                    foreach (var value in values) {
                        total += value;
                    }

                    totals += total;
                    idles += idle;
                }
            } catch (GLib.Error e) {
                warning ("Failed to read per-core CPU info: %s", e.message);
                return result;
            }

            bool first_run = prev_core_total.length != totals.length;
            for (int i = 0; i < totals.length; i++) {
                if (first_run) {
                    double usage = totals[i] > 0
                        ? (1.0 - ((double) idles[i] / (double) totals[i])) * 100.0
                        : 0.0;

                    result += usage;
                }
                else {
                    uint64 total_diff = totals[i] - prev_core_total[i];
                    uint64 idle_diff = idles[i] - prev_core_idle[i];
                    double usage = total_diff > 0
                        ? (1.0 - ((double) idle_diff / (double) total_diff)) * 100.0
                        : 0.0;
                    result += usage;
                }
            }

            prev_core_total = totals;
            prev_core_idle = idles;
            return result;
        }

        /* ------------------------------------------------------------------ */
        /*  Память                                                            */
        /* ------------------------------------------------------------------ */
        public static double get_memory_usage () {
            double total, used, free, available;
            get_memory_info (
                out total,
                out used,
                out free,
                out available
            );

            return total > 0 ? (used / total) * 100.0 : 0.0;
        }

        public static void get_memory_info (
            out double total_mib,
            out double used_mib,
            out double free_mib,
            out double available_mib
        ) {
            total_mib = 0;
            used_mib = 0;
            free_mib = 0;
            available_mib = 0;

            try {
                string contents;
                GLib.FileUtils.get_contents ("/proc/meminfo", out contents);

                uint64 mem_total = 0;
                uint64 mem_free = 0;
                uint64 mem_available = 0;

                foreach (var line in contents.split ("\n")) {
                    if (line.has_prefix ("MemTotal:")) {
                        mem_total = parse_meminfo_value (line);
                    }
                    else if (line.has_prefix ("MemFree:")) {
                        mem_free = parse_meminfo_value (line);
                    }
                    else if (line.has_prefix ("MemAvailable:")) {
                        mem_available = parse_meminfo_value (line);
                    }
                }

                total_mib = mem_total / 1024.0;
                free_mib = mem_free / 1024.0;
                available_mib = mem_available / 1024.0;
                used_mib = (mem_total - mem_available) / 1024.0;
            } catch (GLib.Error e) {
                warning ("Failed to read memory info: %s", e.message);
            }
        }

        /* ------------------------------------------------------------------ */
        /*  Звук                                                              */
        /* ------------------------------------------------------------------ */
        public static void get_volume_state (out int volume, out bool muted) {
            volume = 0;
            muted = false;

            if (GLib.Environment.find_program_in_path ("wpctl") != null) {
                try {
                    string stdout_buf, stderr_buf;
                    int status;
                    GLib.Process.spawn_command_line_sync (
                        "wpctl get-volume @DEFAULT_AUDIO_SINK@",
                        out stdout_buf,
                        out stderr_buf,
                        out status
                    );

                    if (status == 0 && stdout_buf != null) {
                        var parts = stdout_buf.strip ().split (" ");
                        if (parts.length >= 2) {
                            double vol = double.parse (parts[1]);
                            volume = (int) Math.round (vol * 100.0);
                        }

                        muted = stdout_buf.contains ("[MUTED]");
                        return;
                    }
                } catch (GLib.Error e) {
                    // Пробуем pactl
                }
            }

            if (GLib.Environment.find_program_in_path ("pactl") != null) {
                try {
                    string stdout_buf, stderr_buf;
                    int status;

                    GLib.Process.spawn_command_line_sync (
                        "pactl get-sink-volume @DEFAULT_SINK@",
                        out stdout_buf,
                        out stderr_buf,
                        out status
                    );

                    if (status == 0 && stdout_buf != null) {
                        var regex = new GLib.Regex ("""(\\d+)%""");
                        GLib.MatchInfo match_info;
                        if (regex.match (stdout_buf, 0, out match_info)) {
                            volume = int.parse (match_info.fetch (1));
                        }
                    }

                    GLib.Process.spawn_command_line_sync (
                        "pactl get-sink-mute @DEFAULT_SINK@",
                        out stdout_buf,
                        out stderr_buf,
                        out status
                    );

                    if (status == 0 && stdout_buf != null) {
                        muted = stdout_buf.contains ("yes");
                    }
                } catch (GLib.Error e) {
                    warning ("Failed to get volume: %s", e.message);
                }
            }
        }

        public static int get_volume () {
            int volume;
            bool muted;
            get_volume_state (out volume, out muted);
            return volume;
        }

        public static bool is_muted () {
            int volume;
            bool muted;
            get_volume_state (out volume, out muted);
            return muted;
        }

        public static void set_volume (int percent) {
            int value = percent < 0 ? 0 : (percent > 100 ? 100 : percent);

            if (GLib.Environment.find_program_in_path ("wpctl") != null) {
                run_async ("wpctl set-volume @DEFAULT_AUDIO_SINK@ %d%%".printf (value));
            }
            else if (GLib.Environment.find_program_in_path ("pactl") != null) {
                run_async ("pactl set-sink-volume @DEFAULT_SINK@ %d%%".printf (value));
            }
        }

        public static void set_muted (bool muted) {
            string state = muted ? "1" : "0";

            if (GLib.Environment.find_program_in_path ("wpctl") != null) {
                run_async ("wpctl set-mute @DEFAULT_AUDIO_SINK@ %s".printf (state));
            }
            else if (GLib.Environment.find_program_in_path ("pactl") != null) {
                run_async ("pactl set-sink-mute @DEFAULT_SINK@ %s".printf (state));
            }
        }

        /* ------------------------------------------------------------------ */
        /*  Яркость                                                           */
        /* ------------------------------------------------------------------ */
        public static string? find_backlight_device () {
            try {
                var dir = GLib.Dir.open ("/sys/class/backlight/");
                string? name = null;
                while ((name = dir.read_name ()) != null) {
                    string brightness_path = GLib.Path.build_filename (
                        "/sys/class/backlight", name, "brightness"
                    );

                    string max_path = GLib.Path.build_filename (
                        "/sys/class/backlight", name, "max_brightness"
                    );

                    if (
                        GLib.FileUtils.test (brightness_path, GLib.FileTest.EXISTS) &&
                        GLib.FileUtils.test (max_path, GLib.FileTest.EXISTS)
                    ) {
                        return name;
                    }
                }
            } catch (GLib.Error e) {
                // Нет backlight-устройства
            }
            return null;
        }

        public static bool has_brightness_control () {
            return GLib.Environment.find_program_in_path ("brightnessctl") != null || find_backlight_device () != null;
        }

        public static int get_brightness () {
            if (GLib.Environment.find_program_in_path ("brightnessctl") != null) {
                try {
                    string stdout_buf, stderr_buf;
                    int status;
                    GLib.Process.spawn_command_line_sync (
                        "brightnessctl -m",
                        out stdout_buf,
                        out stderr_buf,
                        out status
                    );

                    if (status == 0 && stdout_buf != null) {
                        var parts = stdout_buf.strip ().split (",");

                        if (parts.length >= 4) {
                            int current = int.parse (parts[2]);
                            int max_val = int.parse (parts[3]);
                            if (max_val > 0) {
                                return (int) Math.round (((double) current / (double) max_val) * 100.0);
                            }
                        }
                    }
                } catch (GLib.Error e) {
                    // Пробуем sysfs
                }
            }

            string? device = find_backlight_device ();
            if (device != null) {
                try {
                    string brightness_str, max_str;
                    GLib.FileUtils.get_contents (
                        GLib.Path.build_filename ("/sys/class/backlight", device, "brightness"),
                        out brightness_str
                    );

                    GLib.FileUtils.get_contents (
                        GLib.Path.build_filename ("/sys/class/backlight", device, "max_brightness"),
                        out max_str
                    );

                    int current = int.parse (brightness_str.strip ());
                    int max_val = int.parse (max_str.strip ());
                    if (max_val > 0) {
                        return (int) Math.round (((double) current / (double) max_val) * 100.0);
                    }
                } catch (GLib.Error e) {
                    warning ("Failed to read brightness: %s", e.message);
                }
            }

            return 100;
        }

        public static void set_brightness (int percent) {
            int value = percent < 0 ? 0 : (percent > 100 ? 100 : percent);

            if (GLib.Environment.find_program_in_path ("brightnessctl") != null) {
                run_async ("brightnessctl set %d%%".printf (value));
                return;
            }

            string? device = find_backlight_device ();
            if (device == null) {
                return;
            }

            int raw = -1;
            try {
                string max_str;
                GLib.FileUtils.get_contents (
                    GLib.Path.build_filename ("/sys/class/backlight", device, "max_brightness"),
                    out max_str
                );

                int max_val = int.parse (max_str.strip ());
                raw = (int) Math.round (max_val * (value / 100.0));

                GLib.FileUtils.set_contents (
                    GLib.Path.build_filename ("/sys/class/backlight", device, "brightness"),
                    "%d".printf (raw)
                );

                return;
            } catch (GLib.Error e) {
                // Прямая запись в sysfs обычно требует root — пробуем logind
            }

            if (raw >= 0 && GLib.Environment.find_program_in_path ("busctl") != null) {
                run_async (
                    "busctl call org.freedesktop.login1 /org/freedesktop/login1/session/auto " +
                    "org.freedesktop.login1.Session SetBrightness ssu backlight %s %d".printf (
                        device, raw
                    )
                );
            }
        }

        /* ------------------------------------------------------------------ */
        /*  Батарея                                                           */
        /* ------------------------------------------------------------------ */
        private static string? find_battery_name () {
            try {
                var dir = GLib.Dir.open ("/sys/class/power_supply/");
                string? name = null;
                string? fallback = null;

                while ((name = dir.read_name ()) != null) {
                    string dir_path = GLib.Path.build_filename ("/sys/class/power_supply", name);
                    string type_path = GLib.Path.build_filename (dir_path, "type");

                    if (!GLib.FileUtils.test (type_path, GLib.FileTest.EXISTS)) {
                        continue;
                    }

                    string type_str;
                    GLib.FileUtils.get_contents (type_path, out type_str);
                    if (type_str.strip () != "Battery") {
                        continue;
                    }

                    // Периферия (мыши, наушники) тоже отдаёт Type=Battery
                    string scope = "";
                    string scope_path = GLib.Path.build_filename (dir_path, "scope");
                    if (GLib.FileUtils.test (scope_path, GLib.FileTest.EXISTS)) {
                        try {
                            GLib.FileUtils.get_contents (scope_path, out scope);
                        } catch (GLib.Error e) {
                            scope = "";
                        }
                        scope = scope.strip ();
                    }

                    bool present = true;
                    string present_path = GLib.Path.build_filename (dir_path, "present");
                    if (GLib.FileUtils.test (present_path, GLib.FileTest.EXISTS)) {
                        try {
                            string present_str;
                            GLib.FileUtils.get_contents (present_path, out present_str);
                            present = present_str.strip () != "0";
                        } catch (GLib.Error e) {
                            present = true;
                        }
                    }

                    if (!present) {
                        continue;
                    }

                    bool looks_like_system_battery =
                        name.has_prefix ("BAT") || name.has_prefix ("CMB") ||
                        scope == "System";

                    if (!looks_like_system_battery) {
                        if (fallback == null && scope == "") {
                            fallback = name;
                        }

                        continue;
                    }

                    string capacity_path = GLib.Path.build_filename (dir_path, "capacity");
                    if (GLib.FileUtils.test (capacity_path, GLib.FileTest.EXISTS)) {
                        return name;
                    }
                }

                if (fallback != null) {
                    string capacity_path = GLib.Path.build_filename (
                        "/sys/class/power_supply", fallback, "capacity"
                    );

                    if (GLib.FileUtils.test (capacity_path, GLib.FileTest.EXISTS)) {
                        return fallback;
                    }
                }
            } catch (GLib.Error e) {
                warning ("Failed to find battery: %s", e.message);
            }

            return null;
        }

        public static int get_battery_level () {
            string? name = find_battery_name ();
            if (name == null) {
                return -1;
            }

            string capacity_path = GLib.Path.build_filename (
                "/sys/class/power_supply", name, "capacity"
            );
            try {
                string capacity_str;
                GLib.FileUtils.get_contents (capacity_path, out capacity_str);
                return int.parse (capacity_str.strip ());
            } catch (GLib.Error e) {
                warning ("Failed to get battery level: %s", e.message);
            }

            return -1;
        }

        public static bool is_battery_charging () {
            string status = get_battery_status ();
            return status == "Charging" || status == "Full";
        }

        public static string get_battery_status () {
            string? name = find_battery_name ();
            if (name == null) {
                return "";
            }

            string status_path = GLib.Path.build_filename (
                "/sys/class/power_supply", name, "status"
            );

            try {
                string status_str;
                GLib.FileUtils.get_contents (status_path, out status_str);
                return status_str.strip ();
            } catch (GLib.Error e) {
                warning ("Failed to get battery status: %s", e.message);
            }

            return "";
        }

        /* ------------------------------------------------------------------ */
        /*  Режимы питания                                                    */
        /* ------------------------------------------------------------------ */
        public static bool has_power_profiles () {
            return GLib.Environment.find_program_in_path ("powerprofilesctl") != null;
        }

        public static string get_power_profile () {
            if (!has_power_profiles ()) {
                return "";
            }

            try {
                string stdout_buf, stderr_buf;
                int status;
                GLib.Process.spawn_command_line_sync (
                    "powerprofilesctl get",
                    out stdout_buf,
                    out stderr_buf,
                    out status
                );

                if (status == 0 && stdout_buf != null) {
                    return stdout_buf.strip ();
                }
            } catch (GLib.Error e) {
                warning ("Failed to get power profile: %s", e.message);
            }

            return "";
        }

        public static bool set_power_profile (string profile) {
            if (!has_power_profiles ()) {
                return false;
            }

            return run_async ("powerprofilesctl set " + profile);
        }

        /* ------------------------------------------------------------------ */
        /*  Утилиты                                                           */
        /* ------------------------------------------------------------------ */
        public static bool run_async (string command) {
            try {
                GLib.Process.spawn_command_line_async (command);
                return true;
            } catch (GLib.Error e) {
                warning ("Failed to run '%s': %s", command, e.message);
                return false;
            }
        }

        public static bool run_sync (string command) {
            try {
                int status;
                GLib.Process.spawn_command_line_sync (command, null, null, out status);
                return status == 0;
            } catch (GLib.Error e) {
                warning ("Failed to run '%s': %s", command, e.message);
                return false;
            }
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
