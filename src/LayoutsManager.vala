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


public class Keyboard.Widgets.LayoutManager : Gtk.ScrolledWindow {
    public signal void updated ();

    private GLib.Settings settings;
    private Gtk.Grid main_grid;

    public class LayoutManager () {
        populate_layouts ();
    }

    construct {
        hscrollbar_policy = Gtk.PolicyType.NEVER;
        main_grid = new Gtk.Grid ();
        main_grid.orientation = Gtk.Orientation.VERTICAL;
        add_with_viewport (main_grid);
        settings = new GLib.Settings ("org.gnome.desktop.input-sources");
        settings.changed["sources"].connect (() => {
            clear ();
            populate_layouts ();
            updated ();
        });

        settings.changed["current"].connect_after (() => {
            updated ();
        });

        show_all ();
    }

    public override void get_preferred_height (out int minimum_height, out int natural_height) {
        List<weak Gtk.Widget> children = main_grid.get_children ();
        weak Gtk.Widget? first_child = children.first ().data;
        if (first_child == null) {
            minimum_height = 0;
            natural_height = 0;
        } else {
            main_grid.get_preferred_height (out minimum_height, out natural_height);
            minimum_height = int.min (minimum_height, (int)(Gdk.Screen.height ()*2/3));
        }
    }

    private void populate_layouts () {
        var source_list = settings.get_value ("sources");
        LayoutButton layout_button = null;
        var iter = source_list.iterator ();
        int i = 0;
        string manager_type;
        string source;
        while (iter.next ("(ss)", out manager_type, out source)) {
            switch (manager_type) {
                case "xkb":
                    string? name;
                    string language;
                    string? variant = null;
                    if ("+" in source) {
                        var layouts = source.split ("+", 2);
                        language = layouts[0];
                        variant = layouts[1];
                    } else {
                        language = source;
                    }

                    name = get_name_for_xkb_layout (language, variant);
                    layout_button = new LayoutButton (name, language, i, settings, layout_button);
                    main_grid.add (layout_button);
                    break;
                case "ibus":
                    // source contains the IBus engine name, how do we implement it ?
                    break;
            }

            i++;
        }

        main_grid.show_all ();
    }

    public string? get_name_for_xkb_layout (string language, string? variant) {
        var file = File.new_for_path ("/usr/share/X11/xkb/rules/evdev.lst");

        if (!file.query_exists ()) {
            critical ("File '%s' doesn't exist.", file.get_path ());
            return null;
        }

        if (variant == null) {
            try {
                var dis = new DataInputStream (file.read ());
                string line;
                bool layout_found = false;
                while ((line = dis.read_line (null)) != null) {
                    if (layout_found) {
                        if ("!" in line || line == "") {
                            break;
                        }

                        var parts = line.chug ().split (" ", 2);
                        if (parts[0] == language) {
                            return dgettext ("xkeyboard-config", parts[1].chug ());
                        }
                    } else {
                        if ("!" in line && "layout" in line) {
                            layout_found = true;
                        }
                    }
                }
            } catch (Error e) {
                error ("%s", e.message);
            }

            return null;
        } else {
            try {
                var dis = new DataInputStream (file.read ());
                string line;
                bool variant_found = false;
                while ((line = dis.read_line (null)) != null) {
                    if (variant_found) {
                        if ("!" in line || line == "") {
                            break;
                        }

                        var parts = line.chug ().split (" ", 2);
                        var subparts = parts[1].chug ().split (":", 2);
                        if (subparts[0] == language && parts[0] == variant) {
                            return dgettext ("xkeyboard-config", subparts[1].chug ());
                        }
                    } else {
                        if ("!" in line && "variant" in line) {
                            variant_found = true;
                        }
                    }
                }
            } catch (Error e) {
                error ("%s", e.message);
            }

            return null;
        }
    }

    public string get_current (bool shorten = false) {
        string current = "us";
        main_grid.get_children ().foreach ((child) => {
            if (child is LayoutButton) {
                var layout_button = (LayoutButton) child;
                if (layout_button.radio_button.active) {
                    current = layout_button.code;
                }
            }
        });

        if (shorten) {
            return current[0:2];
        } else {
            return current;
        }
    }

    public void next () {
        var current = settings.get_value ("current");
        var next = current.get_uint32 () + 1;
        if (next >= main_grid.get_children ().length ()) {
            next = 0;
        }

        settings.set_value ("current", next);
    }

    public void clear () {
        main_grid.get_children ().foreach ((child) => {
            child.destroy ();
        });
    }

    public bool has_layouts () {
        return main_grid.get_children ().length () > 1;
    }
}