termux_step_override_config_scripts() {
	[ "$TERMUX_ON_DEVICE_BUILD" = "true" ] && return
	# resolves many variants of "cannot execute binary file: Exec format error"

	# this copies if applicable, but if there is no host binary available
	# to copy, the binary is deleted or stubbed.
	handle_incompatible_binary() {
		prefix_binary="$1"
		binary_name="$(basename $prefix_binary)"
		unset host_binary


		# clean broken symbolic links left over from the previous passes
		if [ ! -e "$prefix_binary" ] ; then
			echo "${FUNCNAME[0]}: deleting broken symbolic link $prefix_binary"
			rm -f $prefix_binary
			return
		fi

		# if file is a text file, it is a script that is potentially
		# intentional and necessary for cross-compilation, and must not be deleted.
		# elixir is an edge case where it's hard to auto detect that it's a bionic libc binary,
		# because it is an extended chain of shell scripts that eventually
		# leads to the bionic libc binary file 
		# /data/data/com.termux/files/usr/lib/erlang/erts-15.1.2/bin/erlexec
		# so that needs to be either manually specified, or a smarter
		# binary detection method is needed.
		# also if the file is already a glibc binary, it does not need to be replaced.
		if file -b "$(readlink -f $prefix_binary)" | grep text >/dev/null || \
			file -b "$(readlink -f $prefix_binary)" | grep GNU >/dev/null; then
			if ! grep -q "elixir" <<< "$binary_name"; then
				return
			fi
		fi

		# if a host binary of the same name exists, 
		# set the host binary to the existing binary
		# "which" is necessary here instead of "command -v"
		# because "command -v" does not behave as needed here
		# for the commands "true" or "false"
		if which $binary_name >/dev/null; then
			host_binary="$(which $binary_name)"
		fi

		# the "config" part here is necessary to help ensure an error-free
		# setup of both the llvm-config and pg_config files later in the
		# outer function
		# (example of purpose of deleting the other files: 
		# "configure: error: C preprocessor "aarch64-linux-android-cpp" fails sanity check"
		# in libgnustep-base if aarch64-linux-android-cpp is permitted to symlink to /bin/true)
		# this is deliberately broad in order to fuzz for edge cases and make sure they
		# can all be handled using logic this broad [i.e. looking for binaries that are
		# actually necessary for detection by some package but contain the string "cpp" 
		# or "ar" or "nm" or "ld" in their names, etc])
		deletelist=()
		deletelist+=("cc")
		deletelist+=("config") # for outer function below this llvm-config and pkg_config
		deletelist+=("g++")
		deletelist+=("cpp") # configure: error: C preprocessor "aarch64-linux-android-cpp" fails sanity check in libgnustep-base
		deletelist+=("ranlib")
		deletelist+=("readelf")
		deletelist+=("strip")
		deletelist+=("lua") # fixes error in luarocks if any Termux lua version is installed newer than the newest in host
		deletelist+=("elixir") # /bin/sh: 1: elixirc: not found in atomvm
		# deletelist+=("clang") # do not delete - deleting breaks build of ccls
		# deletelist+=("ar") # do not delete - deleting breaks build of ccls
		# deletelist+=("ld") # do not delete - deleting breaks build of ccls
		# deletelist+=("nm") # do not delete - deleting breaks build of ccls
		# deletelist+=("objdump") # do not delete - deleting breaks build of ccls

		if [ -z ${host_binary+x} ]; then
			# if no appropriate host binary could be determined, check whether
			# the binary is in the delete list and if so, delete it and return
			for binary_to_delete in "${deletelist[@]}"; do
				if grep -q "$binary_to_delete" <<< "$binary_name"; then
					echo "${FUNCNAME[0]}: deleting binary $prefix_binary"
					rm -f $prefix_binary
					return
				fi
			done
			# if host binary not found but binary not in deletelist,
			# set host binary to /bin/true
			host_binary=/bin/true
		fi

		# if the host binary and prefix binary currently link to the same file, do nothing,
		if [ "$(readlink -f $host_binary)" == "$(readlink -f $prefix_binary)" ]; then
			return
		fi

		# copy host binary over the file (do not symlink since it would interfere with
		# reinstalling the same package, for example 
		# cp: cannot create regular file '/data/data/com.termux/files/usr/bin/zip': Permission denied)
		rm $prefix_binary
		echo "${FUNCNAME[0]}: copying $host_binary to $prefix_binary"
		install -Dm755 $host_binary $prefix_binary
	}
	export -f handle_incompatible_binary

	# Execute a single subshell that runs the function handle_incompatible_binary in a loop,
	# avoiding the use of the -exec argument to find because it was very slow for me due to
	# the excessive subshells. this still continues to get slower the more files are in
	# $TERMUX_PREFIX/bin, but not as much. making sure as many binaries are deleted as possible
	# also reduces the rate at which this gets slower.
	(
	while IFS= read -r -d '' prefix_binary; do
		handle_incompatible_binary "$prefix_binary"
	done < <(find "$TERMUX_PREFIX/bin" \( -type f -o -type l \) -executable -print0)
	)

	unset handle_incompatible_binary
	# from one perspective, the above block could be considered an expansion of the same logic
	# behind the line below this, but for everything in the usr/bin folder instead of only bin/sh

	# Make $TERMUX_PREFIX/bin/sh executable on the builder, so that build
	# scripts can assume that it works on both builder and host later on:
	ln -sf /bin/sh "$TERMUX_PREFIX/bin/sh"

	if [ "$TERMUX_PKG_DEPENDS" != "${TERMUX_PKG_DEPENDS/libllvm/}" ] ||
		[ "$TERMUX_PKG_BUILD_DEPENDS" != "${TERMUX_PKG_BUILD_DEPENDS/libllvm/}" ]; then
		LLVM_DEFAULT_TARGET_TRIPLE=$TERMUX_HOST_PLATFORM
		if [ $TERMUX_ARCH = "arm" ]; then
			LLVM_TARGET_ARCH=ARM
		elif [ $TERMUX_ARCH = "aarch64" ]; then
			LLVM_TARGET_ARCH=AArch64
		elif [ $TERMUX_ARCH = "i686" ]; then
			LLVM_TARGET_ARCH=X86
		elif [ $TERMUX_ARCH = "x86_64" ]; then
			LLVM_TARGET_ARCH=X86
		fi
		LIBLLVM_VERSION=$(. $TERMUX_SCRIPTDIR/packages/libllvm/build.sh; echo $TERMUX_PKG_VERSION)
		sed $TERMUX_SCRIPTDIR/packages/libllvm/llvm-config.in \
			-e "s|@TERMUX_PKG_VERSION@|$LIBLLVM_VERSION|g" \
			-e "s|@TERMUX_PREFIX@|$TERMUX_PREFIX|g" \
			-e "s|@LLVM_TARGET_ARCH@|$LLVM_TARGET_ARCH|g" \
			-e "s|@LLVM_DEFAULT_TARGET_TRIPLE@|$LLVM_DEFAULT_TARGET_TRIPLE|g" \
			-e "s|@TERMUX_ARCH@|$TERMUX_ARCH|g" > $TERMUX_PREFIX/bin/llvm-config
		chmod 755 $TERMUX_PREFIX/bin/llvm-config
	fi

	if [ "$TERMUX_PKG_DEPENDS" != "${TERMUX_PKG_DEPENDS/postgresql/}" ] ||
		[ "$TERMUX_PKG_BUILD_DEPENDS" != "${TERMUX_PKG_BUILD_DEPENDS/postgresql/}" ]; then
		local postgresql_version=$(. $TERMUX_SCRIPTDIR/packages/postgresql/build.sh; echo $TERMUX_PKG_VERSION)
		sed $TERMUX_SCRIPTDIR/packages/postgresql/pg_config.in \
			-e "s|@POSTGRESQL_VERSION@|$postgresql_version|g" \
			-e "s|@TERMUX_HOST_PLATFORM@|$TERMUX_HOST_PLATFORM|g" \
			-e "s|@TERMUX_PREFIX@|$TERMUX_PREFIX|g" > $TERMUX_PREFIX/bin/pg_config
		chmod 755 $TERMUX_PREFIX/bin/pg_config
	fi

	if [ "$TERMUX_PKG_DEPENDS" != "${TERMUX_PKG_DEPENDS/libprotobuf/}" ]; then
		rm -f $TERMUX_PREFIX/lib/cmake/protobuf/protobuf-targets{,-release}.cmake
		cp $TERMUX_PREFIX/opt/protobuf-cmake/shared/protobuf-targets{,-release}.cmake $TERMUX_PREFIX/lib/cmake/protobuf/
	elif [ "$TERMUX_PKG_BUILD_DEPENDS" != "${TERMUX_PKG_BUILD_DEPENDS/protobuf-static/}" ]; then
		rm -f $TERMUX_PREFIX/lib/cmake/protobuf/protobuf-targets{,-release}.cmake
		cp $TERMUX_PREFIX/opt/protobuf-cmake/static/protobuf-targets{,-release}.cmake $TERMUX_PREFIX/lib/cmake/protobuf/
	fi
}
