namespace ViaShell {

    public class Distro : GLib.Object {

        public string id     { get; private set; }
        public string name   { get; private set; }
        public uint32 glyph  { get; private set; }
        public string colour { get; private set; }

        public Distro (
            string id,
            string name,
            uint32 glyph,
            string colour
        ) {
            this.id = id;
            this.name = name;
            this.glyph = glyph;
            this.colour = colour;
        }

        public static Distro detect () {
            string? raw_id = GLib.Environment.get_os_info ("ID");
            string? raw_like = GLib.Environment.get_os_info ("ID_LIKE");
            string? raw_name = GLib.Environment.get_os_info ("NAME");
            string? raw_pretty = GLib.Environment.get_os_info ("PRETTY_NAME");

            string id = raw_id != null ? raw_id.down ().strip () : "";
            string like = raw_like != null ? raw_like.down ().strip () : "";
            string name = raw_name != null ? raw_name.strip () : "";
            string pretty = raw_pretty != null ? raw_pretty.strip () : "";

            Distro distro = map_id (id);
            if (distro == null && like != "") {
                foreach (var token in like.split_set (" \t")) {
                    if (token.strip () == "") {
                        continue;
                    }

                    distro = map_id (token.strip ());

                    if (distro != null) {
                        break;
                    }
                }
            }

            if (distro == null) {
                distro = new Distro ("linux", "Linux", Icons.DISTRO_TUX, "#cdd6f4");
            }

            if (pretty != "") {
                distro.name = pretty;
            }
            else if (name != "") {
                distro.name = name;
            }

            return distro;
        }

        private static Distro? map_id (string id) {
            switch (id) {
                case "void":
                    return new Distro ("void", "Void Linux", Icons.DISTRO_VOID, "#a6e3a1");

                case "arch":
                    return new Distro ("arch", "Arch Linux", Icons.DISTRO_ARCH, "#89b4fa");
                case "archlinux":
                    return new Distro ("arch", "Arch Linux", Icons.DISTRO_ARCH, "#89b4fa");

                case "gentoo":
                    return new Distro ("gentoo", "Gentoo", Icons.DISTRO_GENTOO, "#cba6f7");

                case "nixos":
                    return new Distro ("nixos", "NixOS", Icons.DISTRO_NIXOS, "#89b4fa");

                case "linuxmint":
                    return new Distro ("mint", "Linux Mint", Icons.DISTRO_MINT, "#a6e3a1");
                case "mint":
                    return new Distro ("mint", "Linux Mint", Icons.DISTRO_MINT, "#a6e3a1");

                case "debian":
                    return new Distro ("debian", "Debian", Icons.DISTRO_DEBIAN, "#f38ba8");

                case "artix":
                    return new Distro ("artix", "Artix", Icons.DISTRO_ARTIX, "#94e2d5");

                case "endeavouros":
                    return new Distro ("endeavouros", "EndeavourOS", Icons.DISTRO_ENDEAVOUR, "#cba6f7");
                case "endeavour":
                    return new Distro ("endeavouros", "EndeavourOS", Icons.DISTRO_ENDEAVOUR, "#cba6f7");

                default:
                    return null;
            }
        }
    }
}
