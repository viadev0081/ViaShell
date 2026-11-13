namespace ViaShell {

    public class MessageInfo : GLib.Object {
        public string app      { get; set; default = ""; }
        public string summary  { get; set; default = ""; }
        public string body     { get; set; default = ""; }
        public string urgency  { get; set; default = ""; }
        public int64 timestamp { get; set; default = 0; }
    }

    public class NotificationService : GLib.Object {

        public signal void changed ();

        private MessageInfo[] messages = {};
        private string signature = "";
        private uint timer_id = 0;

        public NotificationService () {
            refresh ();
            timer_id = GLib.Timeout.add_seconds (4, () => {
                refresh ();
                return GLib.Source.CONTINUE;
            });
        }

        public MessageInfo[] get_messages () {
            return messages;
        }

        public void refresh () {
            GLib.GenericArray<MessageInfo> list = new GLib.GenericArray<MessageInfo> ();
            bool parsed = false;

            if (GLib.Environment.find_program_in_path ("swaync-client") != null) {
                parsed = parse_command ("swaync-client -j", list);
            }
            else if (GLib.Environment.find_program_in_path ("dunstctl") != null) {
                parsed = parse_command ("dunstctl history", list);
            }
            else if (GLib.Environment.find_program_in_path ("makoctl") != null) {
                parsed = parse_command ("makoctl history", list);
            }

            MessageInfo[] result = {};
            for (uint i = 0; i < list.length; i++) {
                result += list[i];
            }
            sort_messages (result);

            string new_signature = "";
            foreach (var msg in result) {
                new_signature += "%s|%s|%s|%lld;".printf (
                    msg.app, msg.summary, msg.body, msg.timestamp
                );
            }

            if (new_signature == signature) {
                return;
            }

            signature = new_signature;
            messages = result;
            changed ();
        }

        private bool parse_command (string command, GLib.GenericArray<MessageInfo> list) {
            try {
                string stdout_buf, stderr_buf;
                int status;
                GLib.Process.spawn_command_line_sync (
                    command,
                    out stdout_buf,
                    out stderr_buf,
                    out status
                );

                if (
                    status != 0 ||
                    stdout_buf == null ||
                    stdout_buf.strip () == ""
                ) {
                    return false;
                }

                var parser = new Json.Parser ();
                parser.load_from_data (stdout_buf);
                var root = parser.get_root ();
                if (root == null) return false;
                walk_node (root, list);
                return true;
            } catch (GLib.Error e) {
                return false;
            }
        }

        private void walk_node (Json.Node node, GLib.GenericArray<MessageInfo> list) {
            if (node.get_node_type () == Json.NodeType.ARRAY) {
                var array = node.get_array ();
                for (uint i = 0; i < array.get_length (); i++) {
                    walk_node (array.get_element (i), list);
                }

                return;
            }

            if (node.get_node_type () != Json.NodeType.OBJECT) {
                return;
            }

            var obj = node.get_object ();
            if (obj.has_member ("summary") || obj.has_member ("body") ||
                obj.has_member ("title") || obj.has_member ("message")) {
                var msg = new MessageInfo ();
                msg.app = member_string (obj, "appname", "appName", "app_name", "app");
                msg.summary = member_string (obj, "summary", "title", "", "");
                msg.body = member_string (obj, "body", "message", "", "");
                msg.urgency = member_string (obj, "urgency", "", "", "");
                msg.timestamp = member_time (obj);

                if (msg.summary != "" || msg.body != "") {
                    list.add (msg);
                }

                return;
            }

            var members = obj.get_members ();
            if (members != null) {
                foreach (var name in members) {
                    if (name == null) {
                        continue;
                    }

                    var child = obj.get_member (name);
                    if (child != null) {
                        walk_node (child, list);
                    }
                }
            }
        }

        private static string member_string (
            Json.Object obj,
            string a,
            string b,
            string c,
            string d
        ) {
            string[] keys = { a, b, c, d };
            foreach (var key in keys) {
                if (key == "" || !obj.has_member (key)) {
                    continue;
                }

                var node = obj.get_member (key);
                if (node == null) {
                    continue;
                }

                if (node.get_node_type () != Json.NodeType.VALUE) {
                    continue;
                }

                var vtype = node.get_value_type ();
                if (vtype == typeof (string)) {
                    var value = node.get_string ();
                    if (value != null) {
                        return value.strip ();
                    }
                }
                else if (vtype == typeof (int64)) {
                    return "%lld".printf (node.get_value ().get_int64 ());
                }
                else if (vtype == typeof (double)) {
                    return "%.0f".printf (node.get_value ().get_double ());
                }
            }

            return "";
        }

        private static int64 member_time (Json.Object obj) {
            string[] keys = {
                "timestamp",
                "time",
                "created_at",
                "date"
            };

            foreach (var key in keys) {
                if (!obj.has_member (key)) {
                    continue;
                }

                var node = obj.get_member (key);
                if (
                    node == null ||
                    node.get_node_type () != Json.NodeType.VALUE
                ) {
                    continue;
                }

                var vtype = node.get_value_type ();
                int64 value = 0;
                if (vtype == typeof (int64)) {
                    value = node.get_value ().get_int64 ();
                }
                else if (vtype == typeof (double)) {
                    value = (int64) node.get_value ().get_double ();
                }
                else if (vtype == typeof (string)) {
                    var text = node.get_string ();
                    if (text != null) {
                        value = int64.parse (text);
                    }
                }

                if (value > 0) {
                    // Dunst и некоторые другие отдают микросекунды
                    if (value > 100000000000000LL) {
                        value = value / 1000000;
                    }
                    else if (value > 100000000000LL) {
                        value = value / 1000;
                    }

                    return value;
                }
            }

            return 0;
        }

        private static void sort_messages (MessageInfo[] list) {
            for (int i = 1; i < list.length; i++) {
                var item = list[i];
                int j = i - 1;
                while (j >= 0 && list[j].timestamp < item.timestamp) {
                    list[j + 1] = list[j];
                    j--;
                }

                list[j + 1] = item;
            }
        }
    }
}
