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

source_dir="$script_dir/.repos/hidapi"
for triple in "${triples[@]}"; do
    echo
    build_dir="$script_dir/.build/$(fn_os_arch_fromtriplet "$triple")/hidapi-shared"
    xroot_dir="$script_dir/.xroot/$(fn_os_arch_fromtriplet "$triple")"
    xroot_shared_dir="$script_dir/.xroot-shared/$(fn_os_arch_fromtriplet "$triple")"
    mkdir -p "$build_dir"
    echo "Building hidapi (shared) for $triple => $build_dir"
    pushd "$build_dir" >/dev/null 2>&1
    rm -rf "$build_dir/*"

    unset EXTRA_ARGS
    unset EXTRA_LDFLAGS

    if [ -n "$(fn_os_arch_fromtriplet $triple | grep macos)" ]; then
        echo "MACOSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET"
        echo "SDK_VERSION=$SDK_VERSION"
        CFLAGS="-include $script_dir/support/macos-common/forward-decl.h"
        LDFLAGS=""
        EXTRA_ARGS="-DCMAKE_INSTALL_NAME_DIR=@rpath"
    elif [ -n "$(fn_os_arch_fromtriplet $triple | grep windows)" ]; then
        CFLAGS=""
        LDFLAGS=""
    else
        CFLAGS="-fPIC"
        CFLAGS="$CFLAGS $(pkg-config --with-path="$xroot_dir/lib/pkgconfig" --static --cflags libudev)"
        LDFLAGS="-pthread"
        EXTRA_ARGS="-DHIDAPI_WITH_HIDRAW=ON -DHIDAPI_WITH_LIBUSB=OFF"
        EXTRA_LDFLAGS="$(pkg-config --with-path="$xroot_dir/lib/pkgconfig" --static --libs libudev)"
    fi

    rcmd cmake "$source_dir" \
        -DCMAKE_BUILD_TYPE=Release \
        -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$script_dir/support/$(fn_os_arch_fromtriplet "$triple")-toolchain.cmake" \
        -DCMAKE_PREFIX_PATH="$xroot_dir" \
        -DCMAKE_INSTALL_PREFIX="$xroot_shared_dir" \
        -DCMAKE_C_FLAGS="$CFLAGS" \
        -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
        -DCMAKE_SHARED_LINKER_FLAGS="${LDFLAGS}${EXTRA_LDFLAGS:+ ${EXTRA_LDFLAGS}}" \
        -DBUILD_SHARED_LIBS=ON \
        ${EXTRA_ARGS:-}
    rcmd cmake --build . --target install -- -j$(nproc)
    popd >/dev/null 2>&1
done
