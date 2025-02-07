TERMUX_PKG_HOMEPAGE=https://www.gnu.org/software/gnushogi/
TERMUX_PKG_DESCRIPTION="Program that plays the game of Shogi, also known as Japanese Chess"
TERMUX_PKG_LICENSE="GPL-2.0"
TERMUX_PKG_MAINTAINER="@termux"
_COMMIT=5bb0b5b2f6953b3250e965c7ecaf108215751a74
TERMUX_PKG_VERSION=2014.11.19
TERMUX_PKG_SRCURL=git+https://git.savannah.gnu.org/git/gnushogi.git
TERMUX_PKG_GIT_BRANCH=master
TERMUX_PKG_SHA256=7743bef7ca9d412e2e2d2c111c24ff23c934b53134a3eb7f477c05139dba9299
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="ac_cv_lib_curses_clrtoeol=yes --with-curses"
TERMUX_PKG_RM_AFTER_INSTALL="info/gnushogi.info"
TERMUX_PKG_DEPENDS="ncurses"
TERMUX_PKG_HOSTBUILD=true
TERMUX_PKG_GROUPS="games"

termux_step_post_get_source() {
	git fetch --unshallow
	git checkout $_COMMIT

	local version="$(git log -1 --format=%cs | sed 's/-/./g')"
	if [ "$version" != "$TERMUX_PKG_VERSION" ]; then
		echo -n "ERROR: The specified version \"$TERMUX_PKG_VERSION\""
		echo " is different from what is expected to be: \"$version\""
		return 1
	fi

	local s=$(find . -type f ! -path '*/.git/*' -print0 | xargs -0 sha256sum | LC_ALL=C sort | sha256sum)
	if [[ "${s}" != "${TERMUX_PKG_SHA256}  "* ]]; then
		termux_error_exit "Checksum mismatch for source files."
	fi
}

termux_step_host_build() {
	cd "$TERMUX_PKG_SRCDIR"
	./autogen.sh
}

termux_step_pre_configure() {
	CFLAGS+=" $CPPFLAGS -fcommon"
}
