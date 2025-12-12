TERMUX_PKG_HOMEPAGE=https://hnefatafl.org/
TERMUX_PKG_DESCRIPTION="Copenhagen Hnefatafl client"
TERMUX_PKG_LICENSE="MIT, Apache-2.0"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="4.4.1"
TERMUX_PKG_SRCURL="https://github.com/dcampbell24/hnefatafl/archive/refs/tags/v${TERMUX_PKG_VERSION}.tar.gz"
TERMUX_PKG_SHA256=154f18aade8b84acbd8ce090de82ce8e541b33d31976a2f6a5c5ea5370e69e3e
TERMUX_PKG_DEPENDS="alsa-lib, libc++, hicolor-icon-theme, libxi, libxcursor, libxrandr, hicolor-icon-theme"
TERMUX_PKG_BUILD_DEPENDS="libxcb, libxkbcommon"
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_AUTO_UPDATE=true
TERMUX_PKG_HOSTBUILD=true

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

_install_ubuntu_packages() {
	# install Ubuntu packages, like in the aosp-libs build.sh
	export HOSTBUILD_ROOTFS="${TERMUX_PKG_HOSTBUILD_DIR}/ubuntu_packages"
	mkdir -p "${HOSTBUILD_ROOTFS}"
	local URL DEB_NAME DEB_LIST

	DEB_LIST="$@"

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

	find "${HOSTBUILD_ROOTFS}/usr/lib/x86_64-linux-gnu" -xtype l \
		-exec sh -c "ln -snvf /usr/lib/x86_64-linux-gnu/\$(readlink \$1) \$1" sh {} \;

	export LD_LIBRARY_PATH="${HOSTBUILD_ROOTFS}/usr/lib/x86_64-linux-gnu"
	LD_LIBRARY_PATH+=":${HOSTBUILD_ROOTFS}/usr/lib"

	export PKG_CONFIG_LIBDIR="${HOSTBUILD_ROOTFS}/usr/lib/x86_64-linux-gnu/pkgconfig"
}

termux_step_host_build() {
	# build man page

	if [[ "$TERMUX_ON_DEVICE_BUILD" == "true" ]]; then
		return
	fi

	_install_ubuntu_packages libasound2-dev

	termux_setup_rust
	pushd "$TERMUX_PKG_SRCDIR"
	rm -f .cargo/config.toml 
	cargo build \
		--jobs "$TERMUX_PKG_MAKE_PROCESSES" \
		--release \
		--example hnefatafl-client \
		--no-default-features
	target/release/examples/hnefatafl-client --man
	cp hnefatafl-client.1 "$TERMUX_PKG_HOSTBUILD_DIR/"
	popd
}

termux_step_pre_configure() {
	termux_setup_rust

	rm -f .cargo/config.toml

	: "${CARGO_HOME:=$HOME/.cargo}"
	export CARGO_HOME

	cargo vendor
	find ./vendor \
		-mindepth 1 -maxdepth 1 -type d \
		! -wholename ./vendor/cpal \
		! -wholename ./vendor/smithay-client-toolkit \
		! -wholename ./vendor/smithay-client-toolkit-0.19.2 \
		! -wholename ./vendor/softbuffer \
		! -wholename ./vendor/wayland-cursor \
		! -wholename ./vendor/wgpu-hal \
		! -wholename ./vendor/winit \
		! -wholename ./vendor/x11rb-protocol \
		! -wholename ./vendor/xkbcommon-dl \
		-exec rm -rf '{}' \;

	git clone https://github.com/iced-rs/winit.git vendor/winit-iced

	find vendor/{cpal,smithay-client-toolkit,smithay-client-toolkit-0.19.2,softbuffer,wgpu-hal,winit,winit-iced,x11rb-protocol,xkbcommon-dl} -type f | \
		xargs -n 1 sed -i \
		-e 's|target_os = "android"|target_os = "disabling_this_because_it_is_for_building_an_apk"|g' \
		-e 's|target_os = "linux"|target_os = "android"|g' \
		-e "s|libxkbcommon.so.0|libxkbcommon.so|g" \
		-e "s|libxkbcommon-x11.so.0|libxkbcommon-x11.so|g" \
		-e "s|libxcb.so.1|libxcb.so|g" \
		-e "s|/tmp|$TERMUX_PREFIX/tmp|g"

	for crate in wayland-cursor softbuffer; do
		local patch="$TERMUX_PKG_BUILDER_DIR/$crate-no-shm.diff"
		local dir="vendor/$crate"
		echo "Applying patch: $patch"
		patch -p1 -d "$dir" < "${patch}"
	done

	local patch="$TERMUX_PKG_BUILDER_DIR/smithay-client-toolkit-0.19.2-no-shm.diff"
	local dir="vendor/smithay-client-toolkit-0.19.2"
	echo "Applying patch: $patch"
	patch -p1 -d "$dir" < "${patch}"

	local patch="$TERMUX_PKG_BUILDER_DIR/smithay-client-toolkit-0.20.0-no-shm.diff"
	local dir="vendor/smithay-client-toolkit"
	echo "Applying patch: $patch"
	patch -p1 -d "$dir" < "${patch}"

	echo "" >> Cargo.toml
	echo '[patch.crates-io]' >> Cargo.toml
	for crate in cpal smithay-client-toolkit softbuffer wayland-cursor wgpu-hal winit x11rb-protocol xkbcommon-dl; do
		echo "$crate = { path = \"./vendor/$crate\" }" >> Cargo.toml
	done
	echo "smithay-client-toolkit2 = { package = \"smithay-client-toolkit\", path = \"./vendor/smithay-client-toolkit-0.19.2\" }" >> Cargo.toml
	echo "" >> Cargo.toml
	echo '[patch."git+https://github.com/iced-rs/winit.git"]' >> Cargo.toml
	echo 'winit = { path = "./vendor/winit-iced" }' >> Cargo.toml
}

termux_step_make() {
	cargo build \
		--jobs "$TERMUX_PKG_MAKE_PROCESSES" \
		--target "$CARGO_TARGET_NAME" \
		--release \
		--example hnefatafl-client \
		--no-default-features
	
	if [[ "$TERMUX_ON_DEVICE_BUILD" == "true" ]]; then
		"target/$CARGO_TARGET_NAME/release/examples/hnefatafl-client" --man
		mkdir -p "$TERMUX_PKG_HOSTBUILD_DIR"
		cp hnefatafl-client.1 "$TERMUX_PKG_HOSTBUILD_DIR/"
	fi
}

termux_step_make_install() {
    install -Dm755 -t "$TERMUX_PREFIX/bin" \
		"target/$CARGO_TARGET_NAME/release/examples/hnefatafl-client"
	for size in 16 22 24 32 42 64 128 256; do
    	install -Dm644 "icons/king_${size}x${size}.png" \
			"$TERMUX_PREFIX/share/icons/hicolor/${size}x${size}/apps/org.hnefatafl.hnefatafl_client.png"
	done
    install -Dm644 "$TERMUX_PKG_HOSTBUILD_DIR/hnefatafl-client.1" \
		"$TERMUX_PREFIX/share/man/man1/hnefatafl-client.1"
    install -Dm644 packages/hnefatafl-client.desktop \
		"$TERMUX_PREFIX/share/applications/hnefatafl-client.desktop"
}
