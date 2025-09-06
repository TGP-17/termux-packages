TERMUX_PKG_HOMEPAGE="https://gnucash.org"
TERMUX_PKG_DESCRIPTION="Personal and small-business financial-accounting software"
TERMUX_PKG_LICENSE="GPL-2.0-or-later" # with OpenSSL linking exceptions
TERMUX_PKG_LICENSE_FILE="LICENSE"	 # specified for additional nuance.
TERMUX_PKG_MAINTAINER="@acozzette <adam@acozzette.net>"
TERMUX_PKG_VERSION="5.12"
TERMUX_PKG_SRCURL="https://github.com/Gnucash/gnucash/releases/download/${TERMUX_PKG_VERSION}/gnucash-${TERMUX_PKG_VERSION}.tar.bz2"
TERMUX_PKG_SHA256="b35b4756be12bcfdbed54468f30443fa53f238520a9cead5bde2e6c4773fbf39"
TERMUX_PKG_DEPENDS="boost, gettext, guile, glib, gtk3, libsecret, libxml2, libxslt, perl, python, swig, webkit2gtk-4.1, xsltproc, zlib"
TERMUX_PKG_BUILD_DEPENDS="boost-headers, googletest"
TERMUX_PKG_AUTO_UPDATE=true
TERMUX_PKG_SETUP_PYTHON=true
TERMUX_PKG_HOSTBUILD=true
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
-DWITH_PYTHON=ON
-DWITH_SQL=OFF
-DWITH_OFX=OFF
-DWITH_AQBANKING=OFF
"

# Function to obtain the .deb URL
obtain_deb_url() {
	local url attempt retries wait PAGE deb_url
	url="https://packages.ubuntu.com/noble/amd64/$1/download"
	retries=50
	wait=50

	>&2 echo "url: $url"

	for ((attempt=1; attempt<=retries; attempt++)); do
		PAGE="$(curl -s "$url")"
		deb_url="$(grep -oE 'https?://.*\.deb' <<< "$PAGE" | head -n1)"
		if [[ -n "$deb_url" ]]; then
				echo "$deb_url"
				return 0
		else
			>&2 echo "Attempt $attempt: Failed to obtain deb URL. Retrying in $wait seconds..."
		fi
		sleep "$wait"
	done

	termux_error_exit "Failed to obtain URL after $retries attempts."
}

termux_step_host_build() {
	if [[ "$TERMUX_ON_DEVICE_BUILD" == "true" ]]; then
		return
	fi
	# install Ubuntu packages, like in the aosp-libs build.sh
	local HOSTBUILD_ROOTFS="${TERMUX_PKG_HOSTBUILD_DIR}/ubuntu_packages"
	mkdir -p "${HOSTBUILD_ROOTFS}"

	local URL DEB_NAME DEB_LIST

	# how to get this list:
	# 1. run these commands in the container
	# sudo apt update
	# sudo apt install libxslt1-dev \
	#	 libwebkit2gtk-4.1-dev \
	#	 libboost-dev \
	#	 libgtest-dev \
	#	 python3-dev \
	#	 libboost-filesystem-dev \
	#	 libboost-date-time-dev \
	#	 libboost-locale-dev \
	#	 libboost-regex-dev \
	#	 libboost-program-options-dev \
	#	 libboost-system-dev \
	#	 libgmock-dev
	# 2. cancel the installation by answering "NO" when prompted
	# 3. copy the "NEW packages will be installed" list
	DEB_LIST=""
	DEB_LIST+=" bubblewrap"
	DEB_LIST+=" enchant-2"
	DEB_LIST+=" fuse3"
	DEB_LIST+=" gir1.2-javascriptcoregtk-4.1"
	DEB_LIST+=" gir1.2-soup-3.0"
	DEB_LIST+=" gir1.2-webkit2-4.1"
	DEB_LIST+=" glib-networking"
	DEB_LIST+=" glib-networking-common"
	DEB_LIST+=" glib-networking-services"
	DEB_LIST+=" googletest"
	DEB_LIST+=" gsettings-desktop-schemas"
	DEB_LIST+=" gstreamer1.0-gl"
	DEB_LIST+=" gstreamer1.0-plugins-base"
	DEB_LIST+=" gstreamer1.0-plugins-good"
	DEB_LIST+=" gstreamer1.0-x"
	DEB_LIST+=" hunspell-en-us"
	DEB_LIST+=" iso-codes"
	DEB_LIST+=" libaa1"
	DEB_LIST+=" libasyncns0"
	DEB_LIST+=" libavc1394-0"
	DEB_LIST+=" libboost-atomic1.83-dev"
	DEB_LIST+=" libboost-atomic1.83.0"
	DEB_LIST+=" libboost-chrono1.83-dev"
	DEB_LIST+=" libboost-chrono1.83.0t64"
	DEB_LIST+=" libboost-date-time-dev"
	DEB_LIST+=" libboost-date-time1.83-dev"
	DEB_LIST+=" libboost-date-time1.83.0"
	DEB_LIST+=" libboost-dev"
	DEB_LIST+=" libboost-filesystem-dev"
	DEB_LIST+=" libboost-filesystem1.83-dev"
	DEB_LIST+=" libboost-filesystem1.83.0"
	DEB_LIST+=" libboost-locale-dev"
	DEB_LIST+=" libboost-locale1.83-dev"
	DEB_LIST+=" libboost-locale1.83.0"
	DEB_LIST+=" libboost-program-options-dev"
	DEB_LIST+=" libboost-program-options1.83-dev"
	DEB_LIST+=" libboost-program-options1.83.0"
	DEB_LIST+=" libboost-regex-dev"
	DEB_LIST+=" libboost-regex1.83-dev"
	DEB_LIST+=" libboost-regex1.83.0"
	DEB_LIST+=" libboost-serialization1.83-dev"
	DEB_LIST+=" libboost-serialization1.83.0"
	DEB_LIST+=" libboost-system-dev"
	DEB_LIST+=" libboost-system1.83-dev"
	DEB_LIST+=" libboost-system1.83.0"
	DEB_LIST+=" libboost-thread1.83-dev"
	DEB_LIST+=" libboost-thread1.83.0"
	DEB_LIST+=" libboost1.83-dev"
	DEB_LIST+=" libcaca0"
	DEB_LIST+=" libcap2-bin"
	DEB_LIST+=" libcdparanoia0"
	DEB_LIST+=" libduktape207"
	DEB_LIST+=" libdv4t64"
	DEB_LIST+=" libenchant-2-2"
	DEB_LIST+=" libevdev2"
	DEB_LIST+=" libflac12t64"
	DEB_LIST+=" libfuse3-3"
	DEB_LIST+=" libgmock-dev"
	DEB_LIST+=" libgraphene-1.0-0"
	DEB_LIST+=" libgstreamer-gl1.0-0"
	DEB_LIST+=" libgstreamer-plugins-base1.0-0"
	DEB_LIST+=" libgstreamer-plugins-good1.0-0"
	DEB_LIST+=" libgstreamer1.0-0"
	DEB_LIST+=" libgtest-dev"
	DEB_LIST+=" libgudev-1.0-0"
	DEB_LIST+=" libhunspell-1.7-0"
	DEB_LIST+=" libhyphen0"
	DEB_LIST+=" libiec61883-0"
	DEB_LIST+=" libjavascriptcoregtk-4.1-0"
	DEB_LIST+=" libjavascriptcoregtk-4.1-dev"
	DEB_LIST+=" libmanette-0.2-0"
	DEB_LIST+=" libmp3lame0"
	DEB_LIST+=" libmpg123-0t64"
	DEB_LIST+=" libnghttp2-dev"
	DEB_LIST+=" libogg0"
	DEB_LIST+=" libopus0"
	DEB_LIST+=" liborc-0.4-0t64"
	DEB_LIST+=" libpam-cap"
	DEB_LIST+=" libpipewire-0.3-0t64"
	DEB_LIST+=" libpipewire-0.3-common"
	DEB_LIST+=" libproxy1v5"
	DEB_LIST+=" libpsl-dev"
	DEB_LIST+=" libpulse0"
	DEB_LIST+=" libpython3-dev"
	DEB_LIST+=" libpython3.12-dev"
	DEB_LIST+=" libraw1394-11"
	DEB_LIST+=" libshout3"
	DEB_LIST+=" libslang2"
	DEB_LIST+=" libsndfile1"
	DEB_LIST+=" libsoup-3.0-0"
	DEB_LIST+=" libsoup-3.0-common"
	DEB_LIST+=" libsoup-3.0-dev"
	DEB_LIST+=" libspa-0.2-modules"
	DEB_LIST+=" libspeex1"
	DEB_LIST+=" libsysprof-capture-4-dev"
	DEB_LIST+=" libtag1v5"
	DEB_LIST+=" libtag1v5-vanilla"
	DEB_LIST+=" libtheora0"
	DEB_LIST+=" libtwolame0"
	DEB_LIST+=" libunwind8"
	DEB_LIST+=" libv4l-0t64"
	DEB_LIST+=" libv4lconvert0t64"
	DEB_LIST+=" libvisual-0.4-0"
	DEB_LIST+=" libvorbis0a"
	DEB_LIST+=" libvorbisenc2"
	DEB_LIST+=" libvpx9"
	DEB_LIST+=" libwavpack1"
	DEB_LIST+=" libwebkit2gtk-4.1-0"
	DEB_LIST+=" libwebkit2gtk-4.1-dev"
	DEB_LIST+=" libwebrtc-audio-processing1"
	DEB_LIST+=" libxslt1-dev"
	DEB_LIST+=" libxv1"
	DEB_LIST+=" python3-dev"
	DEB_LIST+=" python3.12-dev"
	DEB_LIST+=" session-migration"
	DEB_LIST+=" xdg-dbus-proxy"
	DEB_LIST+=" xdg-desktop-portal"
	DEB_LIST+=" xdg-desktop-portal-gtk"

	for i in $DEB_LIST; do
		echo "deb: $i"
		URL="$(obtain_deb_url "$i")"
		DEB_NAME="${URL##*/}"
		termux_download "$URL" "${TERMUX_PKG_CACHEDIR}/${DEB_NAME}" SKIP_CHECKSUM

		mkdir -p "${TERMUX_PKG_TMPDIR}/${DEB_NAME}"
		ar x "${TERMUX_PKG_CACHEDIR}/${DEB_NAME}" --output="${TERMUX_PKG_TMPDIR}/${DEB_NAME}"
		tar xf "${TERMUX_PKG_TMPDIR}/${DEB_NAME}/data.tar.zst" \
			-C "${HOSTBUILD_ROOTFS}"
	done

	find "${HOSTBUILD_ROOTFS}" -type f -name '*.pc' | \
		xargs -n 1 sed -i -e "s|/usr|${HOSTBUILD_ROOTFS}/usr|g"

	# delete python static libraries to prevent error:
	# relocation R_X86_64_32 against `.rodata' can not be used when making a shared object; recompile with -fPIC
	find "${HOSTBUILD_ROOTFS}" -type f -name '*python*.a' -delete

	# /usr/bin/ld: cannot find -lxslt: No such file or directory
	find "${HOSTBUILD_ROOTFS}/usr/lib/x86_64-linux-gnu" -xtype l \
		-exec sh -c "ln -snvf /usr/lib/x86_64-linux-gnu/\$(readlink \$1) \$1" sh {} \;

	# libgnucash-guile.so: cannot open shared object file: No such file or directory
	export LD_LIBRARY_PATH="${HOSTBUILD_ROOTFS}/usr/lib/x86_64-linux-gnu"
	LD_LIBRARY_PATH+=":${HOSTBUILD_ROOTFS}/usr/lib"
	LD_LIBRARY_PATH+=":${HOSTBUILD_ROOTFS}/usr/lib/$TERMUX_PKG_NAME"

	termux_setup_cmake
	termux_setup_ninja

	mkdir build
	pushd build
	cmake "$TERMUX_PKG_SRCDIR" \
		-DCMAKE_PREFIX_PATH="${HOSTBUILD_ROOTFS}/usr" \
		-DCMAKE_INSTALL_PREFIX="${HOSTBUILD_ROOTFS}/usr" \
		$TERMUX_PKG_EXTRA_CONFIGURE_ARGS \
		-GNinja

	cmake --build .

	cmake --install .
	popd
}

termux_step_pre_configure() {
	termux_setup_gir
	termux_setup_glib_cross_pkg_config_wrapper

	# gnc-autoclear.c:151:22: error: format string is not a string literal (potentially insecure)
	CFLAGS+=" -Wno-format-security"

	if [[ "$TERMUX_ON_DEVICE_BUILD" == "true" ]]; then
		return
	fi

	local GUILD_EXECUTABLE=$(command -v guild)
	local GUILE_EXECUTABLE=$(command -v guile)

	patch="$TERMUX_PKG_BUILDER_DIR/cross-compilation.diff"
	echo "Applying patch: $(basename "$patch")"
	test -f "$patch" && sed \
		-e "s%\@TERMUX_PREFIX\@%${TERMUX_PREFIX}%g" \
		-e "s%\@TERMUX_PYTHON_HOME\@%${TERMUX_PYTHON_HOME}%g" \
		-e "s%\@GUILD_EXECUTABLE\@%${GUILD_EXECUTABLE}%g" \
		-e "s%\@GUILE_EXECUTABLE\@%${GUILE_EXECUTABLE}%g" \
		"$patch" | patch --silent -p1 -d"$TERMUX_PKG_SRCDIR"

	local HOSTBUILD_ROOTFS="${TERMUX_PKG_HOSTBUILD_DIR}/ubuntu_packages"

	# libgnucash-guile.so: cannot open shared object file: No such file or directory
	export LD_LIBRARY_PATH="${HOSTBUILD_ROOTFS}/usr/lib/x86_64-linux-gnu"
	LD_LIBRARY_PATH+=":${HOSTBUILD_ROOTFS}/usr/lib"
	LD_LIBRARY_PATH+=":${HOSTBUILD_ROOTFS}/usr/lib/$TERMUX_PKG_NAME"

	# ERROR: ./lib/libgnc-expressions.so contains undefined symbols log, pow, exp...
	LDFLAGS+=" -lm"

	# CANNOT LINK EXECUTABLE "gnucash": library "libgnc-qif-import.so" not found: needed by main executable
	LDFLAGS+=" -Wl,-rpath=$TERMUX__PREFIX__LIB_DIR/$TERMUX_PKG_NAME"
}
