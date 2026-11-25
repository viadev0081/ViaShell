using GLib;
using Json;

namespace ViaShell {

    /*
     * sway / swayfx через IPC (swaymsg).
     * Рабочие столы и отслеживание текущего режима (default, resizing …).
     * WorkspaceInfo берётся из hyprland.vala — общий тип для обоих композиторов.
     */
    public class Sway : GLib.Object {

        // Инициализатор статического поля Vala выполняет в class_init, а класс
        // Sway нигде не инстанцируется (все методы статические), поэтому
        // полагаться на него нельзя — храним null и подставляем значение
        // по умолчанию в геттере.
        private static string? current_mode = null;
        private static uint mode_poll_source = 0;
        private static uint mode_child_source = 0;
        private static GLib.IOChannel? io_channel;

        public static string get_current_mode () {
            return current_mode ?? "default";
        }

        public static bool is_available () {
            return GLib.Environment.find_program_in_path ("swaymsg") != null &&
                   GLib.Environment.get_variable ("SWAYSOCK") != null;
        }

        private static string? run (string args) {
            try {
                string stdout_buf, stderr_buf;
                int status;
                GLib.Process.spawn_command_line_sync (
                    "swaymsg -t " + args,
                    out stdout_buf,
                    out stderr_buf,
                    out status
                );
                if (status == 0 && stdout_buf != null) {
                    return stdout_buf;
                }
            } catch (GLib.Error e) {
                warning ("swaymsg failed: %s", e.message);
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

        /* ------------------------------------------------------------------ */
        /*  Режимы                                                            */
        /* ------------------------------------------------------------------ */
        public static void start_mode_watcher () {
            if (mode_poll_source != 0 || !is_available ()) {
                return;
            }

            int pid;
            int stdin_fd = -1;
            int stdout_fd;
            int stderr_fd = -1;

            try {
                if (!GLib.Process.spawn_async_with_pipes (
                        null,
                        new string [] { "swaymsg", "-m", "-t", "subscribe", "[\"mode\"]" },
                        null,
                        GLib.SpawnFlags.SEARCH_PATH | GLib.SpawnFlags.DO_NOT_REAP_CHILD,
                        null,
                        out pid,
                        out stdin_fd,
                        out stdout_fd,
                        out stderr_fd
                    )) {
                    return;
                }
            } catch (GLib.Error e) {
                warning ("Failed to start sway mode watcher: %s", e.message);
                return;
            }

            // stdin/stderr не нужны — закрываем, чтобы не течь дескрипторами.
            if (stdin_fd >= 0) {
                Posix.close (stdin_fd);
            }
            if (stderr_fd >= 0) {
                Posix.close (stderr_fd);
            }

            io_channel = new GLib.IOChannel.unix_new (stdout_fd);
            try {
                io_channel.set_flags (GLib.IOFlags.NONBLOCK);
            } catch (GLib.Error e) {
                warning ("Failed to configure sway mode channel: %s", e.message);
            }

            mode_poll_source = GLib.Timeout.add (300, poll_mode_line);

            // Если swaymsg неожиданно завершился — прекращаем polling.
            mode_child_source = GLib.ChildWatch.add (pid, (child_pid, status) => {
                GLib.Process.close_pid (child_pid);
                stop_mode_watcher ();
            });
        }

        private static bool poll_mode_line () {
            if (io_channel == null) {
                return false;
            }

            string? line;
            ulong length;
            ulong terminator_pos;
            GLib.IOStatus status;
            try {
                status = io_channel.read_line (
                    out line, out length, out terminator_pos
                );
            } catch (GLib.Error e) {
                return true;
            }

            if (status == GLib.IOStatus.NORMAL && line != null) {
                try {
                    var parser = new Json.Parser ();
                    parser.load_from_data (line);
                    var root = parser.get_root ();
                    if (root != null &&
                        root.get_node_type () == Json.NodeType.OBJECT) {
                        var obj = root.get_object ();
                        string change = obj.has_member ("change")
                            ? obj.get_string_member ("change") : "";
                        if (change != "" && change != current_mode) {
                            current_mode = change;
                        }
                    }
                } catch (GLib.Error e) {
                    warning ("Failed to parse sway mode event: %s", e.message);
                }
            }

            return true;
        }

        public static void stop_mode_watcher () {
            if (mode_poll_source != 0) {
                GLib.Source.remove (mode_poll_source);
                mode_poll_source = 0;
            }
            if (mode_child_source != 0) {
                GLib.Source.remove (mode_child_source);
                mode_child_source = 0;
            }
            io_channel = null;
        }

        /* ------------------------------------------------------------------ */
        /*  Рабочие столы                                                     */
        /* ------------------------------------------------------------------ */
        // Vala хранит ключи HashTable<int, …> как указатели (gpointer)(gintptr).
        // GLib.int_hash/int_equal ожидают настоящий указатель на int и падают
        // с SIGSEGV при разыменовании маленьких значений (1, 2, 3 …).
        // Поэтому используем собственные хеш/сравнение, совместимые с Vala.
        private static uint int_key_hash (int key) {
            return (uint) key;
        }

        private static bool int_key_equal (int a, int b) {
            return a == b;
        }

        private static Json.Array? get_array_member (Json.Object obj, string name) {
            if (!obj.has_member (name)) {
                return null;
            }

            var node = obj.get_member (name);
            if (node == null || node.get_node_type () != Json.NodeType.ARRAY) {
                return null;
            }

            return node.get_array ();
        }

        // Рекурсивно обходим дерево окон и считаем окна на каждом рабочем столе
        // (по полю num рабочего стола).
        private static void count_windows_in_node (
            Json.Object node,
            ref int current_ws,
            HashTable<int, int> counts
        ) {
            if (node.has_member ("type")) {
                string type = node.get_string_member ("type");
                if (type == "workspace") {
                    current_ws = node.has_member ("num")
                        ? (int) node.get_int_member ("num") : 0;
                }
            }

            if (node.has_member ("window")) {
                var window_node = node.get_member ("window");
                if (
                    window_node != null &&
                    window_node.get_node_type () == Json.NodeType.VALUE &&
                    window_node.get_value_type () == typeof (int64)
                ) {
                    int64 window_id = window_node.get_int ();
                    if (window_id != 0 && current_ws != 0) {
                        int have = counts.contains (current_ws) ? counts[current_ws] : 0;
                        counts[current_ws] = have + 1;
                    }
                }
            }

            var array = get_array_member (node, "nodes");
            if (array != null) {
                for (uint i = 0; i < array.get_length (); i++) {
                    var child = array.get_element (i);
                    if (child.get_node_type () == Json.NodeType.OBJECT) {
                        count_windows_in_node (
                            child.get_object (), ref current_ws, counts
                        );
                    }
                }
            }
        }

        private static HashTable<int, int> window_counts () {
            var counts = new HashTable<int, int> (int_key_hash, int_key_equal);
            string? data = run ("get_tree");
            if (data == null) {
                return counts;
            }

            try {
                var parser = new Json.Parser ();
                parser.load_from_data (data);
                var root = parser.get_root ();
                if (root == null ||
                    root.get_node_type () != Json.NodeType.OBJECT) {
                    return counts;
                }

                int current_ws = 0;
                var tree = root.get_object ();
                var array = get_array_member (tree, "nodes");
                if (array != null) {
                    for (uint i = 0; i < array.get_length (); i++) {
                        var node = array.get_element (i);
                        if (node.get_node_type () == Json.NodeType.OBJECT) {
                            count_windows_in_node (
                                node.get_object (), ref current_ws, counts
                            );
                        }
                    }
                }
            } catch (GLib.Error e) {
                warning ("Failed to parse sway tree: %s", e.message);
            }

            return counts;
        }

        public static WorkspaceInfo[] get_workspaces (string? monitor_name, int base_count = 10) {
            WorkspaceInfo[] result = {};
            string? data = run ("get_workspaces");
            if (data == null) {
                return result;
            }

            var counts = window_counts ();

            try {
                var parser = new Json.Parser ();
                parser.load_from_data (data);
                var root = parser.get_root ();
                if (root == null ||
                    root.get_node_type () != Json.NodeType.ARRAY) {
                    return result;
                }

                var array = root.get_array ();
                for (uint i = 0; i < array.get_length (); i++) {
                    var node = array.get_element (i);
                    if (node.get_node_type () != Json.NodeType.OBJECT) {
                        continue;
                    }

                    var obj = node.get_object ();

                    string output = obj.has_member ("output")
                        ? obj.get_string_member ("output") : "";

                    if (monitor_name != null && monitor_name != "" && output != monitor_name) {
                        continue;
                    }

                    int id = obj.has_member ("id")
                        ? (int) obj.get_int_member ("id") : 0;
                    int num = obj.has_member ("num")
                        ? (int) obj.get_int_member ("num") : id;
                    int idx = num != 0 ? num : id;

                    string name = obj.has_member ("name")
                        ? obj.get_string_member ("name") : "%d".printf (id);

                    int windows = counts.contains (num) ? counts[num] : 0;

                    bool active = obj.has_member ("focused")
                        ? obj.get_boolean_member ("focused") : false;

                    var ws = new WorkspaceInfo (id, name, output, windows);
                    ws.idx = idx;
                    ws.active = active;
                    result += ws;
                }
            } catch (GLib.Error e) {
                warning ("Failed to parse sway workspaces: %s", e.message);
            }

            sort_by_idx (result);
            return result;
        }

        private static void sort_by_idx (WorkspaceInfo[] list) {
            for (int i = 1; i < list.length; i++) {
                var item = list[i];
                int j = i - 1;
                while (j >= 0 && list[j].idx > item.idx) {
                    list[j + 1] = list[j];
                    j--;
                }
                list[j + 1] = item;
            }
        }

        public static int get_active_workspace_id (string? monitor_name) {
            foreach (var ws in get_workspaces (monitor_name)) {
                if (ws.active) {
                    return ws.idx;
                }
            }
            return 1;
        }

        public static void focus_workspace_on (string? monitor_name, int idx) {
            if (monitor_name != null && monitor_name != "") {
                // Ищем рабочий стол с таким номером именно на своём мониторе,
                // иначе на другом выходе может быть стол с тем же номером.
                foreach (var ws in get_workspaces (monitor_name)) {
                    if (ws.idx == idx) {
                        run_cmd (
                            "swaymsg workspace %s".printf (GLib.Shell.quote (ws.name))
                        );
                        return;
                    }
                }
            }
            run_cmd ("swaymsg workspace number %d".printf (idx));
        }

        public static void focus_workspace (int id) {
            run_cmd ("swaymsg workspace number %d".printf (id));
        }

        public static void focus_relative (int delta) {
            if (delta < 0) {
                run_cmd ("swaymsg workspace prev");
            } else if (delta > 0) {
                run_cmd ("swaymsg workspace next");
            }
        }
    }
}
