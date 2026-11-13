using Gtk;

namespace ViaShell {

    public class ClockWidget : Gtk.Box {

        private Gtk.MenuButton button;
        private Gtk.Label time_label;
        private Gtk.Label date_label;
        private CalendarWidget calendar;

        public ClockWidget () {
            Object (
                orientation: Gtk.Orientation.VERTICAL,
                spacing: 0
            );

            button = new Gtk.MenuButton ();
            button.add_css_class ("clock-button");
            button.set_direction (Gtk.ArrowType.RIGHT);
            button.set_has_frame (false);
            button.set_tooltip_text ("Календарь");
            button.set_hexpand (true);
            button.set_halign (Gtk.Align.FILL);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 1);
            box.add_css_class ("clock-content");
            box.set_halign (Gtk.Align.CENTER);

            time_label = new Gtk.Label ("");
            time_label.add_css_class ("vs-clock-time");
            time_label.set_halign (Gtk.Align.CENTER);

            date_label = new Gtk.Label ("");
            date_label.add_css_class ("vs-clock-date");
            date_label.set_halign (Gtk.Align.CENTER);
            date_label.set_ellipsize (Pango.EllipsizeMode.END);

            box.append (time_label);
            box.append (date_label);
            button.set_child (box);

            calendar = new CalendarWidget ();

            var popover = new Gtk.Popover ();
            popover.add_css_class ("vs-popover");
            popover.add_css_class ("calendar-popover");
            popover.set_has_arrow (false);
            popover.set_position (Gtk.PositionType.RIGHT);
            popover.set_child (calendar);
            popover.show.connect (() => {
                calendar.reset_to_today ();
            });
            button.set_popover (popover);

            this.append (button);

            update_time ();
            GLib.Timeout.add_seconds (1, () => {
                update_time ();
                return GLib.Source.CONTINUE;
            });
        }

        private void update_time () {
            var now = new GLib.DateTime.now_local ();

            time_label.set_text (now.format ("%H:%M"));

            int weekday = now.get_day_of_week ();
            date_label.set_text ("%s, %d %s".printf (
                CalendarWidget.weekday_short (weekday).down (),
                now.get_day_of_month (),
                CalendarWidget.month_short (now.get_month ()).down ()
            ));

            button.set_tooltip_text (now.format ("%A, %d %B %Y"));
        }
    }
}
