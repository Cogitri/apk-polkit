globals_d = configure_file(
    input: 'globals.d',
    output: 'globals.d',
    configuration: conf,
)

common_src = [
    'ApkDatabaseOperations.d',
    'SysLogger.d',
    globals_d,
]

libapkd_common = static_library(
    'apkd_common',
    common_src,
    pic: true,
    include_directories: src_inc,
)

libapkd_common_dep = declare_dependency(
    link_with: libapkd_common,
)