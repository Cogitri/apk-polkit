configure_file(
    input: 'dev.Cogitri.apkPolkit.rules.in',
    output: 'dev.Cogitri.apkPolkit.rules',
    configuration: conf,
    install: true,
    install_dir: 'share/polkit-1/rules.d',
)

configure_file(
    input: 'dev.Cogitri.apkPolkit.Helper.service.in',
    output: 'dev.Cogitri.apkPolkit.Helper.service',
    configuration: conf,
    install: true,
    install_dir: dbus_service_dir,
)

i18n.merge_file(
    input: 'dev.Cogitri.apkPolkit.policy.in',
    output: 'dev.Cogitri.apkPolkit.policy',
    install: true,
    install_dir: polkit_policy_dir,
    po_dir: '../po',
)

install_data(
    'dev.Cogitri.apkPolkit.Helper.conf',
    install_dir: dbus_config_dir,
)

install_data(
    'dev.Cogitri.apkPolkit.interface',
    install_dir: dbus_interface_dir,
    rename: 'dev.cogitri.apkPolkit.xml',
)

gnome = import('gnome')

dbus_interface_src = gnome.gdbus_codegen(
    'apkd-dbus-client',
    sources: 'dev.Cogitri.apkPolkit.interface',
    interface_prefix: 'dev.Cogitri.apkPolkit.',
    namespace: 'Apkd',
    install_header: true,
    install_dir: join_paths(get_option('includedir'), 'apk-polkit'),
)

metainfo_file = i18n.merge_file ('metainfo-file',
    input: 'dev.Cogitri.apkPolkit.metainfo.xml.in',
    output: 'dev.Cogitri.apkPolkit.metainfo.xml',
    po_dir: meson.current_source_dir() / '..' / 'po',
    install: true,
    install_dir: join_paths (data_dir, 'metainfo'),
)

appstream_util = find_program('appstream-util', required: false)

if appstream_util.found()
    test(
        'validate-metainfo', appstream_util,
        args: [
            'validate', '--nonet', metainfo_file.full_path(),
        ],
    )
endif
