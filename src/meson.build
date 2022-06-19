if get_option('shared_lib')
  libtype = 'shared_library'
else
  libtype = 'static_library'
endif

libmedium_sources = [
  'Medium.vala'
]


confh = configuration_data ()
confh.set_quoted('PACKAGE_LOCALE_DIR', join_paths(get_option('prefix'), get_option('datadir'), 'locale'))
confh.set_quoted('GETTEXT_PACKAGE', 'medium')
confh.set_quoted('VERSION', meson.project_version())
configure_file(output : 'config.h',
  configuration : confh)

inc_libh = include_directories ('.')
inc_libh_dep = declare_dependency (include_directories : inc_libh)

libmedium = build_target('medium',
    sources: libmedium_sources,
    dependencies: libmedium_deps,
    vala_args: [
        '--pkg=posix',
        '--vapidir=' + meson.source_root() + '/vapi'
        ],
    target_type: libtype,
    vala_header: 'medium.h',
    vala_vapi: 'medium.vapi',
    c_args: [ '-include', meson.current_build_dir() + '/config.h', '-w'],
    install_dir: [true, true, true],
    install: true,
)

libmedium_dep = declare_dependency(
  include_directories: include_directories('.'),
            link_with: libmedium,
)

pkg = import('pkgconfig')
pkg.generate(
    libraries: libmedium,
      version: meson.project_version(),
         name: 'medium',
  description: 'Publish to Medium.com.',
)
