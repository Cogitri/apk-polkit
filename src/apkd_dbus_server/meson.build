apkd_dbus_server_lib_src = [
    'DbusMethodRegistrar.d',
    'DbusServer.d',
    'OperationErrorTranslator.d',
    'Polkit.d',
]

apkd_dbus_server_exe_src = [
    'main.d',
    'Options.d',
]

install_headers(
    apkd_dbus_server_lib_src,
    subdir: 'd/apk-polkit/apk_dbus_server'
)

apkd_dbus_server_lib = library(
    'apkd-dbus-server',
    apkd_dbus_server_lib_src,
    install: true,
    d_module_versions: d_mod_version,
    include_directories: src_inc,
    dependencies: [
        apkd_dep,
        apkd_dbus_server_deps,
        libapkd_common_dep,
    ],
    d_args: '-J' + join_paths(meson.current_source_dir(), '..', '..', 'data'),
)

apkd_dbus_server_lib_dep = declare_dependency(
    link_with: apkd_dbus_server_lib,
    include_directories: src_inc,
    dependencies: [
        apkd_dep.partial_dependency(compile_args: true),
        apkd_dbus_server_deps,
        libapkd_common_dep.partial_dependency(compile_args: true),
    ],
    compile_args: '-J' + join_paths(meson.current_source_dir(), '..', '..', 'data'),
    version: meson.project_version(),
)

apkd_dbus_server_test_lib = library(
    'apkd-dbus-server-test',
    apkd_dbus_server_lib_src,
    install: false,
    d_module_versions: d_mod_version,
    include_directories: src_inc,
    dependencies: [
        apkd_test_dep,
        apkd_dbus_server_deps,
        libapkd_common_dep,
    ],
    d_args: '-J' + join_paths(meson.current_source_dir(), '..', '..', 'data'),
)

apkd_dbus_server_lib_test_dep = declare_dependency(
    link_with: apkd_dbus_server_test_lib,
    include_directories: src_inc,
    dependencies: [
        apkd_dep.partial_dependency(compile_args: true),
        apkd_dbus_server_deps,
        libapkd_common_dep.partial_dependency(compile_args: true),
    ],
    compile_args: '-J' + join_paths(meson.current_source_dir(), '..', '..', 'data'),
    version: meson.project_version(),
)

apkd_dbus_exe = executable(
    'apkd-dbus-server',
    [apkd_dbus_server_exe_src],
    install: true,
    install_dir: libexec_dir,
    d_module_versions: d_mod_version,
    include_directories: src_inc,
    dependencies: [apkd_dbus_server_lib_dep, libapkd_common_dep],
)

apkd_dbus_test_exe = executable(
    'apkd-dbus-server-test',
    [apkd_dbus_server_exe_src],
    install: false,
    install_dir: libexec_dir,
    d_module_versions: d_mod_version,
    include_directories: src_inc,
    dependencies: [apkd_dbus_server_lib_test_dep, libapkd_common_dep],
)

apkd_dbus_client_lib_src = [
    dbus_interface_src,
]

apkd_dbus_client_lib = library(
    'apkd-dbus-client',
    apkd_dbus_client_lib_src,
    install: true,
    dependencies: [apkd_dbus_client_deps],
    version: meson.project_version(),
)

apkd_dbus_client_lib_dep = declare_dependency(
    link_with: apkd_dbus_client_lib,
    include_directories: src_inc,
)

pkgc.generate(
    apkd_dbus_client_lib,
    name: 'apkd-dbus-client-0',
    subdirs: 'apk-polkit',
    version: meson.project_version(),
)
