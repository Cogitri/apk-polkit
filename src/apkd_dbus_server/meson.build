apkd_dbus_server_src = [
    'main.d',
    'DbusServer.d',
]

executable(
    'apkd-dbus-server',
    [apkd_dbus_server_src],
    install: true,
    install_dir: libexec_dir,
    d_module_versions: d_mod_version,
    include_directories: src_inc,
    dependencies: [apkd_dep, apkd_dbus_server_deps],
)
