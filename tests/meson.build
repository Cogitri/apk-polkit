test_preparer = find_program('apkd_test_common/prepare.sh').path()

if not use_static_apk_tools
    apk = find_program('apk', required: false).path()
else
    apk = apk_tools_proj.get_variable('apk_exe').full_path()
endif

subdir('apkd_test_common')
subdir('apkd')
subdir('apkd_dbus_server')
