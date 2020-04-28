test_src_files = [
    'install.d',
    'listAvailable.d',
    'listInstalled.d',
    'listUpgradable.d',
    'search.d',
    'update.d',
]

foreach src: test_src_files
    test_name = src.underscorify()
    apkd_test_exe = executable(
        'test_apkd_dbus_server_' + test_name + '_exe',
        src,
        dependencies: [apkd_test_dep, libapkd_test_common_dep],
        d_unittest: true,
        include_directories: include_directories('../../')
    )
    test(
        'test_apkd_' + test_name,
        apkd_test_exe,
        args: [test_preparer, apk]
        )
endforeach
