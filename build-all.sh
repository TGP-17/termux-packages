#!/bin/bash
# build-all.sh - script to build all packages from all enabled repositories,
# first from packages, then from root-packages, then from x11-packages,
# with the order of building within each group of packages from each repository
# set by the order of directory entries returned by the readdir() system call
# that your "find" command invokes within its source code
# on your specific environment, operating system, and filesystem format
# (usually arbitrary)

set -e -u -o pipefail

TERMUX_SCRIPTDIR=$(cd "$(realpath "$(dirname "$0")")"; pwd)

# Store pid of current process in a file for docker__run_docker_exec_trap
source "$TERMUX_SCRIPTDIR/scripts/utils/docker/docker.sh"; docker__create_docker_exec_pid_file


if [ "$(uname -o)" = "Android" ] || [ -e "/system/bin/app_process" ]; then
	echo "On-device execution of this script is not supported."
	exit 1
fi

# Read settings from .termuxrc if existing
test -f "$HOME"/.termuxrc && . "$HOME"/.termuxrc
: ${TERMUX_TOPDIR:="$HOME/.termux-build"}
: ${TERMUX_ARCH:="aarch64"}
: ${TERMUX_DEBUG_BUILD:=""}
: ${TERMUX_INSTALL_DEPS:=""}

_show_usage() {
	echo "Usage: ./build-all.sh [-a ARCH] [-d] [-i] [-o DIR]"
	echo "Build all packages."
	echo "  -a The architecture to build for: aarch64(default), arm, i686, x86_64 or all."
	echo "  -d Build with debug symbols."
	echo "  -i Build dependencies."
	echo "  -o Specify deb directory. Default: debs/."
	exit 1
}

while getopts :a:hdio: option; do
case "$option" in
	a) TERMUX_ARCH="$OPTARG";;
	d) TERMUX_DEBUG_BUILD='-d';;
	i) TERMUX_INSTALL_DEPS='-i';;
	o) TERMUX_OUTPUT_DIR="$(realpath -m "$OPTARG")";;
	h) _show_usage;;
	*) _show_usage >&2 ;;
esac
done
shift $((OPTIND-1))
if [ "$#" -ne 0 ]; then _show_usage; fi

if [[ ! "$TERMUX_ARCH" =~ ^(all|aarch64|arm|i686|x86_64)$ ]]; then
	echo "ERROR: Invalid arch '$TERMUX_ARCH'" 1>&2
	exit 1
fi

BUILDSCRIPT=$(dirname "$0")/build-package.sh
BUILDALL_DIR=$TERMUX_TOPDIR/_buildall-$TERMUX_ARCH

mkdir -p "$BUILDALL_DIR"

exec >	>(tee -a "$BUILDALL_DIR"/ALL.out)
exec 2> >(tee -a "$BUILDALL_DIR"/ALL.err >&2)
trap 'echo ERROR: See $BUILDALL_DIR/${PKG}.err' ERR

PACKAGES=()
BLOCKLIST=()
# key:
# ☆: only reproducible when reusing a dirty docker container ("prefix pollution")
# ⬤: reproducible with clean docker container and build-package.sh with -I ("normal" error)

BLOCKLIST+=("aubio") # ⬤ ModuleNotFoundError: No module named 'imp'
BLOCKLIST+=("jack2") # ⬤ ModuleNotFoundError: No module named 'imp'
BLOCKLIST+=("qt5-qtwebengine") # ⬤ ModuleNotFoundError: No module named 'imp'
BLOCKLIST+=("enchant") # ⬤ 404
BLOCKLIST+=("ircd-irc2") # ⬤ 404
BLOCKLIST+=("ghc-libs") # ⬤ error: Warning: Couldn't figure out LLVM version! Make sure you have installed LLVM between [9 and 15)
BLOCKLIST+=("lenmus") # ⬤ lomse_font_freetype.cpp:203:31: error: assigning to 'char *' from 'unsigned char *' converts between pointers
BLOCKLIST+=("inkscape") # ⬤ ld.lld: error: unable to find library -lGraphicsMagick++
BLOCKLIST+=("cairo-dock-core") # ⬤ ld.lld: error: undefined reference due to --no-allow-shlib-undefined: atan2 >>> referenced by gldit/libgldi.so
BLOCKLIST+=("crypto-monitor") # ⬤ error: member access into incomplete type 'WINDOW' (aka '_win_st') (ncurses conflict)
BLOCKLIST+=("frida") # ⬤ Unsupported NDK version 27. Please install NDK r25.
BLOCKLIST+=("iptables") # ⬤ ../include/linux/netfilter/nfnetlink.h:6:6: error: redefinition of 'nfnetlink_groups'
BLOCKLIST+=("iwyu") # ⬤ iwyu_path_util.h:94:16: error: no member named 'equals' in 'llvm::StringRef'
BLOCKLIST+=("ldc") # ⬤ Signals.h:119:8: error: variable or field ‘CleanupOnSignal’ declared void
BLOCKLIST+=("lfortran") # ⬤ asr_to_llvm.cpp:36:10: fatal error: 'llvm/Transforms/Vectorize.h' file not found
BLOCKLIST+=("mapserver") # ⬤ agg_font_freetype.cpp:177:35: error: assigning to 'char *' from 'unsigned char *' converts between pointers to integer types where one is of the unique plain 'char' type and the other is not https://bugs.gentoo.org/939022
BLOCKLIST+=("openfoam") # ⬤ CGAL/IO/io.h:280:22: error: no member named 'optional' in namespace 'std'
BLOCKLIST+=("openscad") # ⬤ FreetypeRenderer.h:127:37: error: no template named 'unary_function' in namespace 'std'; did you mean '__unary_function'?
BLOCKLIST+=("poac") # ⬤ Error: tbb >= 2021.5.0, tbb < 2022.0.0 not found
BLOCKLIST+=("postgis") # ⬤ pg_iovec.h:54:10: error: call to undeclared function 'preadv'
BLOCKLIST+=("pypy3") # ⬤ proot error: 'uname' not found
BLOCKLIST+=("qt-creator") # ⬤ clangformatbaseindenter.cpp:76:17: error: no member named 'startswith' in 'llvm::StringRef'; did you mean 'starts_with'?
BLOCKLIST+=("swift") # ⬤ ld.lld: error: unable to find library -lswiftCore
BLOCKLIST+=("thunderbird") # ⬤ error: the lock file /home/builder/.termux-build/thunderbird/src/comm/rust/Cargo.lock needs to be updated but --frozen was passed to prevent this
BLOCKLIST+=("tint2") # ⬤ ld.lld: error: undefined symbol: log10
BLOCKLIST+=("tvheadend") # ⬤ src/service.c:1168:7: error: variable 'i' set but not used [-Werror,-Wunused-but-set-variable]
BLOCKLIST+=("valgrind") # ⬤ ERROR: ./libexec/valgrind/vgpreload_drd-arm64-linux.so contains undefined symbols
BLOCKLIST+=("vulkan-validation-layers") # ⬤ layer_chassis_dispatch.cpp:6309:97: error: too few arguments to function call, expected 4, have 2



# ☆ error: Warning: Couldn't figure out LLVM version! Make sure you have installed LLVM between [9 and 15)
BLOCKLIST+=("cabal-install") # ☆
BLOCKLIST+=("shellcheck") # ☆

# ☆ 404
BLOCKLIST+=("abiword") # ☆
BLOCKLIST+=("atril") # ☆
BLOCKLIST+=("audacity") # ☆
BLOCKLIST+=("bluefish") # ☆
BLOCKLIST+=("cherrytree") # ☆
BLOCKLIST+=("codeblocks") # ☆
BLOCKLIST+=("epiphany") # ☆
BLOCKLIST+=("fcitx5-configtool") # ☆
BLOCKLIST+=("fcitx5-gtk-common") # ☆
BLOCKLIST+=("fcitx5-hangul") # ☆
BLOCKLIST+=("fcitx5-qt") # ☆
BLOCKLIST+=("fcitx5") # ☆
BLOCKLIST+=("gedit") # ☆
BLOCKLIST+=("gnome-text-editor") # ☆
BLOCKLIST+=("gspell") # ☆
BLOCKLIST+=("hugin") # ☆
BLOCKLIST+=("komorebi") # ☆
BLOCKLIST+=("libspelling") # ☆
BLOCKLIST+=("marco") # ☆
BLOCKLIST+=("mousepad") # ☆
BLOCKLIST+=("spek") # ☆
BLOCKLIST+=("surf") # ☆
BLOCKLIST+=("webkit2gtk-4.1") # ☆
BLOCKLIST+=("webkitgtk-6.0") # ☆
BLOCKLIST+=("wxmaxima") # ☆
BLOCKLIST+=("wxwidgets") # ☆
BLOCKLIST+=("zenity") # ☆
BLOCKLIST+=("remind") # ☆ 410

# ☆ ModuleNotFoundError: No module named 'imp' (fixed if dependencies fixed)
BLOCKLIST+=("ardour") # ☆
BLOCKLIST+=("jack-example-tools") # ☆
BLOCKLIST+=("jftui") # ☆
BLOCKLIST+=("mindforger") # ☆
BLOCKLIST+=("mlt") # ☆
BLOCKLIST+=("mpv-x") # ☆
BLOCKLIST+=("mpv") # ☆
BLOCKLIST+=("otter-browser") # ☆
BLOCKLIST+=("python-pyqtwebengine") # ☆
BLOCKLIST+=("quassel") # ☆
BLOCKLIST+=("shotcut") # ☆
BLOCKLIST+=("ytui-music") # ☆

# ☆ msgpack is already installed with the same version as the provided wheel. Use --force-reinstall to force an installation of the wheel.
BLOCKLIST+=("python-msgpack") 
BLOCKLIST+=("python-pynvim")
BLOCKLIST+=("python-pyarrow")

# ☆ ld.lld: error: undefined symbol: libandroid_shmget referenced by video_out_x11.c
BLOCKLIST+=("audacious-plugins")
BLOCKLIST+=("kid3") 
BLOCKLIST+=("libmpeg2")
BLOCKLIST+=("qt6-qtmultimedia")
BLOCKLIST+=("vlc-qt")
BLOCKLIST+=("vlc")
BLOCKLIST+=("wireshark-qt")

# ☆ seccomp-filter.c:47:10: fatal error: 'asm/prctl.h' file not found
BLOCKLIST+=("emacs-x") 
BLOCKLIST+=("emacs")
BLOCKLIST+=("mu")

# ☆ Program /data/data/com.termux/files/usr/lib/qt6/bin/moc found: NO
BLOCKLIST+=("gst-plugins-good")
BLOCKLIST+=("parole") 

# ☆ /bin/bash: line 1: /data/data/com.termux/files/usr/lib/qt6/moc: cannot execute binary file: Exec format error
BLOCKLIST+=("rbw")
BLOCKLIST+=("evince")
BLOCKLIST+=("gpg-crypter")
BLOCKLIST+=("pinentry-gtk")
BLOCKLIST+=("profanity")
BLOCKLIST+=("poppler")
BLOCKLIST+=("lastpass-cli")
BLOCKLIST+=("blackbox")
BLOCKLIST+=("pdfgrep")
BLOCKLIST+=("keychain")
BLOCKLIST+=("gnupg")
BLOCKLIST+=("pass-otp")
BLOCKLIST+=("nala")
BLOCKLIST+=("apt-file")
BLOCKLIST+=("pacman")
BLOCKLIST+=("aptitude")
BLOCKLIST+=("pinentry")
BLOCKLIST+=("apt")
BLOCKLIST+=("pdf2svg")
BLOCKLIST+=("hash-slinger")
BLOCKLIST+=("pass")
BLOCKLIST+=("pdf2djvu")
BLOCKLIST+=("gopass")
BLOCKLIST+=("gpgme")
BLOCKLIST+=("texlive-installer")
BLOCKLIST+=("libapt-pkg-perl")
BLOCKLIST+=("fwknop")
BLOCKLIST+=("python-apt")
BLOCKLIST+=("wget2")
BLOCKLIST+=("lxc")

# ☆ ld.lld: error: undefined reference due to --no-allow-shlib-undefined: yylex >>> referenced by /data/data/com.termux/files/usr/lib/libfl.so
BLOCKLIST+=("lgogdownloader") 
BLOCKLIST+=("libhtmlcxx")

# ☆ ld.lld: error: undefined symbol: src_new referenced by SDL_stdlib.c
BLOCKLIST+=("xmppc") #
BLOCKLIST+=("babl") #
BLOCKLIST+=("chocolate-doom")
BLOCKLIST+=("libvncserver")
BLOCKLIST+=("lite-xl")
BLOCKLIST+=("mgba")
BLOCKLIST+=("oshu")
BLOCKLIST+=("qemu-system-x86-64")
BLOCKLIST+=("schismtracker")
BLOCKLIST+=("scrcpy")
BLOCKLIST+=("sdl2-image")
BLOCKLIST+=("sdl2-mixer")
BLOCKLIST+=("sdl2-ttf")
BLOCKLIST+=("the-powder-toy")
BLOCKLIST+=("tuxpaint")
BLOCKLIST+=("x11vnc")
BLOCKLIST+=("termplay")
BLOCKLIST+=("dmtx-utils")
BLOCKLIST+=("proton-bridge")
BLOCKLIST+=("php-redis")
BLOCKLIST+=("libgee")
BLOCKLIST+=("valac")
BLOCKLIST+=("composer")
BLOCKLIST+=("gmic")
BLOCKLIST+=("octave")
BLOCKLIST+=("libsixel")
BLOCKLIST+=("gnuplot")
BLOCKLIST+=("libsecret")
BLOCKLIST+=("go-findimagedupes")
BLOCKLIST+=("graphicsmagick")
BLOCKLIST+=("php-psr")
BLOCKLIST+=("phpmyadmin")
BLOCKLIST+=("php-imagick")
BLOCKLIST+=("php-apcu")
BLOCKLIST+=("neomutt")
BLOCKLIST+=("libgd")
BLOCKLIST+=("libgmime")
BLOCKLIST+=("imlib2")
BLOCKLIST+=("blade")
BLOCKLIST+=("qrsspig")
BLOCKLIST+=("zbar")
BLOCKLIST+=("libheif")
BLOCKLIST+=("zile")
BLOCKLIST+=("awesomeshot")
BLOCKLIST+=("zziplib")
BLOCKLIST+=("libvips")
BLOCKLIST+=("gegl")
BLOCKLIST+=("muchsync")
BLOCKLIST+=("libde265")
BLOCKLIST+=("w3m")
BLOCKLIST+=("notmuch")
BLOCKLIST+=("imagemagick")
BLOCKLIST+=("quilt")
BLOCKLIST+=("tenki-php")
BLOCKLIST+=("graphviz")
BLOCKLIST+=("yosys")
BLOCKLIST+=("php")
BLOCKLIST+=("dvdauthor")
BLOCKLIST+=("texlive-bin")
BLOCKLIST+=("libcaca")
BLOCKLIST+=("gexiv2")
BLOCKLIST+=("appstream")
BLOCKLIST+=("mdbook-graphviz")
BLOCKLIST+=("php-zephir-parser")
BLOCKLIST+=("z-push")
BLOCKLIST+=("libplacebo")
BLOCKLIST+=("lsix")
BLOCKLIST+=("toilet")
BLOCKLIST+=("vnstat")

# ☆ ld.lld: error: undefined reference due to --no-allow-shlib-undefined: src_new >>> referenced by ./.libs/libSDL2_net.so
BLOCKLIST+=("dosbox-x") 
BLOCKLIST+=("sdl2-net")
# ☆ ERROR: sdl2 requested but not found
BLOCKLIST+=("ffplay")
BLOCKLIST+=("kdenlive")
# ☆ ERROR: ./lib/libSDL2_Pango.so contains undefined symbols
BLOCKLIST+=("sdl2-pango")

# ☆ ld.lld: error: undefined reference due to --no-allow-shlib-undefined: __android_log_error_write >>> referenced by /home/builder/.termux-build/aapt/src/_lib/libandroid-ziparchive.so
BLOCKLIST+=("aapt") 
BLOCKLIST+=("sysprop")


BLOCKLIST+=("qb64") # ☆ ln: failed to create symbolic link '/data/data/com.termux/files/usr/bin/qb64': File exists
BLOCKLIST+=("lximage-qt") # ☆ ln: failed to create symbolic link '/data/data/com.termux/files/usr/opt/qt6/cross/bin/qmake6': File exists
BLOCKLIST+=("kf6-kbookmarks") # ☆ ln: failed to create symbolic link '/data/data/com.termux/files/usr/opt/qt6/cross/bin/qmake6': File exists
BLOCKLIST+=("libcryptsetup") # ☆ ln: failed to create symbolic link 'libargon2.so': File exists
BLOCKLIST+=("pari") # ☆ ld.lld: error: plotfltk.o is incompatible with aarch64linux
BLOCKLIST+=("python-scipy") # ☆ scipy is already installed with the same version as the provided wheel. Use --force-reinstall to force an installation of the wheel.
BLOCKLIST+=("wasi-libc") # ☆ mv: cannot overwrite '/data/data/com.termux/files/usr/share/cmake/Platform': Directory not empty
BLOCKLIST+=("hstr") # ☆ ln: failed to create hard link '/data/data/com.termux/files/usr/bin/hh': File exists
BLOCKLIST+=("unar") # ☆ configure: error: C compiler cannot create executables
BLOCKLIST+=("dopewars") # ☆ gtk_client.c:2202:3: error: call to undeclared function 'bind_textdomain_codeset
BLOCKLIST+=("helix") # ☆ cp: cannot create regular file '/data/data/com.termux/files/usr/opt/helix/runtime/grammars/sources/elisp/.git/objects/60/73b77c94d2418e19273c33ad2329cbc2834ce2': Permission denied
BLOCKLIST+=("cowsay") # ☆ ln: failed to create symbolic link '/data/data/com.termux/files/usr/bin/cowthink': File exists
BLOCKLIST+=("libiodbc") # ☆ ld.lld: error: version script assignment of 'global' to symbol '_iodbcdm_loginbox' failed: symbol not defined
BLOCKLIST+=("libt3window") # ☆ ln: failed to create symbolic link '/data/data/com.termux/files/usr/lib/transcript1/ibm9449p1002002.ltc': File exists
BLOCKLIST+=("openjdk-21") # ☆ cp: cannot create regular file '/data/data/com.termux/files/usr/lib/jvm/java-21-openjdk/legal/jdk.localedata/thaidict.md': Permission denied
BLOCKLIST+=("python-contourpy") # ☆ contourpy is already installed with the same version as the provided wheel. Use --force-reinstall to force an installation of the wheel.
BLOCKLIST+=("gdal") # ☆ ???
BLOCKLIST+=("osm2pgsql") # ☆ /home/builder/.termux-build/osm2pgsql/src/src/gen/canvas.hpp:15:10: fatal error: 'opencv2/core.hpp' file not found
BLOCKLIST+=("borgbackup") # ☆ borgbackup is already installed with the same version as the provided wheel. Use --force-reinstall to force an installation of the wheel.
BLOCKLIST+=("matplotlib") # ☆ contourpy is already installed with the same version as the provided wheel. Use --force-reinstall to force an installation of the wheel.
BLOCKLIST+=("llvm-mingw-w64") # ☆ ln: failed to create symbolic link '/data/data/com.termux/files/usr/bin/armv7-w64-mingw32-llvm-ranlib': File exists
BLOCKLIST+=("tilde") # ☆ ln: failed to create symbolic link '/data/data/com.termux/files/usr/lib/transcript1/iso88591.ltc': File exists
BLOCKLIST+=("libt3widget") # ☆ ln: failed to create symbolic link '/data/data/com.termux/files/usr/lib/transcript1/iso88591.ltc': File exists
BLOCKLIST+=("argon2") # ☆ ln: failed to create symbolic link 'libargon2.so': File exists
BLOCKLIST+=("seafile-client") # ☆ ln: failed to create symbolic link 'libargon2.so': File exists
BLOCKLIST+=("libtranscript") # ☆ ln: failed to create symbolic link '/data/data/com.termux/files/usr/lib/transcript1/iso88591.ltc': File exists
BLOCKLIST+=("libgnustep-base") # ☆ checking for aarch64-linux-android-gcc... aarch64-linux-android-clang checking whether the C compiler works... no
BLOCKLIST+=("lilypond") # ☆ error: use of undeclared identifier 'scm_from_utf8_symbol'; did you mean 'scm_from_locale_symbol'
BLOCKLIST+=("ansifilter") # ☆ ln: failed to create symbolic link '/data/data/com.termux/files/usr/opt/qt6/cross/bin/qmake6': File exists
BLOCKLIST+=("frogcomposband") # ☆ env: ‘/home/builder/.termux-build/frogcomposband/src/configure’: Permission denied
BLOCKLIST+=("cfengine") # ☆ cf_sql.c:64:5: error: call to undeclared function 'mysql_init'
BLOCKLIST+=("mdbtools") # ☆ ld.lld: error: version script assignment of 'global' to symbol '_iodbcdm_loginbox' failed: symbol not defined
BLOCKLIST+=("rpm") # ☆ elfdeps.c:87:7: error: use of undeclared identifier 'EM_FAKE_ALPHA'
BLOCKLIST+=("libtree-ldd") # ☆ cp: cannot create regular file '/data/data/com.termux/files/usr/bin/libtree': Permission denied
BLOCKLIST+=("gap") # ☆ cp: cannot create regular file '/data/data/com.termux/files/usr/lib/gap/pkg/gapdoc/tst/test.tst': Permission denied
BLOCKLIST+=("ices") # ☆ fatal error: 'sys/soundcard.h' file not found
BLOCKLIST+=("python-torchvision") # ☆ ln: failed to create symbolic link '/data/data/com.termux/files/usr/lib/libc10.so': File exists
BLOCKLIST+=("python-torchaudio") # ☆ ln: failed to create symbolic link '/data/data/com.termux/files/usr/lib/libc10.so': File exists
BLOCKLIST+=("python-onnxruntime") # ☆ ort.fbs.h:11:15: error: static assertion failed due to requirement '24 == 23': Non-compatible flatbuffers version included
BLOCKLIST+=("k2pdfopt") # ☆ Missing required dependency libpng.
BLOCKLIST+=("e2tools") # ☆ ld.lld: error: undefined symbol: _et_list
BLOCKLIST+=("libadwaita") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("ffmpegthumbnailer") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("librav1e") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("mpdscribble") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("alass") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("wasmer") # ☆ note: ld: error: unable to find library -llog
BLOCKLIST+=("rq") # ☆ note: ld: error: unable to find library -llog
BLOCKLIST+=("notcurses") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("minidlna") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("cmus") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("gpac") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("pipewire") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("pianobar") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("gst-libav") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("gomp") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("vgmstream") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("rsgain") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("ristretto") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("timg") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("ffmpeg") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("mpd") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("manim") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("waypipe") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("mplayer") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("ccextractor") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("navidrome") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("megacmd") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("imgflo") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("srt2vobsub") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("chromaprint") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("unpaper") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("crystal") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("thunar") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("kf6-kfilemetadata") # ☆ ld: error: unable to find library -llog
BLOCKLIST+=("recutils") # ☆ ./spawn.h:693:18: error: use of undeclared identifier 'POSIX_SPAWN_SETSCHEDULER'
BLOCKLIST+=("asymptote") # ☆ /bin/sh: 1: cmake: not found
BLOCKLIST+=("avrdude") # ☆ CMake Error at src/cmake_install.cmake:126 (file): file INSTALL cannot copy file "/home/builder/.termux-build/avrdude/build/src/_swig_avrdude.so" to "/usr/local/lib/python3.12/dist-packages/_swig_avrdude.so": Permission denied.
BLOCKLIST+=("cargo-c") # ☆ ld.lld: error: /data/data/com.termux/files/usr/lib/libz.a(adler32.o) is incompatible with elf64-x86-64
BLOCKLIST+=("deadbeef") # ☆ cgme.c:298:34: error: too few arguments to function call, expected 3, have 2 298 | gme_set_fade(info->emu, 0);
BLOCKLIST+=("fio") # ☆ ld.lld: error: undefined reference due to --no-allow-shlib-undefined: yylex
BLOCKLIST+=("gforth") # ☆ /usr/bin/install: cannot stat 'gforth.elc': No such file or directory
BLOCKLIST+=("godot") # ☆ thirdparty/glslang/SPIRV/GlslangToSpv.cpp:9482:42: error: no member named 'hasSprivDecorate' in 'glslang::TQualifier'
BLOCKLIST+=("libdart") # ☆ Imported target "urdfdom" includes non-existent path "/data/data/com.termux/files/usr/lib/urdfdom/cmake//../../../../../../../../include/urdfdom" - urdfdom bug
BLOCKLIST+=("liblog4cxx") # ☆ Imported target "fmt::fmt" includes non-existent path "/home/builder/.termux-build/python-torch/src/torch/include"
BLOCKLIST+=("mogan") # ☆ toolchain not found!
BLOCKLIST+=("mumble-server") # ☆ /bin/sh: 1: --cpp_out: not found
BLOCKLIST+=("ntfs-3g") # ☆ libtool: Version mismatch error. This is libtool 2.4.7 Debian-2.4.7-7build1, but the definition of this LT_INIT comes from libtool 2.5.3.
BLOCKLIST+=("python-tflite-runtime") # ☆ /weight_cache.h:30:10: fatal error: 'tensorflow/lite/delegates/xnnpack/weight_cache_schema_generated.h' file not found
BLOCKLIST+=("rizin") # ☆ ld.lld: error: undefined symbol: backtrace
BLOCKLIST+=("rust") # ☆ /usr/include/openssl/macros.h:147:4: error: "OPENSSL_API_COMPAT expresses an impossible API compatibility level"
BLOCKLIST+=("sdcv") # ☆ error: cannot initialize a variable of type 'gchar *' 
BLOCKLIST+=("smalltalk") # ☆ ERROR: ./lib/libgst.so contains undefined symbols
BLOCKLIST+=("tinygo") # ☆ ld.lld: error: undefined symbol: LLVMConstFCmp
BLOCKLIST+=("wine-stable") # ☆ error: libSDL2 development files not found, SDL2 won't be supported.
BLOCKLIST+=("oleo") # ☆ plot.c:473:7: error: call to undeclared function 'sp_set_axis_ticktype_date'


for PKG in $(find "$TERMUX_SCRIPTDIR"/{packages,root-packages,x11-packages} \
	-mindepth 1 -maxdepth 1 -exec basename {} \;); do
    if [[ " ${BLOCKLIST[*]} " != *" $PKG "* ]]; then
        PACKAGES+=("$PKG")
    fi
done

echo "Build Order:"
for PKG in "${PACKAGES[@]}"; do
	echo "$PKG"
done

for PKG in "${PACKAGES[@]}"; do
	BUILDSTATUS_FILE=/data/data/.built-packages/"$PKG"
	if [ -f "$BUILDSTATUS_FILE" ]; then
		echo "Skipping $PKG (rm $BUILDSTATUS_FILE to force rebuild)"
		continue
	fi

	echo -n "Building $PKG... "
	BUILD_START=$(date "+%s")
	bash "$BUILDSCRIPT" -a "$TERMUX_ARCH" $TERMUX_DEBUG_BUILD \
		${TERMUX_OUTPUT_DIR+-o $TERMUX_OUTPUT_DIR} $TERMUX_INSTALL_DEPS \
		"$PKG" 2>&1 | tee "$BUILDALL_DIR"/"${PKG}".out
		#"$PKG" > "$BUILDALL_DIR"/"${PKG}".out 2> "$BUILDALL_DIR"/"${PKG}".err
	BUILD_END=$(date "+%s")
	BUILD_SECONDS=$(( BUILD_END - BUILD_START ))
	echo "done in $BUILD_SECONDS"
done

echo "Finished"
