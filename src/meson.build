sources = files(
  'main.vala',
  'panel.vala',
  'widgets/clock.vala',
  'widgets/cpu.vala',
  'widgets/memory.vala',
  'widgets/volume.vala',
  'widgets/brightness.vala',
  'widgets/battery.vala',
  'utils/system_info.vala',
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
    math_dep,
  ],
  install: true,
  vala_args: [
    '--pkg=gtk4',
    '--pkg=gtk4-layer-shell-0',
    '--pkg=posix',
  ],
)
