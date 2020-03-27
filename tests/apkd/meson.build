test_preparer = find_program('prepare.sh')

test_src_files = [
    'install.d',
    'listAvailable.d',
    'listInstalled.d',
]

testlib = static_library(
    'testlib',
    'testlib.d',
    dependencies: apk_toolsd_dep,
)

foreach src: test_src_files
    test_name = src.underscorify()
    apkd_test_exe = executable(
        'test_' + test_name + '_exe',
        [src],
        dependencies: [apkd_dep, apk_toolsd_dep],
        d_unittest: true,
        link_with: testlib,
        include_directories: include_directories('../../')
    )
    test(
        'test_' + test_name,
        apkd_test_exe,
        args: [meson.build_root() / 'apk', meson.build_root() / 'abuildRepo', test_preparer.path()]
        )
endforeach