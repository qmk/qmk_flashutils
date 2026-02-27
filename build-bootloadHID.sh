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

source_dir="$script_dir/.repos/bootloadHID"
if [ ! -d "$source_dir/commandline" ]; then
    mkdir -p "$source_dir"
    # Originally retrieved from https://www.obdev.at/downloads/vusb/bootloadHID.2012-12-08.tar.gz
    tar axf "$script_dir/.repos/bootloadHID.2012-12-08.tar.gz" -C "$source_dir" --strip-components=1
fi

for triple in "${triples[@]}"; do
    echo
    build_dir="$script_dir/.build/$(fn_os_arch_fromtriplet "$triple")/bootloadHID"
    xroot_dir="$script_dir/.xroot/$(fn_os_arch_fromtriplet "$triple")"
    mkdir -p "$build_dir"
    echo "Building bootloadHID for $triple => $build_dir"
    pushd "$source_dir/commandline" >/dev/null 2>&1
    rm -rf "$build_dir/*"

    CFLAGS=$(pkg-config --with-path="$xroot_dir/lib/pkgconfig" --static --cflags libusb-1.0)
    LDFLAGS=$(pkg-config --with-path="$xroot_dir/lib/pkgconfig" --static --libs libusb-1.0)

    # bootloadHID includes `libusb-1.0` in its paths, so we need the parent.
    CFLAGS="$CFLAGS -I$xroot_dir/include"

    if [ -n "$(fn_os_arch_fromtriplet $triple | grep macos)" ]; then
        echo "MACOSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET"
        echo "SDK_VERSION=$SDK_VERSION"
    elif [ -n "$(fn_os_arch_fromtriplet $triple | grep windows)" ]; then
        CFLAGS="$CFLAGS -static"
        LDFLAGS="$LDFLAGS -static -lhid -lusb -lsetupapi"
    else
        CFLAGS="$CFLAGS -static"
        LDFLAGS="$LDFLAGS -static"
    fi

    rcmd make clean
    rcmd rm -f bootloadHID bootloadHID.exe || true
    rcmd make CC="${triple}-gcc" CXX="${triple}-g++" USBLIBS="-lusb $LDFLAGS" USBFLAGS="$CFLAGS"
    rcmd cp bootloadHID* "$xroot_dir/bin"
    popd >/dev/null 2>&1
done
