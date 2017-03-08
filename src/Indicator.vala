/*-
 * Copyright (c) 2015 Wingpanel Developers (http://launchpad.net/wingpanel)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Library General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public class Keyboard.Indicator : Wingpanel.Indicator {
    private Gtk.Grid main_grid;
    private Keyboard.Widgets.KeyboardIcon display_icon;
    private Keyboard.Widgets.LayoutManager layouts;

    public Indicator () {
        Object (code_name: Wingpanel.Indicator.KEYBOARD,
                display_name: _("Keyboard"),
                description:_("The keyboard layouts indicator"));
    }

    public override Gtk.Widget get_display_widget () {
        if (display_icon == null) {
            display_icon = new Keyboard.Widgets.KeyboardIcon ();

            display_icon.button_press_event.connect ((e) => {
                if (e.button == Gdk.BUTTON_MIDDLE) {
                    layouts.next ();
                    return Gdk.EVENT_STOP;
                }
                return Gdk.EVENT_PROPAGATE;
            });
        }
        return display_icon;
    }

    public override Gtk.Widget? get_widget () {
        if (main_grid == null) {
            main_grid = new Gtk.Grid ();
            main_grid.set_orientation (Gtk.Orientation.VERTICAL);

            layouts = new Keyboard.Widgets.LayoutManager ();

            var separator = new Wingpanel.Widgets.Separator ();

            var settings_button = new Wingpanel.Widgets.Button (_("Keyboard Settings…"));
            settings_button.clicked.connect (show_settings);

            var map_button = new Wingpanel.Widgets.Button (_("Show keyboard map"));
            map_button.clicked.connect (show_keyboard_map);

            layouts.updated.connect (() => {
                display_icon.label = layouts.get_current (true);
                var new_visibility = layouts.has_layouts ();
                if (new_visibility != visible) {
                    visible = new_visibility;
                }
            });

            layouts.updated ();

            main_grid.add (layouts);
            main_grid.add (separator);
            main_grid.add (settings_button);
            main_grid.add (map_button);
            main_grid.show_all ();
        }

        return main_grid;
    }

    public override void opened () {}

    public override void closed () {}

    private void show_settings () {
        close ();

        var list = new List<string> ();
        list.append ("keyboard:Layout");

        try {
            var appinfo = AppInfo.create_from_commandline ("switchboard", null, AppInfoCreateFlags.SUPPORTS_URIS);
            appinfo.launch_uris (list, null);
        } catch (Error e) {
            warning ("%s\n", e.message);
        }
    }

    private void show_keyboard_map () {
        close ();

        var settings = new Settings ("org.gnome.desktop.input-sources");
        var sources_list = settings.get_value ("sources");
        var current_layout = settings.get_uint ("current");
        string source = null;

        var iter = sources_list.iterator ();

        for (int i = 0; i <= current_layout; i++) {
            iter.next ("(ss)", null, &source);
        }

        string command = "gkbd-keyboard-display -l " + source;

        try {
            AppInfo.create_from_commandline (command, null, AppInfoCreateFlags.NONE).launch (null, null);
        }
        catch (Error e) {
            warning ("%s\n", e.message);
        }
    }
}

public Wingpanel.Indicator? get_indicator (Module module, Wingpanel.IndicatorManager.ServerType server_type) {
    // Temporal workarround for Greeter crash
    if (server_type != Wingpanel.IndicatorManager.ServerType.SESSION)
        return null;
    debug ("Activating Keyboard Indicator");
    var indicator = new Keyboard.Indicator ();
    return indicator;
}
