lib_src = [
    'ApkDataBase.d',
    'ApkPackage.d',
    'exceptions.d',
    'functions.d',
]

apkd_lib = library(
    'apkd',
    [lib_src],
    install: true,
    d_module_versions: d_mod_version,
    include_directories: src_inc,
    dependencies: [apk_toolsd_dep, libapkd_common_dep, apk_tools_dep],
    version: meson.project_version(),
)

apkd_test_lib = library(
    'apkd_test',
    [lib_src],
    d_module_versions: 'testing',
    include_directories: src_inc,
    dependencies: [apk_toolsd_dep, libapkd_common_dep, apk_tools_dep],
    version: meson.project_version(),
)

apkd_dep = declare_dependency(
    link_with: apkd_lib,
    include_directories: src_inc,
    dependencies: apk_toolsd_dep.partial_dependency(compile_args: true),
)

apkd_test_dep = declare_dependency(
    link_with: apkd_test_lib,
    include_directories: src_inc,
    dependencies: apk_toolsd_dep.partial_dependency(compile_args: true),
)

pkgc.generate(
    apkd_lib,
    name: 'apkd-0',
    subdirs: 'd/apk-polkit',
    version: meson.project_version(),
    requires: apk_toolsd_dep,
)


install_headers(
    lib_src,
    subdir: 'd/apk-polkit/apkd',
)
