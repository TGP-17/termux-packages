# For self-contained 3-stage-bootstraps and some hostbuild-steps
# Unsets all possible references to the bionic libc toolchain
# from the build environment of a non-bionic-libc-linked build,
# or a package that otherwise sets up its own toolchain environment
# variables.
# This intentionally includes many variables that would seem
# unimportant, but which I have included as a universal catch-all
# by reading the full environment variable list printed by the
# "env" command and attempting to identify every possible variable
# containing a string that makes references to something that could 
# be considered part of or connected to the bionic libc toolchain in any way.
# "TERMUX_XXX" variables are extremely unlikely to be checked for by
# the source code of an upstream project that already needs this function,
# so should not be completely "unset" here but instead handled separately

termux_disable_bionic() {
    unset \
        AR \
        AS \
        CC \
        CFLAGS \
        CPP \
        CPPFLAGS \
        CXX \
        CXXFILT \
        CXXFLAGS \
        LD \
        LDFLAGS \
        NM \
        OBJCOPY \
        OBJDUMP \
        PKG_CONFIG \
        PKG_CONFIG_LIBDIR \
        PKGCONFIG \
        prefix \
        PREFIX \
        RANLIB \
        READELF \
        STRIP \
        CGO_CFLAGS \
        CGO_ENABLED \
        CGO_LDFLAGS \
        GO_LDFLAGS \
        GOARCH \
        GOOS \
        RUSTFLAGS
    
    # This is necessary to avoid using the bionic portion of
    # termux_step_massage on zig or zig programs, which I believe 
    # are not linked to bionic libc at time of writing.
    # packages I believe this affects at time of writing:
    # - zig
    # - ncdu2 (a zig program)
    if [[ "${TERMUX_PACKAGE_LIBRARY}" == "bionic" ]]; then
        TERMUX_PACKAGE_LIBRARY="unknown"
    fi

    # remove any folder containing "android" (crossbuild host's 
    # compiler root folder: "/home/builder/.termux-build/_cache/android-r27b-api-24-v1/bin") 
    # from PATH in order to prevent the "pkg-config" script contained
    # inside from being invoked and polluting the hostbuild-step
    # with the $TERMUX_PREFIX/lib folder containing potentially-ARM 
    # libraries linked against bionic libc
    # TODO: when the zig package successfully builds with cross-compilation
    # disabled, update this to find some way to correctly hide pkg-config
    # from that zig build.
    export PATH=$(
        declare -a path_dirs
        IFS=':'
        read -a path_dirs <<<"$PATH"
        IFS=' '
        PATH=""
        for dir in ${path_dirs[@]}; do
            if [[ $dir == *"android"* ]]; then
                continue
            else
                PATH=$dir:$PATH
            fi
        done
        echo $PATH | sed 's/.$//'
    )
}
