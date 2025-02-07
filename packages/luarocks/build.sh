TERMUX_PKG_HOMEPAGE=https://luarocks.org/
TERMUX_PKG_DESCRIPTION="Deployment and management system for Lua modules"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="3.11.1"
TERMUX_PKG_SRCURL=https://luarocks.org/releases/luarocks-${TERMUX_PKG_VERSION}.tar.gz
TERMUX_PKG_SHA256=c3fb3d960dffb2b2fe9de7e3cb004dc4d0b34bb3d342578af84f84325c669102
TERMUX_PKG_AUTO_UPDATE=true
TERMUX_PKG_DEPENDS="curl, lua51"
TERMUX_PKG_BUILD_DEPENDS="liblua51"
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_PLATFORM_INDEPENDENT=true

termux_step_configure() {
	./configure --prefix="$TERMUX_PREFIX" \
				--with-lua="$TERMUX_PREFIX"
}