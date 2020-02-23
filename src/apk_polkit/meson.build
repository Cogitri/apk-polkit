main_src = [
    'main.d'
]

apk_polkit_helper_exe = executable(
    'apk-polkit-helper',
    [main_src],
    install: true,
    dependencies: apk_polkit_deps,
    install_dir: libexec_dir,
)