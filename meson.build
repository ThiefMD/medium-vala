project('medium', ['vala', 'c'],
  default_options: [
    'default_library=shared',
  ],
  version: '0.0.1'
)

add_project_arguments(['--vapidir', join_paths(meson.current_source_dir(), 'vapi')], language: 'vala')

libmedium_deps = [
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gtk4'),
  dependency('json-glib-1.0'),
  dependency('libsoup-2.4')
]

subdir('vapi')
subdir('src')
subdir('examples')
