#!/usr/bin/env bash
# Copyright 2024-2026 Nick Brassel (@tzarc)
# SPDX-License-Identifier: GPL-2.0-or-later

set -eEuo pipefail

this_script=$(realpath "${BASH_SOURCE[0]}")
script_dir=$(dirname "$this_script")
source "$script_dir/common.bashinc"
cd "$script_dir"

build_one_help "$@"
respawn_docker_if_needed "$@"

source_dir="$script_dir/.repos/picotool"
pico_sdk_dir="$script_dir/.repos/pico-sdk"

for triple in "${triples[@]}"; do
    echo
    build_dir="$script_dir/.build/$(fn_os_arch_fromtriplet "$triple")/picotool"
    xroot_dir="$script_dir/.xroot/$(fn_os_arch_fromtriplet "$triple")"
    mkdir -p "$build_dir"
    echo "Building picotool for $triple => $build_dir"
    pushd "$build_dir" >/dev/null 2>&1
    rm -rf "$build_dir/*"

    # Explicitly set libusb paths to ensure the cross-compiled version is found
    # rather than the host system's libusb
    LIBUSB_INCLUDE_DIR="$xroot_dir/include/libusb-1.0"
    LIBUSB_LIBRARIES="$xroot_dir/lib/libusb-1.0.a"

    CFLAGS=$(pkg-config --with-path="$xroot_dir/lib/pkgconfig" --static --cflags libusb-1.0)
    LDFLAGS=$(pkg-config --with-path="$xroot_dir/lib/pkgconfig" --static --libs libusb-1.0)

    if [ -n "$(fn_os_arch_fromtriplet $triple | grep macos)" ]; then
        echo "MACOSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET"
        echo "SDK_VERSION=$SDK_VERSION"
        CFLAGS="$CFLAGS -include $script_dir/support/macos-common/forward-decl.h"
        LDFLAGS="$LDFLAGS -static-libstdc++ -static-libgcc"
    elif [ -n "$(fn_os_arch_fromtriplet $triple | grep windows)" ]; then
        CFLAGS="$CFLAGS -static"
        LDFLAGS="$LDFLAGS -static -pthread"
    else
        CFLAGS="$CFLAGS -static"
        LDFLAGS="$LDFLAGS -static -pthread"
    fi

    rcmd cmake "$source_dir" \
        -DCMAKE_BUILD_TYPE=MinSizeRel \
        -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$script_dir/support/$(fn_os_arch_fromtriplet "$triple")-toolchain.cmake" \
        -DCMAKE_PREFIX_PATH="$xroot_dir" \
        -DCMAKE_INSTALL_PREFIX="$xroot_dir" \
        -DCMAKE_C_FLAGS="$CFLAGS" \
        -DCMAKE_CXX_FLAGS="$CFLAGS" \
        -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
        -DPICO_SDK_PATH="$pico_sdk_dir" \
        -DUSE_PRECOMPILED=ON \
        -DPICOTOOL_NO_LIBUSB=OFF \
        -DBUILD_SHARED_LIBS=OFF \
        -DLIBUSB_INCLUDE_DIR="$LIBUSB_INCLUDE_DIR" \
        -DLIBUSB_LIBRARIES="$LIBUSB_LIBRARIES"
    rcmd cmake --build . --target install -- -j$(nproc)
    popd >/dev/null 2>&1
done
