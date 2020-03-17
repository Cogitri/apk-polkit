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
    dependencies: [apkd_deps, libapkd_common_dep],
    link_args: ['-shared', link_runtime_shared_arg],
)

apkd_dep = declare_dependency(
    link_with: apkd_lib,
    include_directories: src_inc,
    link_args: link_runtime_shared_arg,
    dependencies: apkd_deps,
)

pkgc.generate(
    apkd_lib,
    name: 'apkd-0',
    subdirs: 'd/apk-polkit',
    version: meson.project_version(),
    requires: apkd_deps,
)


install_headers(
    lib_src,
    subdir: 'd/apk-polkit/apkd',
)