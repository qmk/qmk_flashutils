#!/usr/bin/env bash
# Copyright 2024-2025 Nick Brassel (@tzarc)
# SPDX-License-Identifier: GPL-2.0-or-later

set -eEuo pipefail

this_script=$(realpath "${BASH_SOURCE[0]}")
script_dir=$(dirname "$this_script")
source "$script_dir/common.bashinc"
cd "$script_dir"

build_one_help "$@"
respawn_docker_if_needed "$@"

source_dir="$script_dir/.repos/libftdi"
for triple in "${triples[@]}"; do
    echo
    build_dir="$script_dir/.build/$(fn_os_arch_fromtriplet "$triple")/libftdi"
    xroot_dir="$script_dir/.xroot/$(fn_os_arch_fromtriplet "$triple")"
    mkdir -p "$build_dir"
    echo "Building libftdi for $triple => $build_dir"
    pushd "$build_dir" >/dev/null 2>&1
    rm -rf "$build_dir/*"

    CFLAGS="-fPIC $(pkg-config --with-path="$xroot_dir/lib/pkgconfig" --static --cflags libusb-1.0)"
    LDFLAGS="-fPIC $(pkg-config --with-path="$xroot_dir/lib/pkgconfig" --static --libs libusb-1.0)"

    if [ -z "$(fn_os_arch_fromtriplet $triple | grep macos)" ]; then
        CFLAGS="$CFLAGS"
        LDFLAGS="$LDFLAGS -pthread"
    else
        echo "MACOSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET"
        echo "SDK_VERSION=$SDK_VERSION"
    fi

    rcmd cmake "$source_dir" -DCMAKE_BUILD_TYPE=Release -G Ninja -DCMAKE_TOOLCHAIN_FILE="$script_dir/support/$(fn_os_arch_fromtriplet "$triple")-toolchain.cmake" -DCMAKE_PREFIX_PATH="$xroot_dir" -DCMAKE_INSTALL_PREFIX="$xroot_dir" -DCMAKE_INSTALL_LIBDIR="$xroot_dir/lib" -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" -DSTATICLIBS=ON -DDOCUMENTATION=OFF -DBUILD_TESTS=OFF -DFTDIPP=OFF -DPYTHON_BINDINGS=OFF -DFTDI_EEPROM=OFF -DEXAMPLES=OFF
    rcmd cmake --build . --target ftdi1-static -- -j$(nproc)
    rcmd cmake --install . --component staticlibs
    rcmd cmake --install . --component headers
    popd >/dev/null 2>&1
done
