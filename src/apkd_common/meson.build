globals_d = configure_file(
    input: 'globals.d',
    output: 'globals.d',
    configuration: conf,
)

common_src = [
    'gettext.d',
    'SysLogger.d',
    globals_d,
]

libapkd_common = library(
    'apkd_common',
    common_src,
    install: true,
    include_directories: src_inc,
    version: meson.project_version(),
)

libapkd_common_dep = declare_dependency(
    link_with: libapkd_common,
)
