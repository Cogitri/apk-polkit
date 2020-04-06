test_src_files = [
    'getProperty.d',
    'queryAsync.d',
    'querySync.d',
    'setProperty.d',
]

test_runner = find_program('test-runner.sh')

foreach src: test_src_files
    test_name = src.underscorify()
    apkd_dbus_client_test_exe = executable(
        'test_apkd_dbus_client_' + test_name + '_exe',
        [src],
        dependencies: [glibd_dep, apkd_dbus_client_lib_dep, libapkd_common_dep],
        d_unittest: true,
        include_directories: include_directories('../../'),
    )
    test(
        'test_apkd_dbus_client_' + test_name,
        test_runner,
        args: [apkd_dbus_client_test_exe.full_path()],
        env: ['TEMPLATE_PATH=' + join_paths(meson.current_source_dir(), 'apkd_dbus_server.py')],
    )
endforeach
