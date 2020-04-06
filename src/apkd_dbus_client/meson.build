apkd_dbus_client_lib_src = [
    'DbusClient.d',
    'DbusClientC.d',
]

apkd_dbus_client_c_headers = [
    'apkd-dbus-client.h',
]

install_headers(
    apkd_dbus_client_c_headers,
    subdir: 'apk-polkit'
)

install_headers(
    apkd_dbus_client_lib_src,
    subdir: 'd/apk-polkit/apk_dbus_client'
)

apkd_dbus_client_lib = library(
    'apkd-dbus-client',
    apkd_dbus_client_lib_src,
    install: true,
    d_module_versions: d_mod_version,
    include_directories: src_inc,
    dependencies: [apkd_dbus_client_deps, apkd_dep, libapkd_common_dep],
    link_args: ['-shared', link_runtime_shared_arg],
    d_args: '-J' + join_paths(meson.current_source_dir(), '..', '..', 'data'),
)

apkd_dbus_client_lib_dep = declare_dependency(
    link_with: apkd_dbus_client_lib,
    include_directories: src_inc,
    link_args: link_runtime_shared_arg,
    dependencies: [apkd_dbus_client_deps, apkd_dep]
)

pkgc.generate(
    apkd_dbus_client_lib,
    name: 'apkd-dbus-client-0',
    subdirs: 'd/apk-polkit',
    version: meson.project_version(),
    requires: apkd_dbus_client_deps,
)

apkd_dbus_client_exe_src = [
    'main.d',
    'Options.d',
]

executable(
    'apkd',
    apkd_dbus_client_exe_src,
    install: true,
    d_module_versions: d_mod_version,
    include_directories: src_inc,
    dependencies: [apkd_dbus_client_lib_dep],
    d_args: '-J' + join_paths(meson.current_source_dir(), '..', '..', 'data'),
)

apkd_test = executable(
    'apkd_test',
    apkd_dbus_client_exe_src,
    d_module_versions: d_mod_version,
    include_directories: src_inc,
    dependencies: [apkd_dbus_client_lib_dep],
    d_unittest: true,
    d_args: '-J' + join_paths(meson.current_source_dir(), '..', '..', 'data'),
)

test('Test apkd_dbus_client', apkd_test)