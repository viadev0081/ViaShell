using Gtk;

namespace ViaShell {

    private class WsButton : Gtk.Button {

        public const int ROW_HEIGHT = 24;

        public override void measure (
            Gtk.Orientation orientation,
            int for_size,
            out int minimum,
            out int natural,
            out int minimum_baseline,
            out int natural_baseline
        ) {
            base.measure (
                orientation, for_size,
                out minimum, out natural,
                out minimum_baseline, out natural_baseline
            );

            if (orientation == Gtk.Orientation.VERTICAL) {
                minimum = ROW_HEIGHT;
                natural = ROW_HEIGHT;
            }
        }
    }

    public class WorkspacesWidget : Gtk.Box {

        private string? monitor_name;
        private Gtk.Button[] buttons = {};
        private Gtk.Box[] dots = {};
        private WorkspaceInfo[] current = {};
        private string last_state = "";
        private uint timer_id = 0;

        private static bool use_sway = Sway.is_available ();

        public WorkspacesWidget (string? monitor_name) {
            Object (
                orientation: Gtk.Orientation.VERTICAL,
                spacing: 2
            );

            this.monitor_name = monitor_name;
            this.add_css_class ("workspaces");
            this.set_halign (Gtk.Align.CENTER);

            build_buttons (use_sway ? 10 : (Hyprland.is_niri_available () ? 3 : 10));
            refresh ();

            timer_id = GLib.Timeout.add (800, () => {
                refresh ();
                return GLib.Source.CONTINUE;
            });

            var scroll = new Gtk.EventControllerScroll (
                Gtk.EventControllerScrollFlags.VERTICAL
            );

            scroll.scroll.connect ((dx, dy) => {
                if (dy < 0) {
                    focus_relative (-1);
                }
                else if (dy > 0) {
                    focus_relative (1);
                }

                return true;
            });
            this.add_controller (scroll);
        }

        private static void focus_relative (int delta) {
            if (use_sway) {
                Sway.focus_relative (delta);
            } else {
                Hyprland.focus_relative (delta);
            }
        }

        private void build_buttons (int count) {
            while (buttons.length < count) {
                add_button (buttons.length);
            }
        }

        private void add_button (int position) {
            var dot = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            dot.add_css_class ("ws-dot");
            dot.add_css_class ("empty");
            dot.set_size_request (8, 8);
            dot.set_halign (Gtk.Align.CENTER);
            dot.set_valign (Gtk.Align.CENTER);

            var button = new WsButton ();
            button.add_css_class ("ws-button");
            button.set_child (dot);
            button.set_tooltip_text ("Рабочий стол %d".printf (position + 1));
            button.set_size_request (42, WsButton.ROW_HEIGHT);
            button.set_halign (Gtk.Align.CENTER);
            button.set_valign (Gtk.Align.CENTER);

            int index = position;
            button.clicked.connect (() => {
                activate_at (index);
            });

            buttons += button;
            dots += dot;
            this.append (button);
        }

        private void activate_at (int index) {
            if (index < 0 || index >= current.length) {
                return;
            }

            var ws = current[index];
            if (use_sway) {
                Sway.focus_workspace_on (monitor_name, ws.idx);
            } else {
                Hyprland.focus_workspace_on (monitor_name, ws.idx);
            }
        }

        private void refresh () {
            if (use_sway) {
                if (!Sway.is_available ()) {
                    return;
                }
            } else {
                if (!Hyprland.is_available ()) {
                    return;
                }
            }

            WorkspaceInfo[] list = use_sway
                ? Sway.get_workspaces (monitor_name, 10)
                : Hyprland.get_workspaces (monitor_name, 10);
            if (list.length == 0) {
                return;
            }

            current = list;

            if (list.length > buttons.length) {
                build_buttons (list.length);
            }

            string state = "";
            foreach (var ws in list) {
                state += "%d:%d:%d:%d;".printf (
                    ws.idx, ws.active ? 1 : 0, ws.occupied ? 1 : 0, ws.windows
                );
            }

            if (state == last_state) {
                return;
            }

            last_state = state;

            for (int i = 0; i < buttons.length; i++) {
                if (i >= list.length) {
                    buttons[i].set_visible (false);
                    continue;
                }

                var ws = list[i];
                var dot = dots[i];
                buttons[i].set_visible (true);
                buttons[i].set_tooltip_text (
                    ws.name != "" ? ws.name : "Рабочий стол %d".printf (ws.idx)
                );

                dot.remove_css_class ("current");
                dot.remove_css_class ("occupied");
                dot.remove_css_class ("empty");
                dot.remove_css_class ("current-empty");

                if (ws.active) {
                    dot.add_css_class ("current");
                    dot.set_size_request (28, 7);
                    buttons[i].add_css_class ("active-workspace");
                }
                else {
                    buttons[i].remove_css_class ("active-workspace");
                    if (ws.occupied) {
                        dot.add_css_class ("occupied");
                    }
                    else {
                        dot.add_css_class ("empty");
                    }
                    dot.set_size_request (8, 8);
                }
            }
        }

        public override void dispose () {
            if (timer_id != 0) {
                GLib.Source.remove (timer_id);
                timer_id = 0;
            }
            base.dispose ();
        }
    }
}
