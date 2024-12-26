TERMUX_PKG_HOMEPAGE=https://github.com/revoltchat/backend
TERMUX_PKG_DESCRIPTION="Monorepo for Revolt backend services"
TERMUX_PKG_LICENSE="AGPL-V3"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="0.8.0"
# the release tag name is not the same as the release "title" number
_REVOLT_BACKEND_RELEASE_TAG="20241128-2"
TERMUX_PKG_SRCURL=https://github.com/revoltchat/backend/archive/refs/tags/$_REVOLT_BACKEND_RELEASE_TAG.tar.gz
TERMUX_PKG_SHA256=5e0c5fcb205b3de220249a7ab5396bea5611308450b053b1bb55e1085d49bc57
# runtime dependencies ignored for this example (may be run on another device and connected as remote services):
# mongodb, redis, minio, maildev, rabbitmq
# client software required to make use of the server (may be run on another device):
# https://github.com/revoltchat/revite
TERMUX_PKG_DEPENDS="openssl"
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_RM_AFTER_INSTALL="
lib/libz.a
lib/libz.so
"

termux_step_pre_configure() {
	# I really do not like using this workaround, but we have not been able to
	# invent a better solution yet.
	# (ld: error: /data/data/com.termux/files/usr/lib/libz.so is incompatible with elf64-x86-64)
	# https://github.com/termux/termux-packages/issues/20100
	# https://github.com/termux/termux-packages/pull/21835#issuecomment-2418105843
	mv ${TERMUX_PREFIX}/lib/libz.a{,.tmp} || :
	mv ${TERMUX_PREFIX}/lib/libz.so{,.tmp} || :
}

termux_step_make_install() {
	termux_setup_rust
	cargo build --jobs $TERMUX_PKG_MAKE_PROCESSES --target $CARGO_TARGET_NAME --release

	for binary in delta bonfire autumn january pushd; do
		install -Dm755 -t $TERMUX_PREFIX/bin target/${CARGO_TARGET_NAME}/release/revolt-${binary}
	done
}

termux_step_post_make_install() {
	mv ${TERMUX_PREFIX}/lib/libz.a{.tmp,} || :
	mv ${TERMUX_PREFIX}/lib/libz.so{.tmp,} || :
}