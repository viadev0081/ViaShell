namespace ViaShell {

    public class WorkspaceInfo : GLib.Object {
        public int id         { get; set; }
        public int idx        { get; set; }
        public string name    { get; set; }
        public string monitor { get; set; }
        public int windows    { get; set; }

        public bool occupied {
            get {
                return windows > 0;
            }
        }

        public bool active { get; set; }

        public WorkspaceInfo (
            int id,
            string name,
            string monitor,
            int windows
        ) {
            this.id = id;
            this.idx = id;
            this.name = name;
            this.monitor = monitor;
            this.windows = windows;
        }
    }

    /*
     * Рабочие столы и команды композитора.
     * Поддерживаются Hyprland (hyprctl) и niri (niri msg).
     */
    public class Hyprland : GLib.Object {

        public static bool is_available () {
            return is_hyprland_available () || is_niri_available ();
        }

        public static bool is_hyprland_available () {
            return GLib.Environment.find_program_in_path ("hyprctl") != null &&
                   GLib.Environment.get_variable ("HYPRLAND_INSTANCE_SIGNATURE") != null;
        }

        public static bool is_niri_available () {
            return GLib.Environment.find_program_in_path ("niri") != null &&
                   GLib.Environment.get_variable ("NIRI_SOCKET") != null;
        }

        public static string? fetch (string args) {
            if (!is_hyprland_available ()) {
                return null;
            }

            try {
                string stdout_buf, stderr_buf;
                int status;

                GLib.Process.spawn_command_line_sync (
                    "hyprctl -j " + args,
                    out stdout_buf,
                    out stderr_buf,
                    out status
                );

                if (status == 0 && stdout_buf != null) {
                    return stdout_buf;
                }

            } catch (GLib.Error e) {
                warning ("hyprctl failed: %s", e.message);
            }

            return null;
        }

        private static string? niri_fetch (string args) {
            if (!is_niri_available ()) {
                return null;
            }

            try {
                string stdout_buf, stderr_buf;
                int status;

                GLib.Process.spawn_command_line_sync (
                    "niri msg --json " + args,
                    out stdout_buf,
                    out stderr_buf,
                    out status
                );

                if (status == 0 && stdout_buf != null) {
                    return stdout_buf;
                }
            } catch (GLib.Error e) {
                warning ("niri msg failed: %s", e.message);
            }

            return null;
        }

        /* ------------------------------------------------------------------ */
        /*  niri                                                              */
        /* ------------------------------------------------------------------ */
        private static WorkspaceInfo[] get_niri_workspaces (string? monitor_name) {
            WorkspaceInfo[] result = {};
            string? data = niri_fetch ("workspaces");
            if (data == null) {
                return result;
            }

            try {
                var parser = new Json.Parser ();
                parser.load_from_data (data);
                var root = parser.get_root ();

                if (
                    root == null ||
                    root.get_node_type () != Json.NodeType.ARRAY
                ) {
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

                    if (
                        monitor_name != null &&
                        monitor_name != "" &&
                        output != monitor_name
                    ) {
                        continue;
                    }

                    int id = obj.has_member ("id")
                        ? (int) obj.get_int_member ("id") : 0;

                    int idx = obj.has_member ("idx")
                        ? (int) obj.get_int_member ("idx") : id;

                    string name = "";
                    if (obj.has_member ("name")) {
                        var name_node = obj.get_member ("name");

                        if (
                            name_node != null &&
                            name_node.get_node_type () == Json.NodeType.VALUE &&
                            name_node.get_value_type () == typeof (string)
                        ) {
                            var value = name_node.get_string ();
                            if (value != null) {
                                name = value;
                            }
                        }
                    }

                    int windows = 0;
                    if (obj.has_member ("active_window_id")) {
                        var window_node = obj.get_member ("active_window_id");

                        if (
                            window_node != null &&
                            window_node.get_node_type () == Json.NodeType.VALUE &&
                            window_node.get_value_type () == typeof (int64)
                        ) {
                            windows = 1;
                        }
                    }

                    bool active = obj.has_member ("is_active")
                        ? obj.get_boolean_member ("is_active") : false;

                    var ws = new WorkspaceInfo (id, name, output, windows);
                    ws.idx = idx;
                    ws.active = active;
                    result += ws;
                }
            } catch (GLib.Error e) {
                warning ("Failed to parse niri workspaces: %s", e.message);
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

        /* ------------------------------------------------------------------ */
        /*  Hyprland                                                          */
        /* ------------------------------------------------------------------ */
        public static int get_active_workspace_id (string? monitor_name) {
            if (is_niri_available ()) {
                foreach (var ws in get_niri_workspaces (monitor_name)) {
                    if (ws.active) {
                        return ws.idx;
                    }
                }

                return 1;
            }

            string? data = fetch ("monitors");
            if (data != null) {
                try {
                    var parser = new Json.Parser ();
                    parser.load_from_data (data);
                    var root = parser.get_root ();

                    if (root != null && root.get_node_type () == Json.NodeType.ARRAY) {
                        var array = root.get_array ();
                        for (uint i = 0; i < array.get_length (); i++) {
                            var node = array.get_element (i);

                            if (node.get_node_type () != Json.NodeType.OBJECT) {
                                continue;
                            }

                            var obj = node.get_object ();
                            string name = obj.has_member ("name")
                                ? obj.get_string_member ("name") : "";

                            if (
                                monitor_name != null &&
                                monitor_name != "" &&
                                name != monitor_name
                            ) {
                                continue;
                            }

                            if (!obj.has_member ("activeWorkspace")) {
                                continue;
                            }

                            var ws_node = obj.get_member ("activeWorkspace");

                            if (
                                ws_node == null ||
                                ws_node.get_node_type () != Json.NodeType.OBJECT
                            ) {
                                continue;
                            }

                            var ws_obj = ws_node.get_object ();
                            if (ws_obj.has_member ("id")) {
                                return (int) ws_obj.get_int_member ("id");
                            }
                        }
                    }
                } catch (GLib.Error e) {
                    warning ("Failed to parse monitors: %s", e.message);
                }
            }

            // Резервный вариант — активный рабочий стол текущего монитора
            data = fetch ("activeworkspace");
            if (data != null) {
                try {
                    var parser = new Json.Parser ();
                    parser.load_from_data (data);
                    var root = parser.get_root ();
                    if (root != null &&
                        root.get_node_type () == Json.NodeType.OBJECT &&
                        root.get_object ().has_member ("id")) {
                        return (int) root.get_object ().get_int_member ("id");
                    }
                } catch (GLib.Error e) {
                    warning ("Failed to parse active workspace: %s", e.message);
                }
            }

            return 1;
        }

        public static WorkspaceInfo[] get_workspaces (string? monitor_name, int base_count = 10) {
            if (is_niri_available ()) {
                return get_niri_workspaces (monitor_name);
            }

            WorkspaceInfo[] existing = {};

            string? data = fetch ("workspaces");
            if (data != null) {
                try {
                    var parser = new Json.Parser ();
                    parser.load_from_data (data);
                    var root = parser.get_root ();

                    if (root != null && root.get_node_type () == Json.NodeType.ARRAY) {
                        var array = root.get_array ();

                        for (uint i = 0; i < array.get_length (); i++) {
                            var node = array.get_element (i);
                            if (node.get_node_type () != Json.NodeType.OBJECT) {
                                continue;
                            }

                            var obj = node.get_object ();

                            if (!obj.has_member ("id")) {
                                continue;
                            }

                            int id = (int) obj.get_int_member ("id");

                            if (id < 1) {
                                continue;
                            }

                            string name = obj.has_member ("name")
                                ? obj.get_string_member ("name") : "%d".printf (id);

                            string monitor = obj.has_member ("monitor")
                                ? obj.get_string_member ("monitor") : "";

                            int windows = obj.has_member ("windows")
                                ? (int) obj.get_int_member ("windows") : 0;

                            existing += new WorkspaceInfo (id, name, monitor, windows);
                        }
                    }
                } catch (GLib.Error e) {
                    warning ("Failed to parse workspaces: %s", e.message);
                }
            }

            int active_id = get_active_workspace_id (monitor_name);

            int max_id = base_count;
            foreach (var ws in existing) {
                if (ws.id > max_id && (ws.windows > 0 || ws.id == active_id)) {
                    max_id = ws.id;
                }
            }

            if (active_id > max_id) {
                max_id = active_id;
            }

            if (max_id > 30) {
                max_id = 30;
            }

            WorkspaceInfo[] result = {};
            for (int id = 1; id <= max_id; id++) {
                WorkspaceInfo? found = null;

                foreach (var ws in existing) {
                    if (ws.id == id) {
                        found = ws;
                        break;
                    }
                }

                if (found != null) {
                    found.active = (id == active_id);
                    result += found;
                }
                else {
                    var ws = new WorkspaceInfo (
                        id,
                        "%d".printf (id),
                        monitor_name != null ? monitor_name : "",
                        0
                    );

                    ws.active = (id == active_id);
                    result += ws;
                }
            }

            return result;
        }

        /* ------------------------------------------------------------------ */
        /*  Команды                                                           */
        /* ------------------------------------------------------------------ */
        public static void dispatch (string command) {
            if (!is_hyprland_available ()) {
                return;
            }

            SystemInfo.run_async ("hyprctl dispatch " + command);
        }

        public static void focus_workspace (int id) {
            if (is_niri_available ()) {
                SystemInfo.run_async ("niri msg action focus-workspace %d".printf (id));
                return;
            }
            dispatch ("workspace %d".printf (id));
        }

        public static void focus_workspace_on (string? monitor_name, int idx) {
            if (is_niri_available ()) {
                if (monitor_name != null && monitor_name != "") {
                    // Сначала синхронно переключаем монитор, иначе focus-workspace
                    // может сработать на другом выходе с тем же индексом
                    SystemInfo.run_sync (
                        "niri msg action focus-monitor %s".printf (monitor_name)
                    );
                }

                SystemInfo.run_async ("niri msg action focus-workspace %d".printf (idx));
                return;
            }
            focus_workspace (idx);
        }

        public static void focus_relative (int delta) {
            if (is_niri_available ()) {
                if (delta < 0) {
                    SystemInfo.run_async ("niri msg action focus-workspace-up");
                }
                else if (delta > 0) {
                    SystemInfo.run_async ("niri msg action focus-workspace-down");
                }

                return;
            }
            dispatch ("workspace r%s%d".printf (delta >= 0 ? "+" : "-", delta.abs ()));
        }
    }
}
