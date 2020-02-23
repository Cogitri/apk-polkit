project(
    'apk-polkit',
    'd',
    license: 'GPL-3.0-or-later',
    meson_version: '>=0.50',
    version: '0.0.1',
)

project_soversion = 0

d_mod_version = []

glibd_dep = dependency('glibd-2.0')
polkit_gobjectd_dep = dependency('polkit-gobjectd-1')
apk_toolsd_dep = dependency('apk-toolsd')
openssld_dep = dependency('openssld')

apk_polkit_deps = [glibd_dep, polkit_gobjectd_dep]
libapk_helper_deps = [apk_toolsd_dep, openssld_dep]

src_inc = include_directories('src')

prefix = get_option('prefix')
libexec_dir = join_paths(prefix, get_option('libexecdir'), 'apk-polkit')
sysconf_dir = join_paths(prefix, get_option('sysconfdir'))
include_dir = join_paths(prefix, get_option('includedir'), 'd', 'apk-polkit')

vcs_tag = run_command('git', 'rev-parse', '--short', 'HEAD').stdout().strip()
if vcs_tag == ''
    corecollector_version = meson.project_version()
else
    corecollector_version = meson.project_version() + '-@0@'.format (vcs_tag)
endif

compiler_id = meson.get_compiler('d').get_id()

link_runtime_shared_arg = []

if compiler_id == 'llvm'
    link_runtime_shared_arg = ['-link-defaultlib-shared']
elif compiler_id == 'dmd'
    link_runtime_shared_arg = ['-defaultlib=phobos2', '-debuglib=phobos2']
elif compiler_id == 'gcc'
    link_runtime_shared_arg = ['-shared-libphobos']
endif

subdir('src')
