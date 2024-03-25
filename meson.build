#
# OUTLINE:
#
# The top-level meson.build file (this file) handles general logic for build options,
# generation of config.h (which is put in the build directory, not the source root
# like the previous, autoconf-based build system did), the mechanism for header
# generation, and the few global C++ compiler arguments that are added to all targets in Lix.
#
# src/meson.build coordinates each of Lix's subcomponents (the lib dirs in ./src),
# which each have their own meson.build. Lix's components depend on each other,
# so each of `src/lib{util,store,fetchers,expr,main,cmd}/meson.build` rely on variables
# set in earlier `meson.build` files. Each of these also defines the install targets for
# their headers.
#
# src/meson.build also collects the miscellaneous source files that are in further subdirectories
# that become part of the final Nix command (things like `src/nix-build/*.cc`).
#
# Finally, src/nix/meson.build defines the Nix command itself, relying on all prior meson files.

project('lix', 'cpp',
  version : run_command('bash', '-c', 'echo -n $(cat ./.version)$VERSION_SUFFIX', check : true).stdout().strip(),
  default_options : [
    'cpp_std=c++2a',
    # TODO(Qyriad): increase the warning level
    'warning_level=1',
    'debug=true',
    'optimization=2',
  ],
)

fs = import('fs')

prefix = get_option('prefix')
# For each of these paths, assume that it is relative to the prefix unless
# it is already an absolute path (which is the default for store-dir, state-dir, and log-dir).
path_opts = [
  # Meson built-ins.
  'datadir',
  'sysconfdir',
  'bindir',
  'mandir',
  'libdir',
  'includedir',
  # Homecooked Lix directories.
  'store-dir',
  'state-dir',
  'log-dir',
]
foreach optname : path_opts
  varname = optname.replace('-', '_')
  path = get_option(optname)
  if fs.is_absolute(path)
    set_variable(varname, path)
  else
    set_variable(varname, prefix / path)
  endif
endforeach

cxx = meson.get_compiler('cpp')

host_system = host_machine.cpu_family() + '-' + host_machine.system()
message('canonical Nix system name:', host_system)

is_linux = host_machine.system() == 'linux'
is_x64 = host_machine.cpu_family() == 'x86_64'

deps = [ ]
configdata = { }

#
# Dependencies
#

boehm = dependency('bdw-gc', required : get_option('gc'))
if boehm.found()
  deps += boehm
endif
configdata += {
  'HAVE_BOEHMGC': boehm.found().to_int(),
}

boost = dependency('boost', required : true, modules : ['context', 'coroutine', 'container'])
deps += boost

# cpuid only makes sense on x86_64
cpuid_required = is_x64 ? get_option('cpuid') : false
cpuid = dependency('libcpuid', 'cpuid', required : cpuid_required)
configdata += {
  'HAVE_LIBCPUID': cpuid.found().to_int(),
}
deps += cpuid

# seccomp only makes sense on Linux
seccomp_required = is_linux ? get_option('seccomp-sandboxing') : false
seccomp = dependency('libseccomp', 'seccomp', required : seccomp_required)
configdata += {
  'HAVE_SECCOMP': seccomp.found().to_int(),
}

libarchive = dependency('libarchive', required : true)
deps += libarchive

brotli = [
  dependency('libbrotlicommon', required : true),
  dependency('libbrotlidec', required : true),
  dependency('libbrotlienc', required : true),
]
deps += brotli

openssl = dependency('libcrypto', 'openssl', required : true)
deps += openssl

aws_sdk = dependency('aws-cpp-sdk-core', required : false)
if aws_sdk.found()
  # The AWS pkg-config adds -std=c++11.
  # https://github.com/aws/aws-sdk-cpp/issues/2673
  aws_sdk = aws_sdk.partial_dependency(
    compile_args : false,
    includes : true,
    link_args : true,
    links : true,
    sources : true,
  )
  deps += aws_sdk
  s = aws_sdk.version().split('.')
  configdata += {
    'AWS_VERSION_MAJOR': s[0].to_int(),
    'AWS_VERSION_MINOR': s[1].to_int(),
    'AWS_VERSION_PATCH': s[2].to_int(),
  }
  aws_sdk_transfer = dependency('aws-cpp-sdk-transfer', required : true).partial_dependency(
    compile_args : false,
    includes : true,
    link_args : true,
    links : true,
    sources : true,
  )
endif

aws_s3 = dependency('aws-cpp-sdk-s3', required : false)
if aws_s3.found()
  # The AWS pkg-config adds -std=c++11.
  # https://github.com/aws/aws-sdk-cpp/issues/2673
  aws_s3 = aws_s3.partial_dependency(
    compile_args : false,
    includes : true,
    link_args : true,
    links : true,
    sources : true,
  )
  deps += aws_s3
endif

configdata += {
  'ENABLE_S3': aws_s3.found().to_int(),
}

sqlite = dependency('sqlite3', 'sqlite', version : '>=3.6.19', required : true)
deps += sqlite

sodium = dependency('libsodium', 'sodium', required : true)
deps += sodium

curl = dependency('libcurl', 'curl', required : true)
deps += curl

editline = dependency('libeditline', 'editline', version : '>=1.14', required : true)
deps += editline

lowdown = dependency('lowdown', version : '>=0.9.0', required : true)
deps += lowdown

rapidcheck = dependency('rapidcheck', required : false)
deps += rapidcheck

gtest = dependency('gtest', required : false)
deps += gtest

#
# Build-time tools
#
bash = find_program('bash')

# Used to workaround https://github.com/mesonbuild/meson/issues/2320 in src/nix/meson.build.
installcmd = find_program('install')

sandbox_shell = get_option('sandbox-shell')
# Consider it required if we're on Linux and the user explicitly specified a non-default value.
sandbox_shell_required = sandbox_shell != 'busybox' and host_machine.system() == 'linux'
# NOTE(Qyriad): package.nix puts busybox in buildInputs for Linux.
# Most builds should not require setting this.
busybox = find_program(sandbox_shell, required : sandbox_shell_required, native : false)
if not busybox.found() and host_machine.system() == 'linux' and sandbox_shell_required
  warning('busybox not found and other sandbox shell was specified')
  warning('a sandbox shell is recommended on Linux -- configure with -Dsandbox-shell=/path/to/shell to set')
endif
# FIXME(Qyriad): the autoconf system checks that busybox has the "standalone" feature, indicating
# that busybox sh won't run busybox applets as builtins (which would break our sandbox).

lsof = find_program('lsof')
bison = find_program('bison')
flex = find_program('flex')

# This is how Nix does generated headers...
# FIXME(Qyriad): do we really need to use the shell for this?
gen_header = generator(
  bash,
  arguments : [
    '-c',
    'echo \'R"__NIX_STR(\' | cat - @INPUT@ && echo \')__NIX_STR"\'',
  ],
  capture : true,
  output : '@PLAINNAME@.gen.hh',
)

#
# Configuration
#

run_command('ln', '-s',
  meson.project_build_root() / '__nothing_link_target',
  meson.project_build_root() / '__nothing_symlink',
  check : true,
)
can_link_symlink = run_command('ln',
  meson.project_build_root() / '__nothing_symlink',
  meson.project_build_root() / '__nothing_hardlink',
  check : false,
).returncode() == 0
run_command('rm', '-f',
  meson.project_build_root() / '__nothing_symlink',
  meson.project_build_root() / '__nothing_hardlink',
  check : true,
)
summary('can hardlink to symlink', can_link_symlink, bool_yn : true)
configdata += { 'CAN_LINK_SYMLINK': can_link_symlink.to_int() }


# Check for each of these functions, and create a define like `#define HAVE_LCHOWN 1`.
check_funcs = [
  'lchown',
  'lutimes',
  'pipe2',
  'posix_fallocate',
  'statvfs',
  'strsignal',
  'sysconf',
]
foreach funcspec : check_funcs
  define_name = 'HAVE_' + funcspec.underscorify().to_upper()
  define_value = cxx.has_function(funcspec).to_int()
  configdata += {
    define_name: define_value,
  }
endforeach

config_h = configure_file(
  configuration : {
    'PACKAGE_NAME': '"' + meson.project_name() + '"',
    'PACKAGE_VERSION': '"' + meson.project_version() + '"',
    'PACKAGE_TARNAME': '"' + meson.project_name() + '"',
    'PACKAGE_STRING': '"' + meson.project_name() + ' ' + meson.project_version() + '"',
    'HAVE_STRUCT_DIRENT_D_TYPE': 1, # FIXME: actually check this for solaris
    'SYSTEM': '"' + host_system + '"',
  } + configdata,
  output : 'config.h',
)

install_headers(config_h, subdir : 'nix')

add_project_arguments(
  # TODO(Qyriad): Yes this is how the autoconf+Make system did it.
  # It would be nice for our headers to be idempotent instead.
  '-include', 'config.h',
  '-Wno-deprecated-declarations',
  '-Wimplicit-fallthrough',
  '-Werror=switch',
  '-Werror=switch-enum',
  language : 'cpp',
)

add_project_link_arguments('-pthread', language : 'cpp')
if cxx.get_linker_id() in ['ld.bfd', 'ld.gold']
  add_project_link_arguments('-Wl,--no-copy-dt-needed-entries', language : 'cpp')
endif

subdir('src')