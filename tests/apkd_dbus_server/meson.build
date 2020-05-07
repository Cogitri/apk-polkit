test_src_files = [
    'addAndDelete.d',
    'deleteRequiredPackage.d',
    'install.d',
    'installFail.d',
    'progressNotification.d',
    'search.d',
    'searchFileOwner.d',
    'update.d',
]

foreach src: test_src_files
    test_name = src.underscorify()
    apkd_test_exe = executable(
        'test_apkd_dbus_server_' + test_name + '_exe',
        src,
        dependencies: [libapkd_common_dep, apkd_dep, apkd_dbus_server_lib_dep, apkd_dbus_client_lib_dep, libapkd_test_common_dep],
        d_unittest: true,
        include_directories: include_directories('../../'),
        d_args: enable_asserts_compile_arg,
    )
    test(
        'test_apkd_dbus_server_' + test_name,
        apkd_test_exe,
        args: [test_preparer, apk, apkd_dbus_test_exe.full_path()]
        )
endforeach
