test_preparer = find_program('../apkd_test_common/prepare.sh')

test_src_files = [
    'install.d',
    'listAvailable.d',
    'listInstalled.d',
    'listUpgradable.d',
    'update.d',
]

foreach src: test_src_files
    test_name = src.underscorify()
    apkd_test_exe = executable(
        'test_apkd_dbus_server_' + test_name + '_exe',
        src,
        dependencies: [apkd_dep, libapkd_test_common_dep],
        d_unittest: true,
        include_directories: include_directories('../../')
    )
    test(
        'test_apkd_' + test_name,
        apkd_test_exe,
        args: [meson.build_root() / 'apk', meson.build_root() / 'abuildRepo', test_preparer.path()]
        )
endforeach