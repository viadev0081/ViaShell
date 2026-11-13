using Gtk;

namespace ViaShell {

    public class CalendarWidget : Gtk.Box {

        private Gtk.Label title_label;
        private Gtk.Label footer_label;
        private Gtk.Grid grid;

        private int display_year;
        private int display_month;

        private int selected_year;
        private int selected_month;
        private int selected_day;

        public CalendarWidget () {
            Object (
                orientation: Gtk.Orientation.VERTICAL,
                spacing: 8
            );

            this.add_css_class ("calendar-content");
            this.set_size_request (318, -1);

            var now = new GLib.DateTime.now_local ();
            display_year = now.get_year ();
            display_month = now.get_month ();
            selected_year = display_year;
            selected_month = display_month;
            selected_day = now.get_day_of_month ();

            // Заголовок с навигацией
            var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            header.add_css_class ("cal-header");

            var prev_button = new Gtk.Button.with_label (Icons.get (Icons.CHEVRON_LEFT));
            prev_button.add_css_class ("cal-nav");
            prev_button.set_tooltip_text ("Предыдущий месяц");
            prev_button.clicked.connect (() => {
                shift_month (-1);
            });

            title_label = new Gtk.Label ("");
            title_label.add_css_class ("cal-title");
            title_label.set_hexpand (true);
            title_label.set_halign (Gtk.Align.CENTER);

            var next_button = new Gtk.Button.with_label (Icons.get (Icons.CHEVRON_RIGHT));
            next_button.add_css_class ("cal-nav");
            next_button.set_tooltip_text ("Следующий месяц");
            next_button.clicked.connect (() => {
                shift_month (1);
            });

            header.append (prev_button);
            header.append (title_label);
            header.append (next_button);
            this.append (header);

            // Дни недели
            var weekdays = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            weekdays.add_css_class ("cal-weekdays");
            weekdays.set_homogeneous (true);

            string[] names = {
                "Пн",
                "Вт",
                "Ср",
                "Чт",
                "Пт",
                "Сб",
                "Вс"
            };

            foreach (var name in names) {
                var label = new Gtk.Label (name);
                label.add_css_class ("cal-weekday");
                weekdays.append (label);
            }

            this.append (weekdays);

            // Сетка дней
            grid = new Gtk.Grid ();
            grid.add_css_class ("cal-grid");
            grid.set_column_homogeneous (true);
            grid.set_row_homogeneous (true);
            grid.set_column_spacing (2);
            grid.set_row_spacing (2);
            this.append (grid);

            // Нижняя строка
            var footer = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            footer.add_css_class ("cal-footer");

            var today_button = new Gtk.Button.with_label ("Сегодня");
            today_button.add_css_class ("cal-today-button");
            today_button.clicked.connect (() => {
                reset_to_today ();
            });

            footer_label = new Gtk.Label ("");
            footer_label.add_css_class ("cal-footer-label");
            footer_label.set_hexpand (true);
            footer_label.set_halign (Gtk.Align.END);
            footer_label.set_ellipsize (Pango.EllipsizeMode.END);

            footer.append (today_button);
            footer.append (footer_label);
            this.append (footer);

            refresh ();
        }

        public void reset_to_today () {
            var now = new GLib.DateTime.now_local ();
            display_year = now.get_year ();
            display_month = now.get_month ();
            selected_year = display_year;
            selected_month = display_month;
            selected_day = now.get_day_of_month ();
            refresh ();
        }

        private void shift_month (int delta) {
            int year = display_year;
            int month = display_month;
            month += delta;
            while (month < 1) {
                month += 12;
                year--;
            }

            while (month > 12) {
                month -= 12;
                year++;
            }

            display_year = year;
            display_month = month;
            refresh ();
        }

        private void select_date (int year, int month, int day) {
            selected_year = year;
            selected_month = month;
            selected_day = day;
            display_year = year;
            display_month = month;
            refresh ();
        }

        private void refresh () {
            title_label.set_text ("%s %d".printf (month_name (display_month), display_year));

            Gtk.Widget? child = grid.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                grid.remove (child);
                child = next;
            }

            var now = new GLib.DateTime.now_local ();
            int today_year = now.get_year ();
            int today_month = now.get_month ();
            int today_day = now.get_day_of_month ();

            var first = new GLib.DateTime.local (display_year, display_month, 1, 0, 0, 0);
            int first_weekday = first.get_day_of_week (); // 1 = понедельник
            int offset = first_weekday - 1;
            int days_in_month = days_in (display_year, display_month);

            int prev_year = display_year;
            int prev_month = display_month;
            shift_month_values (ref prev_year, ref prev_month, -1);
            int prev_days = days_in (prev_year, prev_month);

            int next_year = display_year;
            int next_month = display_month;
            shift_month_values (ref next_year, ref next_month, 1);

            for (int i = 0; i < 42; i++) {
                int cell = i - offset + 1;
                int year = display_year;
                int month = display_month;
                int day = cell;
                bool other = false;

                if (cell < 1) {
                    year = prev_year;
                    month = prev_month;
                    day = prev_days + cell;
                    other = true;
                }
                else if (cell > days_in_month) {
                    year = next_year;
                    month = next_month;
                    day = cell - days_in_month;
                    other = true;
                }

                bool is_today = (
                    year == today_year &&
                    month == today_month &&
                    day == today_day
                );

                bool is_selected = (
                    year == selected_year &&
                    month == selected_month &&
                    day == selected_day
                );

                var button = create_day_button (
                    year,
                    month,
                    day,
                    other,
                    is_today,
                    is_selected
                );

                grid.attach (button, i % 7, i / 7, 1, 1);
            }

            update_footer ();
        }

        private Gtk.Button create_day_button (
            int year,
            int month,
            int day,
            bool other,
            bool is_today,
            bool is_selected
        ) {
            var button = new Gtk.Button.with_label ("%d".printf (day));
            button.add_css_class ("cal-day");

            if (other) {
                button.add_css_class ("other-month");
            }
            if (is_today) {
                button.add_css_class ("today");
            }
            if (is_selected) {
                button.add_css_class ("selected");
            }

            button.set_size_request (34, 32);
            button.clicked.connect (() => {
                select_date (year, month, day);
            });

            return button;
        }

        private void update_footer () {
            var date = new GLib.DateTime.local (
                selected_year, selected_month, selected_day, 0, 0, 0
            );

            int weekday = date.get_day_of_week ();
            footer_label.set_text ("%s, %d %s".printf (
                weekday_name (weekday), selected_day, month_genitive (selected_month)
            ));
        }

        private static int days_in (int year, int month) {
            return (int) GLib.Date.get_days_in_month (
                (GLib.DateMonth) month,
                (GLib.DateYear) year
            );
        }

        private static void shift_month_values (
            ref int year,
            ref int month,
            int delta
        ) {
            month += delta;
            while (month < 1) {
                month += 12;
                year--;
            }

            while (month > 12) {
                month -= 12;
                year++;
            }
        }

        private static string month_name (int month) {
            switch (month) {
                case 1: return "Январь";
                case 2: return "Февраль";
                case 3: return "Март";
                case 4: return "Апрель";
                case 5: return "Май";
                case 6: return "Июнь";
                case 7: return "Июль";
                case 8: return "Август";
                case 9: return "Сентябрь";
                case 10: return "Октябрь";
                case 11: return "Ноябрь";
                case 12: return "Декабрь";
                default: return "";
            }
        }

        private static string month_genitive (int month) {
            switch (month) {
                case 1: return "января";
                case 2: return "февраля";
                case 3: return "марта";
                case 4: return "апреля";
                case 5: return "мая";
                case 6: return "июня";
                case 7: return "июля";
                case 8: return "августа";
                case 9: return "сентября";
                case 10: return "октября";
                case 11: return "ноября";
                case 12: return "декабря";
                default: return "";
            }
        }

        public static string weekday_name (int weekday) {
            switch (weekday) {
                case 1: return "Понедельник";
                case 2: return "Вторник";
                case 3: return "Среда";
                case 4: return "Четверг";
                case 5: return "Пятница";
                case 6: return "Суббота";
                case 7: return "Воскресенье";
                default: return "";
            }
        }

        public static string weekday_short (int weekday) {
            switch (weekday) {
                case 1: return "Пн";
                case 2: return "Вт";
                case 3: return "Ср";
                case 4: return "Чт";
                case 5: return "Пт";
                case 6: return "Сб";
                case 7: return "Вс";
                default: return "";
            }
        }

        public static string month_short (int month) {
            switch (month) {
                case 1: return "янв";
                case 2: return "фев";
                case 3: return "мар";
                case 4: return "апр";
                case 5: return "мая";
                case 6: return "июн";
                case 7: return "июл";
                case 8: return "авг";
                case 9: return "сен";
                case 10: return "окт";
                case 11: return "ноя";
                case 12: return "дек";
                default: return "";
            }
        }
    }
}
