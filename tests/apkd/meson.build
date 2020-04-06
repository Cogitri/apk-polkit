test_preparer = find_program('prepare.sh')

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
        'test_apkd_' + test_name + '_exe',
        ['testlib.d', src],
        dependencies: [apkd_dep, apk_toolsd_dep],
        d_unittest: true,
        include_directories: include_directories('../../')
    )
    test(
        'test_apkd_' + test_name,
        apkd_test_exe,
        args: [meson.build_root() / 'apk', meson.build_root() / 'abuildRepo', test_preparer.path()]
        )
endforeach