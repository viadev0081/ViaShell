namespace ViaShell {

    public class MediaInfo : GLib.Object {
        public string status  { get; set; default = ""; }
        public string artist  { get; set; default = ""; }
        public string title   { get; set; default = ""; }
        public string album   { get; set; default = ""; }
        public string art_url { get; set; default = ""; }

        public bool available { get { return status != ""; } }
        public bool playing   { get { return status == "Playing"; } }
    }

    public class MediaService : GLib.Object {

        public signal void changed ();

        private const string METADATA_FORMAT =
            "{{status}}\t{{artist}}\t{{title}}\t{{album}}\t{{mpris:artUrl}}";

        private MediaInfo? current = null;
        private string last_raw = "";
        private uint timer_id = 0;

        public MediaInfo? info {
            get { return current; }
        }

        public MediaService () {
            update ();
            timer_id = GLib.Timeout.add_seconds (2, () => {
                update ();
                return GLib.Source.CONTINUE;
            });
        }

        public void refresh () {
            update ();
        }

        public void play_pause () {
            SystemInfo.run_async ("playerctl play-pause");
            schedule_refresh ();
        }

        public void next () {
            SystemInfo.run_async ("playerctl next");
            schedule_refresh ();
        }

        public void previous () {
            SystemInfo.run_async ("playerctl previous");
            schedule_refresh ();
        }

        private void schedule_refresh () {
            GLib.Timeout.add (180, () => {
                update ();
                return GLib.Source.REMOVE;
            });
        }

        private void update () {
            if (GLib.Environment.find_program_in_path ("playerctl") == null) {
                if (last_raw != "__none__") {
                    last_raw = "__none__";
                    current = null;
                    changed ();
                }

                return;
            }

            string? raw = read_metadata ();

            if (raw == null) {
                raw = "";
            }

            if (raw == last_raw) {
                return;
            }

            last_raw = raw;

            if (raw.strip () == "") {
                current = null;
                changed ();
                return;
            }

            var parts = raw.split ("\t");
            var media = new MediaInfo ();
            media.status = get_part (parts, 0);
            media.artist = get_part (parts, 1);
            media.title = get_part (parts, 2);
            media.album = get_part (parts, 3);
            media.art_url = get_part (parts, 4);

            if (media.title == "" && media.artist == "") {
                current = null;
            }
            else {
                current = media;
            }

            changed ();
        }

        private string? read_metadata () {
            try {
                string stdout_buf, stderr_buf;
                int status;
                GLib.Process.spawn_command_line_sync (
                    "playerctl metadata --format '" + METADATA_FORMAT + "'",
                    out stdout_buf,
                    out stderr_buf,
                    out status
                );

                if (status == 0 && stdout_buf != null) {
                    return stdout_buf.strip ();
                }
            } catch (GLib.Error e) {
                // Нет playerctl / плеера
            }
            return null;
        }

        private static string get_part (string[] parts, int index) {
            if (index >= parts.length) {
                return "";
            }

            return parts[index].strip ();
        }
    }
}
