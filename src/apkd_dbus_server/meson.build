apkd_dbus_server_lib_src = [
    'DbusServer.d',
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
    dependencies: [apkd_dep, apkd_dbus_server_deps, libapkd_common_dep],
    link_args: ['-shared', link_runtime_shared_arg],
    d_args: '-J' + join_paths(meson.current_source_dir(), '..', '..', 'data'),
)

apkd_dbus_server_lib_dep = declare_dependency(
    link_with: apkd_dbus_server_lib,
    include_directories: src_inc,
    link_args: link_runtime_shared_arg,
    dependencies: [apkd_dep, apkd_dbus_server_deps, libapkd_common_dep],
    compile_args: '-J' + join_paths(meson.current_source_dir(), '..', '..', 'data'),
)

apkd_dbus_exe = executable(
    'apkd-dbus-server',
    [apkd_dbus_server_exe_src],
    install: true,
    install_dir: libexec_dir,
    d_module_versions: d_mod_version,
    include_directories: src_inc,
    dependencies: [apkd_dbus_server_lib_dep ],
)
