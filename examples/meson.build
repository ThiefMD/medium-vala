if get_option('enable_examples')

  example_deps = libmedium_deps + [ libmedium_dep ]

  executable('hello-medium', 'hello-medium.vala',
    dependencies: example_deps,
    vala_args: [
        '--pkg=posix',
        '--vapidir=' + meson.source_root() + '/vapi'
        ],
    install: false
  )

endif
