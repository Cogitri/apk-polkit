test_src_files = [
    'installFail.d',
    'progressNotification.d',
    'search.d',
    'update.d',
]

foreach src: test_src_files
    test_name = src.underscorify()
    apkd_test_exe = executable(
        'test_apkd_dbus_server_' + test_name + '_exe',
        src,
        dependencies: [libapkd_common_dep, apkd_dep, apkd_dbus_server_lib_dep, apkd_dbus_client_lib_dep, libapkd_test_common_dep],
        d_unittest: true,
        include_directories: include_directories('../../')
    )
    test(
        'test_apkd_dbus_server_' + test_name,
        apkd_test_exe,
        args: [meson.build_root() / 'apk', meson.build_root() / 'abuildRepo', test_preparer, apk, apkd_dbus_exe.full_path()]
        )
endforeach
