using Gtk;

namespace ViaShell {

    public class LauncherMenu : Gtk.Popover {

        private Distro distro;
        private MediaService media;
        private NotificationService notifications;

        private string user_name;
        private string display_name;

        private Gtk.Label media_title;
        private Gtk.Label media_artist;
        private Gtk.Button play_button;
        private Gtk.Button prev_button;
        private Gtk.Button next_button;
        private Gtk.Box media_art;
        private Gtk.Label media_art_fallback;

        private Gtk.Box messages_box;
        private Gtk.Label message_count;
        private Gtk.ScrolledWindow messages_scroll;

        public LauncherMenu (
            Distro distro,
            MediaService media,
            NotificationService notifications
        ) {
            this.distro = distro;
            this.media = media;
            this.notifications = notifications;

            string? user = GLib.Environment.get_user_name ();
            user_name = user != null ? user : "user";

            string? real = GLib.Environment.get_real_name ();
            if (real != null && real.strip () != "" && real.strip () != "Unknown") {
                display_name = real.strip ();
            }
            else {
                display_name = user_name;
            }

            this.add_css_class ("vs-popover");
            this.add_css_class ("launcher-popover");
            this.set_has_arrow (false);
            this.set_position (Gtk.PositionType.RIGHT);

            var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
            root.add_css_class ("menu-content");
            root.set_size_request (400, 560);

            root.append (build_header ());
            root.append (build_media_card ());
            root.append (build_messages ());
            root.append (build_power_grid ());

            this.set_child (root);

            this.show.connect (() => {
                media.refresh ();
                notifications.refresh ();
                update_media ();
                refresh_messages ();
            });

            media.changed.connect (() => {
                update_media ();
            });

            notifications.changed.connect (() => {
                refresh_messages ();
            });

            update_media ();
            refresh_messages ();
        }

        /* ------------------------------------------------------------------ */
        /*  Шапка                                                             */
        /* ------------------------------------------------------------------ */
        private Gtk.Widget build_header () {
            var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 14);
            header.add_css_class ("menu-header");

            header.append (build_avatar ());

            var info = new Gtk.Box (Gtk.Orientation.VERTICAL, 3);
            info.set_hexpand (true);
            info.set_valign (Gtk.Align.CENTER);

            var name_label = new Gtk.Label (display_name);
            name_label.add_css_class ("user-name");
            name_label.set_halign (Gtk.Align.START);
            name_label.set_ellipsize (Pango.EllipsizeMode.END);

            var host_label = new Gtk.Label ("@" + GLib.Environment.get_host_name ());
            host_label.add_css_class ("user-host");
            host_label.set_halign (Gtk.Align.START);

            var chip = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            chip.add_css_class ("distro-chip");
            chip.set_halign (Gtk.Align.START);
            chip.set_tooltip_text (distro.name);

            var distro_icon = new Gtk.Label ("");
            distro_icon.add_css_class ("distro-glyph");

            distro_icon.set_markup (
                "<span foreground='%s'>%s</span>".printf (
                    distro.colour, GLib.Markup.escape_text (Icons.get (distro.glyph))
                )
            );

            var distro_name = new Gtk.Label (distro.name);
            distro_name.add_css_class ("distro-name");
            distro_name.set_ellipsize (Pango.EllipsizeMode.END);

            chip.append (distro_icon);
            chip.append (distro_name);

            info.append (name_label);
            info.append (host_label);
            info.append (chip);

            header.append (info);
            return header;
        }

        private Gtk.Widget build_avatar () {
            var avatar = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            avatar.add_css_class ("avatar");
            avatar.set_size_request (58, 58);
            avatar.set_halign (Gtk.Align.CENTER);
            avatar.set_valign (Gtk.Align.CENTER);

            string? path = find_avatar_path ();
            if (path != null) {
                try {
                    string uri = GLib.Filename.to_uri (path);
                    var provider = new Gtk.CssProvider ();
                    string css = ".avatar-image { background-image: url(\"%s\"); background-size: cover; background-position: center; }".printf (uri);
                    provider.load_from_data (css.data);
                    avatar.add_css_class ("avatar-image");
                    avatar.get_style_context ().add_provider (
                        provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                    );
                } catch (GLib.Error e) {
                    add_avatar_initial (avatar);
                }
            }
            else {
                add_avatar_initial (avatar);
            }

            return avatar;
        }

        private void add_avatar_initial (Gtk.Box avatar) {
            avatar.add_css_class ("avatar-fallback");
            string initial = display_name.length > 0
                ? display_name.substring (0, 1).up ()
                : "?";

            var label = new Gtk.Label (initial);
            label.add_css_class ("avatar-initial");
            label.set_halign (Gtk.Align.CENTER);
            label.set_valign (Gtk.Align.CENTER);
            avatar.append (label);
        }

        private static string? find_avatar_path () {
            string home = GLib.Environment.get_home_dir ();
            string user = GLib.Environment.get_user_name ();
            string[] candidates = {
                GLib.Path.build_filename (home, ".face"),
                GLib.Path.build_filename (home, ".face.icon"),
                GLib.Path.build_filename (home, ".config", "viashell", "avatar"),
                GLib.Path.build_filename (home, ".config", "viashell", "avatar.png"),
                GLib.Path.build_filename (home, ".local", "share", "icons", "avatar.png"),
                GLib.Path.build_filename ("/var/lib/AccountsService/icons", user),
            };

            foreach (var path in candidates) {
                if (GLib.FileUtils.test (path, GLib.FileTest.IS_REGULAR)) {
                    return path;
                }
            }
            return null;
        }

        /* ------------------------------------------------------------------ */
        /*  Медиа                                                             */
        /* ------------------------------------------------------------------ */
        private Gtk.Widget build_media_card () {
            var card = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            card.add_css_class ("media-card");

            media_art = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            media_art.add_css_class ("media-art");
            media_art.set_size_request (54, 54);
            media_art.set_overflow (Gtk.Overflow.HIDDEN);
            media_art.set_valign (Gtk.Align.CENTER);

            media_art_fallback = new Gtk.Label (Icons.get (Icons.MUSIC));
            media_art_fallback.add_css_class ("media-art-fallback");
            media_art_fallback.set_halign (Gtk.Align.CENTER);
            media_art_fallback.set_valign (Gtk.Align.CENTER);
            media_art.append (media_art_fallback);

            var info = new Gtk.Box (Gtk.Orientation.VERTICAL, 3);
            info.set_hexpand (true);
            info.set_valign (Gtk.Align.CENTER);

            media_title = new Gtk.Label ("Ничего не играет");
            media_title.add_css_class ("media-title");
            media_title.set_halign (Gtk.Align.START);
            media_title.set_ellipsize (Pango.EllipsizeMode.END);
            media_title.set_max_width_chars (28);

            media_artist = new Gtk.Label ("Запустите плеер");
            media_artist.add_css_class ("media-artist");
            media_artist.set_halign (Gtk.Align.START);
            media_artist.set_ellipsize (Pango.EllipsizeMode.END);
            media_artist.set_max_width_chars (32);

            var controls = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            controls.add_css_class ("media-controls");

            var media_service = this.media;
            prev_button = build_media_button (Icons.PREVIOUS);
            prev_button.clicked.connect (() => {
                media_service.previous ();
            });

            play_button = build_media_button (Icons.PLAY);
            play_button.clicked.connect (() => {
                media_service.play_pause ();
            });

            next_button = build_media_button (Icons.NEXT);
            next_button.clicked.connect (() => {
                media_service.next ();
            });

            controls.append (prev_button);
            controls.append (play_button);
            controls.append (next_button);

            info.append (media_title);
            info.append (media_artist);
            info.append (controls);

            card.append (media_art);
            card.append (info);
            return card;
        }

        private Gtk.Button build_media_button (uint32 icon) {
            var button = new Gtk.Button ();
            button.add_css_class ("media-button");
            button.add_css_class ("flat");
            button.set_label (Icons.get (icon));
            button.set_tooltip_text ("Управление воспроизведением");
            button.set_size_request (30, 26);
            return button;
        }

        private void update_media () {
            var info = media.info;
            bool available = info != null && info.available;

            if (!available) {
                media_title.set_text ("Ничего не играет");
                media_artist.set_text ("Запустите плеер");
                play_button.set_label (Icons.get (Icons.PLAY));
                prev_button.set_sensitive (false);
                play_button.set_sensitive (false);
                next_button.set_sensitive (false);
                set_media_art (null);
                return;
            }

            media_title.set_text (info.title != "" ? info.title : "Без названия");
            string subtitle = info.artist;
            if (subtitle == "" && info.album != "") {
                subtitle = info.album;
            }
            if (subtitle == "") {
                subtitle = info.status == "Playing" ? "Воспроизведение" : "Пауза";
            }

            media_artist.set_text (subtitle);
            play_button.set_label (Icons.get (info.playing ? Icons.PAUSE : Icons.PLAY));
            prev_button.set_sensitive (true);
            play_button.set_sensitive (true);
            next_button.set_sensitive (true);

            set_media_art (info.art_url);
        }

        private void set_media_art (string? art_url) {
            if (art_url == null || !art_url.has_prefix ("file://")) {
                media_art.remove_css_class ("media-art-has-image");
                media_art_fallback.set_visible (true);
                return;
            }

            try {
                string path = GLib.Filename.from_uri (art_url, null);
                if (!GLib.FileUtils.test (path, GLib.FileTest.IS_REGULAR)) {
                    media_art.remove_css_class ("media-art-has-image");
                    media_art_fallback.set_visible (true);
                    return;
                }

                string uri = GLib.Filename.to_uri (path);
                var provider = new Gtk.CssProvider ();
                string css = ".media-art-has-image { background-image: url(\"%s\"); background-size: cover; background-position: center; }".printf (uri);
                provider.load_from_data (css.data);
                media_art.get_style_context ().add_provider (
                    provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                );

                media_art.add_css_class ("media-art-has-image");
                media_art_fallback.set_visible (false);
            } catch (GLib.Error e) {
                media_art.remove_css_class ("media-art-has-image");
                media_art_fallback.set_visible (true);
            }
        }

        /* ------------------------------------------------------------------ */
        /*  Сообщения                                                         */
        /* ------------------------------------------------------------------ */
        private Gtk.Widget build_messages () {
            var section = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            section.add_css_class ("messages-section");
            section.set_vexpand (true);

            var heading = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            heading.add_css_class ("messages-heading");

            var icon = new Gtk.Label (Icons.get (Icons.BELL));
            icon.add_css_class ("section-icon");

            var title = new Gtk.Label ("Сообщения");
            title.add_css_class ("section-title");
            title.set_halign (Gtk.Align.START);
            title.set_hexpand (true);

            message_count = new Gtk.Label ("0");
            message_count.add_css_class ("message-count");

            heading.append (icon);
            heading.append (title);
            heading.append (message_count);
            section.append (heading);

            messages_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);

            messages_scroll = new Gtk.ScrolledWindow ();
            messages_scroll.add_css_class ("messages-scroll");
            messages_scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            messages_scroll.set_vexpand (true);
            messages_scroll.set_min_content_height (150);
            messages_scroll.set_child (messages_box);

            section.append (messages_scroll);
            return section;
        }

        private void refresh_messages () {
            clear_box (messages_box);

            var messages = notifications.get_messages ();
            message_count.set_text ("%d".printf (messages.length));
            if (messages.length == 0) {
                var empty = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
                empty.add_css_class ("empty-messages");
                empty.set_valign (Gtk.Align.CENTER);
                empty.set_vexpand (false);

                var icon = new Gtk.Label (Icons.get (Icons.BELL));
                icon.add_css_class ("empty-icon");
                var text = new Gtk.Label ("Нет сообщений");
                text.add_css_class ("empty-label");

                empty.append (icon);
                empty.append (text);
                messages_box.append (empty);
                return;
            }

            foreach (var message in messages) {
                messages_box.append (build_message_row (message));
            }
        }

        private Gtk.Widget build_message_row (MessageInfo message) {
            var row = new Gtk.Box (Gtk.Orientation.VERTICAL, 3);
            row.add_css_class ("message-row");
            if (message.urgency == "2" || message.urgency.down () == "critical") {
                row.add_css_class ("urgent");
            }

            var top = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);

            var app = new Gtk.Label (
                message.app != "" ? message.app : "Уведомление"
            );

            app.add_css_class ("message-app");
            app.set_halign (Gtk.Align.START);
            app.set_hexpand (true);
            app.set_ellipsize (Pango.EllipsizeMode.END);

            var time = new Gtk.Label (relative_time (message.timestamp));
            time.add_css_class ("message-time");
            time.set_halign (Gtk.Align.END);

            top.append (app);
            top.append (time);

            row.append (top);

            if (message.summary != "") {
                var summary = new Gtk.Label (message.summary);
                summary.add_css_class ("message-summary");
                summary.set_halign (Gtk.Align.START);
                summary.set_wrap (true);
                summary.set_wrap_mode (Pango.WrapMode.WORD_CHAR);
                summary.set_lines (2);
                summary.set_ellipsize (Pango.EllipsizeMode.END);
                row.append (summary);
            }

            if (message.body != "") {
                var body = new Gtk.Label (message.body);
                body.add_css_class ("message-body");
                body.set_halign (Gtk.Align.START);
                body.set_wrap (true);
                body.set_wrap_mode (Pango.WrapMode.WORD_CHAR);
                body.set_lines (3);
                body.set_ellipsize (Pango.EllipsizeMode.END);
                row.append (body);
            }

            return row;
        }

        private static string relative_time (int64 timestamp) {
            if (timestamp <= 0) {
                return "";
            }

            var now = new GLib.DateTime.now_local ();
            var then = new GLib.DateTime.from_unix_local (timestamp);
            int64 diff = now.to_unix () - then.to_unix ();

            if (diff < 0) {
                return "";
            }
            if (diff < 60) {
                return "только что";
            }
            if (diff < 3600) {
                return "%lld мин".printf (diff / 60);
            }
            if (diff < 86400) {
                return "%lld ч".printf (diff / 3600);
            }
            if (diff < 604800) {
                return "%lld д".printf (diff / 86400);
            }

            return then.format ("%d.%m");
        }

        /* ------------------------------------------------------------------ */
        /*  Питание                                                           */
        /* ------------------------------------------------------------------ */
        private static string build_lock_command () {
            if (Hyprland.is_hyprland_available () &&
                GLib.Environment.find_program_in_path ("hyprlock") != null) {
                return "hyprlock";
            }
            if (GLib.Environment.find_program_in_path ("swaylock") != null) {
                return "swaylock -f";
            }
            if (GLib.Environment.find_program_in_path ("gtklock") != null) {
                return "gtklock";
            }

            return "loginctl lock-session";
        }

        private Gtk.Widget build_power_grid () {
            string login = user_name;
            var grid = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            grid.add_css_class ("power-grid");
            grid.set_homogeneous (true);

            var off_button = build_power_button (
                Icons.POWER, "Выключить", "power-action-off"
            );

            off_button.clicked.connect (() => {
                SystemInfo.run_async ("systemctl poweroff");
                this.popdown ();
            });

            grid.append (off_button);

            var reboot_button = build_power_button (
                Icons.RESTART, "Перезагрузить", "power-action-reboot"
            );

            reboot_button.clicked.connect (() => {
                SystemInfo.run_async ("systemctl reboot");
                this.popdown ();
            });

            grid.append (reboot_button);

            var logout_button = build_power_button (
                Icons.LOGOUT, "Выйти", "power-action-logout"
            );

            logout_button.clicked.connect (() => {
                if (Hyprland.is_hyprland_available ()) {
                    SystemInfo.run_async ("hyprctl dispatch exit");
                }
                else if (Hyprland.is_niri_available ()) {
                    SystemInfo.run_async ("niri msg action quit");
                }
                else {
                    SystemInfo.run_async ("loginctl terminate-user " + login);
                }

                this.popdown ();
            });

            grid.append (logout_button);

            var lock_button = build_power_button (
                Icons.LOCK,
                "Блокировка",
                "power-action-lock"
            );

            lock_button.clicked.connect (() => {
                SystemInfo.run_async (build_lock_command ());
                this.popdown ();
            });

            grid.append (lock_button);

            return grid;
        }

        private Gtk.Button build_power_button (
            uint32 icon,
            string label,
            string css_class
        ) {
            var button = new Gtk.Button ();
            button.add_css_class ("power-action");
            button.add_css_class (css_class);
            button.set_tooltip_text (label);
            button.set_hexpand (true);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            box.set_halign (Gtk.Align.CENTER);

            var icon_label = new Gtk.Label (Icons.get (icon));
            icon_label.add_css_class ("power-icon");
            var text_label = new Gtk.Label (label);
            text_label.add_css_class ("power-label");

            box.append (icon_label);
            box.append (text_label);
            button.set_child (box);

            return button;
        }

        /* ------------------------------------------------------------------ */
        /*  Утилиты                                                           */
        /* ------------------------------------------------------------------ */
        private static void clear_box (Gtk.Box box) {
            Gtk.Widget? child = box.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                box.remove (child);
                child = next;
            }
        }
    }
}
