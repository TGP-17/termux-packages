TERMUX_PKG_HOMEPAGE=https://github.com/plougher/squashfs-tools
TERMUX_PKG_DESCRIPTION="Tools for squashfs, a highly compressed read-only filesystem for Linux"
TERMUX_PKG_LICENSE="GPL-2.0"
TERMUX_PKG_MAINTAINER="@termux"
# last commit made before pthread_cancel() introduced to codebase
_COMMIT=1a26745235e776cd47264b2d96c703676b89cc70
_COMMIT_DATE=20130326
TERMUX_PKG_VERSION="4.2-p${_COMMIT_DATE}"
TERMUX_PKG_SRCURL=git+https://github.com/plougher/squashfs-tools.git
TERMUX_PKG_GIT_BRANCH=master
TERMUX_PKG_SHA256=6cd4a91a2db99c9b041a3b9077da9860758d44320c1461b4d06513f9a2a6ad70
TERMUX_PKG_DEPENDS="liblz4, liblzma, liblzo, zlib, zstd"
TERMUX_PKG_AUTO_UPDATE=false
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_MAKE_PROCESSES=1
TERMUX_PKG_EXTRA_MAKE_ARGS="
INSTALL_DIR=$TERMUX_PREFIX/bin
LZO_DIR=$TERMUX_PREFIX
GZIP_SUPPORT=1
LZ4_SUPPORT=1
LZMA_XZ_SUPPORT=1
LZO_SUPPORT=1
XATTR_SUPPORT=1
XZ_SUPPORT=1
ZSTD_SUPPORT=1
-C squashfs-tools
"

termux_step_post_get_source() {
	git fetch --unshallow
	git checkout $_COMMIT

	local pdate="p$(git log -1 --format=%cs | sed 's/-//g')"
	if [[ "$TERMUX_PKG_VERSION" != *"${pdate}" ]]; then
		echo -n "ERROR: The version string \"$TERMUX_PKG_VERSION\" is"
		echo -n " different from what is expected to be; should end"
		echo " with \"${pdate}\"."
		return 1
	fi

	local s=$(find . -type f ! -path '*/.git/*' -print0 | xargs -0 sha256sum | LC_ALL=C sort | sha256sum)
	if [[ "${s}" != "${TERMUX_PKG_SHA256}  "* ]]; then
		termux_error_exit "Checksum mismatch for source files."
	fi
}
