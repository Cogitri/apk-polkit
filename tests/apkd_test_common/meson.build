common_test_src = [
    'testlib.d',
    'apkd_dbus_client.d',
]

libapkd_test_common = shared_library(
    'apkd_tests_common',
    common_test_src,
    include_directories: src_inc,
    dependencies: [apk_toolsd_dep, apk_tools_dep, glibd_dep],
)

libapkd_test_common_dep = declare_dependency(
    link_with: libapkd_test_common,
    dependencies: [apk_toolsd_dep, apk_tools_dep, glibd_dep],
)
