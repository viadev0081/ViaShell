project(
    'viashell', 'vala', 'c',
    version: '0.1.0',
    meson_version: '>= 0.62.0',
)

gtk4_dep = dependency('gtk4', version: '>= 4.6')
gtk4_layer_shell_dep = dependency('gtk4-layer-shell-0', required: true)
math_dep = meson.get_compiler('c').find_library('m', required: true)

subdir('src')
