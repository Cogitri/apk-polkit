conf = configuration_data()

conf.set('EXTRA_ARGS', '')
conf.set('LIBEXEC_DIR', libexec_dir)
conf.set('PRIVILEGED_GROUP', get_option('privileged-group'))

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