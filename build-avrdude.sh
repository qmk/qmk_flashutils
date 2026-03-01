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

source_dir="$script_dir/.repos/avrdude"
for triple in "${triples[@]}"; do
    echo
    build_dir="$script_dir/.build/$(fn_os_arch_fromtriplet "$triple")/avrdude"
    xroot_dir="$script_dir/.xroot/$(fn_os_arch_fromtriplet "$triple")"
    mkdir -p "$build_dir"
    echo "Building avrdude for $triple => $build_dir"
    pushd "$build_dir" >/dev/null 2>&1
    rm -rf "$build_dir/*"

    CFLAGS=$(pkg-config --with-path="$xroot_dir/lib/pkgconfig" --static --cflags libusb-1.0 libserialport)
    LDFLAGS=$(pkg-config --with-path="$xroot_dir/lib/pkgconfig" --static --libs libusb-1.0 libserialport)
    STANDARD_LIBS=""

    if [ -n "$(fn_os_arch_fromtriplet $triple | grep macos)" ]; then
        echo "MACOSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET"
        echo "SDK_VERSION=$SDK_VERSION"
    elif [ -n "$(fn_os_arch_fromtriplet $triple | grep windows)" ]; then
        CFLAGS="$CFLAGS -static"
        LDFLAGS="$LDFLAGS -static -pthread"
    else
        CFLAGS="$CFLAGS -static"
        LDFLAGS="$LDFLAGS -static -pthread"
        # hidapi-hidraw needs libudev — place after all target_link_libraries entries
        STANDARD_LIBS="-ludev"
    fi

    rcmd cmake "$source_dir" \
        -DCMAKE_BUILD_TYPE=Release \
        -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$script_dir/support/$(fn_os_arch_fromtriplet "$triple")-toolchain.cmake" \
        -DCMAKE_PREFIX_PATH="$xroot_dir" \
        -DCMAKE_INSTALL_PREFIX="$xroot_dir" \
        -DCMAKE_C_FLAGS="$CFLAGS" \
        -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
        -DCMAKE_C_STANDARD_LIBRARIES="$STANDARD_LIBS"
    rcmd cmake --build . --target install -- -j$(nproc)
    popd >/dev/null 2>&1
done
