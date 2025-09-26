TERMUX_PKG_HOMEPAGE=https://openjdk.java.net
TERMUX_PKG_DESCRIPTION="Java development kit and runtime"
TERMUX_PKG_LICENSE="GPL-2.0"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="22.0.2"
TERMUX_PKG_SRCURL=https://github.com/openjdk/jdk22u/archive/refs/tags/jdk-${TERMUX_PKG_VERSION}-ga.tar.gz
TERMUX_PKG_SHA256=c423015bda77bea13e0a13f4dc705972c2185c3c6e6e30b183f733f2b95aa1a4
TERMUX_PKG_AUTO_UPDATE=false
TERMUX_PKG_DEPENDS="libandroid-shmem, libandroid-spawn, libiconv, libjpeg-turbo, zlib, littlecms, alsa-plugins"
TERMUX_PKG_BUILD_DEPENDS="cups, fontconfig, libxrandr, libxt, xorgproto, alsa-lib"
# openjdk-22-x is recommended because X11 separation is still very experimental.
TERMUX_PKG_RECOMMENDS="ca-certificates-java, openjdk-22-x, resolv-conf"
TERMUX_PKG_SUGGESTS="cups"
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_HAS_DEBUG=false
# enable lto, but do not explicitly enable zgc or shenandoahgc because they
# are automatically enabled for x86, but are not supported for arm.
__jvm_features="link-time-opt"

termux_step_pre_configure() {
	unset JAVA_HOME
}

termux_step_configure() {
	local jdk_ldflags="-L${TERMUX_PREFIX}/lib \
		-Wl,-rpath=$TERMUX_PREFIX/lib/jvm/java-22-openjdk/lib \
		-Wl,-rpath=${TERMUX_PREFIX}/lib -Wl,--enable-new-dtags"
	bash ./configure \
		--disable-precompiled-headers \
		--disable-warnings-as-errors \
		--enable-option-checking=fatal \
		--with-version-pre="" \
		--with-version-opt="" \
		--with-jvm-variants=server \
		--with-jvm-features="${__jvm_features}" \
		--with-debug-level=release \
		--openjdk-target=$TERMUX_HOST_PLATFORM \
		--with-toolchain-type=clang \
		--with-extra-cflags="$CFLAGS $CPPFLAGS -DLE_STANDALONE -D__ANDROID__=1 -D__TERMUX__=1" \
		--with-extra-cxxflags="$CXXFLAGS $CPPFLAGS -DLE_STANDALONE -D__ANDROID__=1 -D__TERMUX__=1" \
		--with-extra-ldflags="${jdk_ldflags} -Wl,--as-needed -landroid-shmem -landroid-spawn -liconv" \
		--with-cups-include="$TERMUX_PREFIX/include" \
		--with-fontconfig-include="$TERMUX_PREFIX/include" \
		--with-freetype-include="$TERMUX_PREFIX/include/freetype2" \
		--with-freetype-lib="$TERMUX_PREFIX/lib" \
		--with-alsa="$TERMUX_PREFIX" \
		--with-alsa-include="$TERMUX_PREFIX/include/alsa" \
		--with-alsa-lib="$TERMUX_PREFIX/lib" \
		--with-x="$TERMUX_PREFIX/include/X11" \
		--x-includes="$TERMUX_PREFIX/include/X11" \
		--x-libraries="$TERMUX_PREFIX/lib" \
		--with-giflib=system \
		--with-lcms=system \
		--with-libjpeg=system \
		--with-libpng=system \
		--with-zlib=system \
		--with-vendor-name="Termux" \
		AR="$AR" \
		NM="$NM" \
		OBJCOPY="$OBJCOPY" \
		OBJDUMP="$OBJDUMP" \
		STRIP="$STRIP" \
		CXXFILT="llvm-cxxfilt" \
		BUILD_CC="$TERMUX_HOST_LLVM_BASE_DIR/bin/clang" \
		BUILD_CXX="$TERMUX_HOST_LLVM_BASE_DIR/bin/clang++" \
		BUILD_NM="$TERMUX_HOST_LLVM_BASE_DIR/bin/llvm-nm" \
		BUILD_AR="$TERMUX_HOST_LLVM_BASE_DIR/bin/llvm-ar" \
		BUILD_OBJCOPY="$TERMUX_HOST_LLVM_BASE_DIR/bin/llvm-objcopy" \
		BUILD_STRIP="$TERMUX_HOST_LLVM_BASE_DIR/bin/llvm-strip" \
		--with-jobs=$TERMUX_PKG_MAKE_PROCESSES
}

termux_step_make() {
	cd build/linux-${TERMUX_ARCH/i686/x86}-server-release
	make images
}

termux_step_make_install() {
	rm -rf  $TERMUX_PREFIX/lib/jvm/java-22-openjdk
	mkdir -p $TERMUX_PREFIX/lib/jvm/java-22-openjdk
	cp -r build/linux-${TERMUX_ARCH/i686/x86}-server-release/images/jdk/* \
		$TERMUX_PREFIX/lib/jvm/java-22-openjdk/
	find $TERMUX_PREFIX/lib/jvm/java-22-openjdk/ -name "*.debuginfo" -delete

	# Dependent projects may need JAVA_HOME.
	mkdir -p $TERMUX_PREFIX/lib/jvm/java-22-openjdk/etc/profile.d
	echo "export JAVA_HOME=$TERMUX_PREFIX/lib/jvm/java-22-openjdk/" > \
		$TERMUX_PREFIX/lib/jvm/java-22-openjdk/etc/profile.d/java.sh
}

termux_step_post_make_install() {
	cd $TERMUX_PREFIX/lib/jvm/java-22-openjdk/man/man1
	for manpage in *.1; do
		gzip "$manpage"
	done

	# Make sure that our alternatives file is up to date.
	binaries="$(find $TERMUX_PREFIX/lib/jvm/java-22-openjdk/bin -executable -type f | xargs -I{} basename "{}" | xargs echo)"
	manpages="$(find $TERMUX_PREFIX/lib/jvm/java-22-openjdk/man/man1 -name "*.1.gz" | xargs -I{} basename "{}" | xargs echo)"

	local failure=false
	for binary in $binaries; do
		grep -q "lib/jvm/java-22-openjdk/bin/${binary}$" "$TERMUX_PKG_BUILDER_DIR"/openjdk-22.alternatives || {
			echo "ERROR: Missing entry for binary: $binary in openjdk-22.alternatives"
			failure=true
		}
	done
	for manpage in $manpages; do
		grep -q "lib/jvm/java-22-openjdk/man/man1/${manpage}$" "$TERMUX_PKG_BUILDER_DIR"/openjdk-22.alternatives || {
			echo "ERROR: Missing entry for manpage: $manpage in openjdk-22.alternatives"
			failure=true
		}
	done
	if [[ "$failure" = true ]]; then
		termux_error_exit "ERROR: openjdk-22.alternatives is not up to date, please update it."
	fi
}
