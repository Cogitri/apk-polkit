project(
    'apk-polkit',
    ['c', 'd'],
    license: 'GPL-3.0-or-later',
    meson_version: '>=0.54',
    version: '0.2.1',
)

project_soversion = 0

d_mod_version = []

prefix = get_option('prefix')
libexec_dir = join_paths(prefix, get_option('libexecdir'), 'apk-polkit')
sysconf_dir = join_paths(prefix, get_option('sysconfdir'))
include_dir = join_paths(prefix, get_option('includedir'), 'd', 'apk-polkit')
data_dir = join_paths(prefix, get_option('datadir'))

gio_unix_dep = dependency('gio-unix-2.0')
glibd_dep = dependency('glibd-2.0')
polkit_gobjectd_dep = dependency('polkit-gobjectd-1')
apk_toolsd_dep = dependency('apk-toolsd', version: '>=2.10.5.6')
dbus_dep = dependency('dbus-1')
# Required to translate (and install!) polkit policy
find_program('xgettext')

apk_tools_dep = dependency('apk', required: false)
use_static_apk_tools = false

if not apk_tools_dep.found()
    apk_tools_proj = subproject(
        'apk-tools',
        default_options: [
            'default_library=static',
            'docs=disabled',
            'lua=disabled',
        ],
    )
    apk_tools_lib = [apk_tools_proj.get_variable('libapk')]
    apk_tools_dep = declare_dependency(
        link_whole: apk_tools_lib,
        dependencies: dependency('openssl'),
    )
    use_static_apk_tools = true
endif


dbus_service_dir = dbus_dep.get_pkgconfig_variable('system_bus_services_dir')
dbus_config_dir = join_paths(data_dir, 'dbus-1', 'system.d')
dbus_interface_dir = dbus_dep.get_pkgconfig_variable('interfaces_dir')
polkit_policy_dir = dependency('polkit-gobject-1').get_pkgconfig_variable('policydir')

apkd_dbus_client_deps = [gio_unix_dep]
apkd_dbus_server_deps = [glibd_dep, polkit_gobjectd_dep]
apkd_deps = [apk_toolsd_dep]

src_inc = include_directories('src')

vcs_tag = run_command('git', 'rev-parse', '--short', 'HEAD').stdout().strip()
if vcs_tag == ''
    apkd_version = meson.project_version()
else
    apkd_version = meson.project_version() + '-@0@'.format (vcs_tag)
endif

compiler_id = meson.get_compiler('d').get_id()

i18n = import('i18n')

conf = configuration_data()

conf.set('EXTRA_ARGS', '')
conf.set('LIBEXEC_DIR', libexec_dir)
conf.set('PRIVILEGED_GROUP', get_option('privileged-group'))
conf.set('APKD_VERSION', apkd_version)

subdir('data')
subdir('po')
subdir('src')
subdir('tests')
