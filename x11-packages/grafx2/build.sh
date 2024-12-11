TERMUX_PKG_HOMEPAGE=https://gitlab.com/GrafX2/grafX2
TERMUX_PKG_DESCRIPTION="The Ultimate 256-color bitmap paint program"
TERMUX_PKG_LICENSE="GPL-2.0"
TERMUX_PKG_MAINTAINER="@termux"
_COMMIT=9df0db9ceebc6cefd51b84863038a2fefaa515c0
_COMMIT_DATE=20240827
TERMUX_PKG_VERSION=2.9-p${_COMMIT_DATE}
TERMUX_PKG_SRCURL=git+https://gitlab.com/GrafX2/grafX2.git
TERMUX_PKG_GIT_BRANCH=master
TERMUX_PKG_SHA256=014195dabd21bd98c856ef3115a2afcc2cf89e7815777f1b36d78ea27d9b0a4c
TERMUX_PKG_DEPENDS="freetype, lua51, sdl2, sdl2-image, sdl2-ttf, libiconv"
TERMUX_PKG_BUILD_IN_SRC=true

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
		termux_error_exit "Checksum mismatch for source files. Expected: ${s}"
	fi
}

termux_step_pre_configure() {
	# all of grafx2's use of the "#ifdef __ANDROID__" preprocessor define in C,
	# are changes that are exclusively intended for building an APK,
	# so copy the sdl2 package's global replacement of this
	# (some other packages' code, for example luanti's, has a mixture 
	# of exclusvely-APK-related and non-APK-related changes inside __ANDROID__
	# blocks, so not all packages can safely use this shortcut code instead of
	# patches)
	find "$TERMUX_PKG_SRCDIR"/src -type f | \
		xargs -n 1 sed -i \
		-e 's/\([^A-Za-z0-9_]__ANDROID\)\(__[^A-Za-z0-9_]\)/\1_NO_TERMUX\2/g' \
		-e 's/\([^A-Za-z0-9_]__ANDROID\)__$/\1_NO_TERMUX__/g'

	export API="sdl2"
}

termux_step_make() {
	make -j "$TERMUX_PKG_MAKE_PROCESSES"
}

termux_step_make_install() {
	make -C src/ install
}