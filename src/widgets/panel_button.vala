using Gtk;

namespace ViaShell {

    public class PanelButton : Gtk.ToggleButton {

        private Gtk.Popover? panel_popover;
        private bool syncing = false;

        public PanelButton (string css_class, string? tooltip = null) {
            add_css_class (css_class);
            set_has_frame (false);

            if (tooltip != null) {
                set_tooltip_text (tooltip);
            }

            toggled.connect (on_toggled);
        }

        public void set_panel_popover (Gtk.Popover popover) {
            panel_popover = popover;
            popover.set_parent (this);
            popover.set_has_arrow (false);
            popover.set_position (Gtk.PositionType.RIGHT);
            // Небольшой зазор между панелью и меню
            popover.set_offset (10, 0);

            popover.closed.connect (() => {
                if (!syncing && get_active ()) {
                    syncing = true;
                    set_active (false);
                    syncing = false;
                }
            });
        }

        private void on_toggled () {
            stdout.printf ("DBG toggle active=%s popover=%s mapped=%s\n",
                get_active ().to_string (), (panel_popover != null).to_string (),
                get_mapped ().to_string ());
            if (syncing || panel_popover == null) {
                return;
            }

            if (get_active ()) {
                panel_popover.popup ();
                stdout.printf ("DBG popup called, visible=%s\n", panel_popover.get_visible ().to_string ());
            }
            else {
                panel_popover.popdown ();
            }
        }

        public override void dispose () {
            if (panel_popover != null) {
                panel_popover.unparent ();
                panel_popover = null;
            }
            base.dispose ();
        }
    }
}
