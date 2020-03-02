lib_src = [
    'ApkDataBase.d'
]

libapk_helper_lib = library(
    'libapk-helper',
    [lib_src],
    install: true,
    version: meson.project_version(),
    soversion: project_soversion,
    d_module_versions: d_mod_version,
    include_directories: src_inc,
    dependencies: libapk_helper_deps,
    link_args: ['-shared', link_runtime_shared_arg],
)

libapk_helper_dep = declare_dependency(
    link_with: libapk_helper_lib,
    include_directories: src_inc,
    link_args: link_runtime_shared_arg,
)

pkgc.generate(
    libapk_helper_lib,
    name: 'apk-polkit-0',
    subdirs: 'd/apk-polkit',
    version: meson.project_version(),
)

install_headers(
    lib_src,
    subdir: 'd/apk-polkit/apk_polkit',
)