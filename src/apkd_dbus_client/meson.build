apkd_dbus_client_lib_src = [
    'DbusClient.d',
]

apkd_dbus_client_lib = library(
    'apkd-dbus-client',
    apkd_dbus_client_lib_src,
    install: true,
    d_module_versions: d_mod_version,
    include_directories: src_inc,
    dependencies: apkd_dbus_client_deps,
    link_args: ['-shared', link_runtime_shared_arg],
)

apkd_dbus_client_lib_dep = declare_dependency(
    link_with: apkd_dbus_client_lib,
    include_directories: src_inc,
    link_args: link_runtime_shared_arg,
    dependencies: [apkd_dbus_client_deps]
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
)

apkd_test = executable(
    'apkd_test',
    apkd_dbus_client_exe_src,
    d_module_versions: d_mod_version,
    include_directories: src_inc,
    dependencies: [apkd_dbus_client_lib_dep],
    d_unittest: true,
)

test('Test apkd_dbus_client', apkd_test)