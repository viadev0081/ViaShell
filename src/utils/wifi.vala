using GLib;

namespace ViaShell {

    public class WifiInfo : GLib.Object {
        public string ssid     { get; set; }
        public int    signal   { get; set; }
        public string security { get; set; }
    }

    /*
     * Wi-Fi через nmcli (NetworkManager).
     * Даёт имя сети, уровень сигнала, наличие интернета и
     * возможность включить/выключить радио.
     */
    public class Wifi : GLib.Object {

        public static bool is_available () {
            return GLib.Environment.find_program_in_path ("nmcli") != null;
        }

        private static string? run (string args) {
            try {
                string stdout_buf, stderr_buf;
                int status;
                GLib.Process.spawn_command_line_sync (
                    "nmcli " + args,
                    out stdout_buf,
                    out stderr_buf,
                    out status
                );
                if (status == 0 && stdout_buf != null) {
                    return stdout_buf;
                }
            } catch (GLib.Error e) {
                warning ("nmcli failed: %s", e.message);
            }
            return null;
        }

        public static void run_cmd (string command) {
            try {
                GLib.Process.spawn_command_line_async (command);
            } catch (GLib.Error e) {
                warning ("Failed to run '%s': %s", command, e.message);
            }
        }

        public static bool radio_enabled () {
            string? data = run ("-t radio wifi");
            if (data == null) {
                return false;
            }
            return data.strip () == "enabled";
        }

        public static void set_radio (bool on) {
            run_cmd ("nmcli radio wifi %s".printf (on ? "on" : "off"));
        }

        public static WifiInfo? active_connection () {
            string? data = run ("-t -f NAME,TYPE,STATE connection show --active");
            if (data == null) {
                return null;
            }

            foreach (var line in data.split ("\n")) {
                var parts = line.split (":");
                if (parts.length < 3) {
                    continue;
                }
                string type = parts[1].strip ();
                string state = parts[2].strip ();
                if (type == "wifi" && (state == "activated" || state == "activate")) {
                    var info = new WifiInfo ();
                    info.ssid = parts[0].strip ();
                    info.signal = active_signal ();
                    return info;
                }
            }

            return null;
        }

        public static int active_signal () {
            // Без пересканирования, чтобы не подвешивать интерфейс.
            string? data = run ("-t -f ACTIVE,SSID,SIGNAL,SECURITY device wifi list --rescan no");
            if (data == null) {
                return -1;
            }

            foreach (var line in data.split ("\n")) {
                var parts = line.split (":");
                if (parts.length < 4) {
                    continue;
                }
                if (parts[0].strip () == "yes") {
                    int signal = -1;
                    try {
                        signal = int.parse (parts[2].strip ());
                    } catch {}
                    return signal;
                }
            }

            return -1;
        }

        public static string connectivity () {
            string? data = run ("-t connectivity check");
            if (data == null) {
                return "unknown";
            }
            return data.strip ();
        }

        public static bool has_internet () {
            return connectivity () == "full";
        }
    }
}
