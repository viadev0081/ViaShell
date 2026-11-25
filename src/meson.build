sources = files(
    'main.vala',
    'panel.vala',
    'utils/icons.vala',
    'utils/distro.vala',
    'utils/system_info.vala',
    'utils/hyprland-and-niri.vala',
    'utils/sway.vala',
    'utils/wifi.vala',
    'utils/ini_config.vala',
    'utils/theme.vala',
    'utils/media.vala',
    'utils/notifications.vala',
    'widgets/panel_button.vala',
    'widgets/workspaces.vala',
    'widgets/calendar.vala',
    'widgets/clock.vala',
    'widgets/system.vala',
    'widgets/menu.vala',
)

install_data(
    '../style/style.css',
    install_dir: get_option('datadir') / 'viashell'
)

executable('viashell',
    sources,
    dependencies: [
        gtk4_dep,
        gtk4_layer_shell_dep,
        json_glib_dep,
        math_dep,
    ],
    install: true,
    vala_args: [
        '--pkg=gtk4',
        '--pkg=gtk4-layer-shell-0',
        '--pkg=json-glib-1.0',
        '--pkg=posix',
    ],
)
