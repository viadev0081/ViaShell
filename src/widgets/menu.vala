using Gtk;

namespace ViaShell {

    public class LauncherMenu : Gtk.Popover {

        private Distro distro;
        private MediaService media;
        private NotificationService notifications;
        private ThemeManager themes;
        private IniConfig config;

        private string user_name;
        private string display_name;
        private bool theme_syncing = false;

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

        /* Буфер обмена */
        private Gtk.Label clipboard_text;
        private uint clipboard_timer = 0;

        /* Wi-Fi */
        private Gtk.Label wifi_ssid;
        private Gtk.Label wifi_signal;
        private Gtk.Label wifi_internet;
        private Gtk.Button wifi_toggle;

        /* Рабочие столы в меню */
        private Gtk.Box? workspaces_dots_menu;

    public LauncherMenu (
            Distro distro,
            MediaService media,
            NotificationService notifications,
            ThemeManager themes,
            IniConfig config
        ) {
            this.distro = distro;
            this.media = media;
            this.notifications = notifications;
            this.themes = themes;
            this.config = config;

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
            root.set_size_request (400, 400);
            root.set_vexpand (true);

            root.append (build_header ());
            if (config.get_bool ("menu", "theme", true)) {
                root.append (build_theme_row ());
            }
            if (config.get_bool ("menu", "media", true)) {
                root.append (build_media_card ());
            }
            if (config.get_bool ("menu", "workspaces", true)) {
                root.append (build_workspaces_menu ());
            }
            if (config.get_bool ("menu", "wifi", true)) {
                root.append (build_wifi ());
            }
            if (config.get_bool ("menu", "clipboard", true)) {
                root.append (build_clipboard ());
            }
            if (config.get_bool ("menu", "messages", true)) {
                root.append (build_messages ());
            }
            if (config.get_bool ("menu", "power", true)) {
                root.append (build_power_grid ());
            }

            var scroller = new Gtk.ScrolledWindow ();
            scroller.add_css_class ("menu-scroller");
            scroller.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            scroller.set_vexpand (true);
            // Gtk.Popover в GTK 4.24 подгоняет высоту под минимальную высоту
            // содержимого, поэтому задаём её явно на скроллере.
            scroller.set_min_content_height (760);
            scroller.set_child (root);

            this.set_child (scroller);

            if (GLib.Environment.get_variable ("VIASHELL_DEBUG") == "size") {
                int min_h, nat_h, min_w, nat_w;
                this.measure (Gtk.Orientation.VERTICAL, -1, out min_h, out nat_h, null, null);
                this.measure (Gtk.Orientation.HORIZONTAL, -1, out min_w, out nat_w, null, null);
                stdout.printf ("menu-measure: min=%dx%d nat=%dx%d\n", min_w, min_h, nat_w, nat_h);
                stdout.flush ();
            }

            this.show.connect (() => {
                if (GLib.Environment.get_variable ("VIASHELL_DEBUG") == "menu") {
                    GLib.Timeout.add (600, () => {
                        stdout.printf ("menu-size: popover=%dx%d scroller=%dx%d content=%dx%d\n",
                            this.get_width (), this.get_height (),
                            scroller.get_width (), scroller.get_height (),
                            root.get_width (), root.get_height ());
                        return GLib.Source.REMOVE;
                    });
                }
                media.refresh ();
                notifications.refresh ();
                update_media ();
                refresh_messages ();
                if (config.get_bool ("menu", "wifi", true)) {
                    refresh_wifi ();
                }
                if (config.get_bool ("menu", "clipboard", true)) {
                    read_clipboard ();
                    clipboard_timer = GLib.Timeout.add_seconds (2, () => {
                        read_clipboard ();
                        return GLib.Source.CONTINUE;
                    });
                }
                if (workspaces_dots_menu != null) {
                    refresh_workspaces_menu (workspaces_dots_menu);
                }
            });

            this.hide.connect (() => {
                if (clipboard_timer != 0) {
                    GLib.Source.remove (clipboard_timer);
                    clipboard_timer = 0;
                }
            });

            media.changed.connect (() => {
                update_media ();
            });

            notifications.changed.connect (() => {
                refresh_messages ();
            });

            update_media ();
            refresh_messages ();
            if (config.get_bool ("menu", "wifi", true)) {
                refresh_wifi ();
            }
            if (config.get_bool ("menu", "clipboard", true)) {
                read_clipboard ();
            }
            if (workspaces_dots_menu != null) {
                refresh_workspaces_menu (workspaces_dots_menu);
            }
        }

        /* ------------------------------------------------------------------ */
        /*  Шапка (логотип оцентрировано)                                     */
        /* ------------------------------------------------------------------ */
        private Gtk.Widget build_header () {
            var header = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
            header.add_css_class ("menu-header");
            header.set_halign (Gtk.Align.CENTER);
            header.set_valign (Gtk.Align.START);

            // Логотип/аватура — по центру меню, а не прижатый к правому краю
            var avatar_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            avatar_row.set_hexpand (true);
            avatar_row.set_halign (Gtk.Align.FILL);
            avatar_row.append (build_avatar ());

            header.append (avatar_row);

            var info = new Gtk.Box (Gtk.Orientation.VERTICAL, 3);
            info.set_halign (Gtk.Align.CENTER);
            info.set_valign (Gtk.Align.CENTER);

            var name_label = new Gtk.Label (display_name);
            name_label.add_css_class ("user-name");
            name_label.set_halign (Gtk.Align.CENTER);
            name_label.set_ellipsize (Pango.EllipsizeMode.END);
            name_label.set_max_width_chars (26);

            var host_label = new Gtk.Label ("@" + GLib.Environment.get_host_name ());
            host_label.add_css_class ("user-host");
            host_label.set_halign (Gtk.Align.CENTER);

            var chip = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            chip.add_css_class ("distro-chip");
            chip.set_halign (Gtk.Align.CENTER);
            chip.set_tooltip_text (distro.name);

            var distro_icon = new Gtk.Label ("");
            distro_icon.add_css_class ("distro-glyph");

            // Акцентный цвет текущей темы, а не хардкод из catppuccin
            distro_icon.set_markup (
                "<span foreground='%s'>%s</span>".printf (
                    themes.accent_color (), GLib.Markup.escape_text (Icons.get (distro.glyph))
                )
            );

            var distro_name = new Gtk.Label (distro.name);
            distro_name.add_css_class ("distro-name");
            distro_name.set_ellipsize (Pango.EllipsizeMode.END);
            distro_name.set_max_width_chars (20);

            chip.append (distro_icon);
            chip.append (distro_name);

            info.append (name_label);
            info.append (host_label);
            info.append (chip);

            header.append (info);
            return header;
        }

        /* ------------------------------------------------------------------ */
        /*  Тема оформления                                                   */
        /* ------------------------------------------------------------------ */
        private Gtk.Widget build_theme_row () {
            var card = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            card.add_css_class ("theme-card");
            card.set_valign (Gtk.Align.CENTER);

            var icon = new Gtk.Label (Icons.get (Icons.PALETTE));
            icon.add_css_class ("theme-icon");
            icon.set_valign (Gtk.Align.CENTER);

            var label = new Gtk.Label ("Тема");
            label.add_css_class ("theme-label");
            label.set_hexpand (true);
            label.set_halign (Gtk.Align.START);

            var dropdown = new Gtk.DropDown.from_strings (themes.labels);
            dropdown.add_css_class ("theme-dropdown");
            dropdown.set_selected ((uint) themes.current);
            dropdown.set_valign (Gtk.Align.CENTER);
            dropdown.notify["selected"].connect (() => {
                if (theme_syncing) {
                    return;
                }
                themes.set_theme ((int) dropdown.get_selected ());
            });

            themes.changed.connect (() => {
                if (theme_syncing) {
                    return;
                }

                theme_syncing = true;
                dropdown.set_selected ((uint) themes.current);
                theme_syncing = false;
            });

            card.append (icon);
            card.append (label);
            card.append (dropdown);

            return card;
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
        /*  Рабочие столы в меню                                              */
        /* ------------------------------------------------------------------ */
        private Gtk.Widget build_workspaces_menu () {
            var section = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            section.add_css_class ("menu-workspaces");

            var heading = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            heading.add_css_class ("menu-section-heading");

            var icon = new Gtk.Label (Icons.get (Icons.ACCOUNT));
            icon.add_css_class ("section-icon");

            var title = new Gtk.Label ("Рабочие столы");
            title.add_css_class ("section-title");
            title.set_halign (Gtk.Align.START);
            title.set_hexpand (true);

            heading.append (icon);
            heading.append (title);
            section.append (heading);

            var dots_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            dots_box.add_css_class ("menu-workspaces-dots");
            dots_box.set_halign (Gtk.Align.CENTER);

            section.append (dots_box);

            workspaces_dots_menu = dots_box;
            refresh_workspaces_menu (dots_box);

            var controller = new Gtk.EventControllerScroll (
                Gtk.EventControllerScrollFlags.VERTICAL
            );
            controller.scroll.connect ((dx, dy) => {
                refresh_workspaces_menu (dots_box);
                return true;
            });
            section.add_controller (controller);

            return section;
        }

        private void refresh_workspaces_menu (Gtk.Box dots_box) {
            if (!Hyprland.is_available () && !Sway.is_available ()) {
                return;
            }

            bool use_sway = Sway.is_available ();
            WorkspaceInfo[] list = use_sway
                ? Sway.get_workspaces (null, 10)
                : Hyprland.get_workspaces (null, 10);

            clear_box (dots_box);

            foreach (var ws in list) {
                var dot = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
                dot.add_css_class ("ws-dot");
                dot.set_size_request (10, 10);
                dot.set_halign (Gtk.Align.CENTER);
                dot.set_valign (Gtk.Align.CENTER);

                if (ws.active) {
                    dot.add_css_class ("current");
                    dot.set_size_request (22, 7);
                } else if (ws.occupied) {
                    dot.add_css_class ("occupied");
                } else {
                    dot.add_css_class ("empty");
                }

                var button = new Gtk.Button ();
                button.add_css_class ("menu-ws-button");
                button.set_child (dot);
                button.set_size_request (30, 24);
                button.set_tooltip_text (
                    ws.name != "" ? ws.name : "Рабочий стол %d".printf (ws.idx)
                );
                button.clicked.connect (() => {
                    if (use_sway) {
                        Sway.focus_workspace_on (null, ws.idx);
                    } else {
                        Hyprland.focus_workspace_on (null, ws.idx);
                    }
                    this.popdown ();
                });

                dots_box.append (button);
            }
        }

        /* ------------------------------------------------------------------ */
        /*  Wi-Fi                                                             */
        /* ------------------------------------------------------------------ */
        private Gtk.Widget build_wifi () {
            var section = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            section.add_css_class ("wifi-section");

            var heading = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            heading.add_css_class ("menu-section-heading");

            var icon = new Gtk.Label (Icons.get (Icons.WIFI));
            icon.add_css_class ("section-icon");

            var title = new Gtk.Label ("Wi-Fi");
            title.add_css_class ("section-title");
            title.set_halign (Gtk.Align.START);
            title.set_hexpand (true);

            heading.append (icon);
            heading.append (title);
            section.append (heading);

            var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            row.set_halign (Gtk.Align.FILL);

            wifi_ssid = new Gtk.Label ("Wi-Fi");
            wifi_ssid.add_css_class ("wifi-ssid");
            wifi_ssid.set_halign (Gtk.Align.START);
            wifi_ssid.set_hexpand (true);
            wifi_ssid.set_ellipsize (Pango.EllipsizeMode.END);

            wifi_signal = new Gtk.Label ("");
            wifi_signal.add_css_class ("wifi-signal");
            wifi_signal.set_halign (Gtk.Align.END);

            row.append (wifi_ssid);
            row.append (wifi_signal);
            section.append (row);

            wifi_internet = new Gtk.Label ("");
            wifi_internet.add_css_class ("wifi-internet");
            wifi_internet.set_halign (Gtk.Align.START);
            section.append (wifi_internet);

            var controls = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            wifi_toggle = new Gtk.Button ();
            wifi_toggle.add_css_class ("wifi-toggle");
            wifi_toggle.set_label ("Wi-Fi");
            wifi_toggle.set_hexpand (false);
            wifi_toggle.clicked.connect (() => {
                bool on = !Wifi.radio_enabled ();
                Wifi.set_radio (on);
                GLib.Timeout.add_seconds (1, () => {
                    refresh_wifi ();
                    return GLib.Source.REMOVE;
                });
            });
            controls.append (wifi_toggle);

            var refresh_button = new Gtk.Button ();
            refresh_button.add_css_class ("wifi-refresh");
            refresh_button.set_label ("↻");
            refresh_button.set_hexpand (false);
            refresh_button.clicked.connect (() => refresh_wifi ());
            controls.append (refresh_button);

            section.append (controls);

            return section;
        }

        private void refresh_wifi () {
            if (!Wifi.is_available ()) {
                wifi_ssid.set_text ("nmcli не найден");
                wifi_signal.set_text ("");
                wifi_internet.set_text ("");
                wifi_toggle.set_sensitive (false);
                return;
            }

            bool radio = Wifi.radio_enabled ();
            wifi_toggle.set_label (radio ? "Отключить Wi-Fi" : "Включить Wi-Fi");
            wifi_toggle.set_sensitive (true);

            if (!radio) {
                wifi_ssid.set_text ("Wi-Fi выключен");
                wifi_signal.set_text ("");
                wifi_internet.set_text ("");
                return;
            }

            var info = Wifi.active_connection ();
            if (info != null && info.ssid != "") {
                wifi_ssid.set_text (info.ssid);
                if (info.signal >= 0) {
                    wifi_signal.set_text ("%d%%".printf (info.signal));
                } else {
                    wifi_signal.set_text ("");
                }
            } else {
                wifi_ssid.set_text ("Не подключено");
                wifi_signal.set_text ("");
            }

            if (Wifi.has_internet ()) {
                wifi_internet.set_text ("Интернет: есть");
                wifi_internet.remove_css_class ("wifi-no-inet");
                wifi_internet.add_css_class ("wifi-ok");
            } else {
                wifi_internet.set_text ("Интернет: нет");
                wifi_internet.remove_css_class ("wifi-ok");
                wifi_internet.add_css_class ("wifi-no-inet");
            }
        }

        /* ------------------------------------------------------------------ */
        /*  Буфер обмена                                                      */
        /* ------------------------------------------------------------------ */
        private Gtk.Widget build_clipboard () {
            var section = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            section.add_css_class ("clipboard-section");

            var heading = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            heading.add_css_class ("menu-section-heading");

            var icon = new Gtk.Label (Icons.get (Icons.CLIPBOARD));
            icon.add_css_class ("section-icon");

            var title = new Gtk.Label ("Буфер обмена");
            title.add_css_class ("section-title");
            title.set_halign (Gtk.Align.START);
            title.set_hexpand (true);

            heading.append (icon);
            heading.append (title);
            section.append (heading);

            clipboard_text = new Gtk.Label ("Читаю буфер…");
            clipboard_text.add_css_class ("clipboard-text");
            clipboard_text.set_halign (Gtk.Align.START);
            clipboard_text.set_hexpand (true);
            clipboard_text.set_valign (Gtk.Align.CENTER);
            clipboard_text.set_wrap (true);
            clipboard_text.set_wrap_mode (Pango.WrapMode.WORD_CHAR);
            clipboard_text.set_lines (3);
            clipboard_text.set_ellipsize (Pango.EllipsizeMode.END);
            clipboard_text.set_selectable (true);
            section.append (clipboard_text);

            var controls = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);

            var refresh_button = new Gtk.Button ();
            refresh_button.add_css_class ("clipboard-refresh");
            refresh_button.set_label ("Обновить");
            refresh_button.set_hexpand (false);
            refresh_button.clicked.connect (() => read_clipboard ());
            controls.append (refresh_button);

            var clear_button = new Gtk.Button ();
            clear_button.add_css_class ("clipboard-clear");
            clear_button.set_label ("Очистить");
            clear_button.set_hexpand (false);
            clear_button.clicked.connect (() => {
                SystemInfo.run_async ("wl-copy < /dev/null");
                clipboard_text.set_text ("Очищено");
            });
            controls.append (clear_button);

            section.append (controls);

            return section;
        }

        private void read_clipboard () {
            string? text = null;
            try {
                string out, err;
                int status;
                if (
                    GLib.Process.spawn_command_line_sync (
                        "wl-paste",
                        out out,
                        out err,
                        out status
                    ) && status == 0
                ) {
                    text = out;
                }
            } catch (GLib.Error e) {
                text = null;
            }

            if (text == null || text == "") {
                clipboard_text.set_text ("Буфер пуст");
            } else {
                string shown = text.replace ("\n", " ");
                if (shown.length > 140) {
                    shown = shown.substring (0, 140) + "…";
                }
                clipboard_text.set_text (shown);
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
                else if (Sway.is_available ()) {
                    SystemInfo.run_async ("swaymsg exit");
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
