namespace ViaShell {

    /*
     * Nerd Font codepoints used across the shell.
     * Use Icons.get (Icons.CPU) to turn them into an UTF-8 string.
     */
    public class Icons {

        // Hardware / system
        public const uint32 CPU = 0xF0EE0;              // md-cpu_64_bit
        public const uint32 MEMORY = 0xF035B;           // md-memory
        public const uint32 CHIP = 0xF061A;             // md-chip
        public const uint32 GAUGE = 0xF029A;            // md-gauge
        public const uint32 SPEEDOMETER = 0xF04C5;      // md-speedometer

        // Audio
        public const uint32 VOLUME_HIGH = 0xF057E;      // md-volume_high
        public const uint32 VOLUME_MEDIUM = 0xF0580;    // md-volume_medium
        public const uint32 VOLUME_LOW = 0xF057F;       // md-volume_low
        public const uint32 VOLUME_MUTE = 0xF075F;      // md-volume_mute

        // Display
        public const uint32 BRIGHTNESS = 0xF00DF;       // md-brightness_6
        public const uint32 BRIGHTNESS_LOW = 0xF00DA;   // md-brightness_1
        public const uint32 SUNNY = 0xF0599;            // md-weather_sunny

        // Battery
        public const uint32 BATTERY = 0xF0079;          // md-battery
        public const uint32 BATTERY_10 = 0xF007A;
        public const uint32 BATTERY_20 = 0xF007B;
        public const uint32 BATTERY_30 = 0xF007C;
        public const uint32 BATTERY_40 = 0xF007D;
        public const uint32 BATTERY_50 = 0xF007E;
        public const uint32 BATTERY_60 = 0xF007F;
        public const uint32 BATTERY_70 = 0xF0080;
        public const uint32 BATTERY_80 = 0xF0081;
        public const uint32 BATTERY_90 = 0xF0082;
        public const uint32 BATTERY_CHARGING = 0xF0084; // md-battery_charging
        public const uint32 POWER_PLUG = 0xF06A5;       // md-power_plug

        // Power menu
        public const uint32 POWER = 0xF0902;            // md-power_off
        public const uint32 RESTART = 0xF0709;          // md-restart
        public const uint32 LOGOUT = 0xF0343;           // md-logout
        public const uint32 LOCK = 0xF033E;             // md-lock

        // Power profiles
        public const uint32 LEAF = 0xF032A;             // md-leaf
        public const uint32 BALANCE = 0xF05D1;          // md-scale_balance
        public const uint32 ROCKET = 0xF04C5;           // md-speedometer

        // Media
        public const uint32 MUSIC = 0xF075A;            // md-music
        public const uint32 PLAY = 0xF040A;             // md-play
        public const uint32 PAUSE = 0xF03E4;            // md-pause
        public const uint32 PREVIOUS = 0xF04AE;         // md-skip_previous
        public const uint32 NEXT = 0xF04AD;             // md-skip_next

        // Misc
        public const uint32 CALENDAR = 0xF00ED;         // md-calendar
        public const uint32 BELL = 0xF009A;             // md-bell
        public const uint32 ACCOUNT = 0xF0009;          // md-account_circle
        public const uint32 CHEVRON_LEFT = 0xF0141;     // md-chevron_left
        public const uint32 CHEVRON_RIGHT = 0xF0142;    // md-chevron_right
        public const uint32 CHECK = 0xF012C;             // md-check
        public const uint32 PALETTE = 0xF03D8;           // md-palette

        // Network
        public const uint32 WIFI = 0xF05A9;             // mdi-wifi
        public const uint32 CLIPBOARD = 0xF014C;        // mdi-clipboard-outline

        // Distributions
        public const uint32 DISTRO_VOID = 0xF32E;       // linux-void
        public const uint32 DISTRO_ARCH = 0xF303;       // linux-archlinux
        public const uint32 DISTRO_GENTOO = 0xF30D;     // linux-gentoo
        public const uint32 DISTRO_NIXOS = 0xF313;      // linux-nixos
        public const uint32 DISTRO_MINT = 0xF30E;       // linux-linuxmint
        public const uint32 DISTRO_DEBIAN = 0xF306;     // linux-debian
        public const uint32 DISTRO_ARTIX = 0xF31F;      // linux-artix
        public const uint32 DISTRO_ENDEAVOUR = 0xF322;  // linux-endeavour
        public const uint32 DISTRO_TUX = 0xF31A;        // linux-tux

        public static string get (uint32 codepoint) {
            return ((unichar) codepoint).to_string ();
        }

        public static uint32 battery_for (int level, bool charging) {
            if (charging) {
                return BATTERY_CHARGING;
            }
            if (level >= 90) {
                return BATTERY_90;
            }
            if (level >= 70) {
                return BATTERY_80;
            }
            if (level >= 50) {
                return BATTERY_60;
            }
            if (level >= 30) {
                return BATTERY_40;
            }
            if (level >= 10) {
                return BATTERY_20;
            }

            return BATTERY_10;
        }
    }
}
