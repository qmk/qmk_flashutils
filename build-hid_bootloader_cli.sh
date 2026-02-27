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

source_dir="$script_dir/.repos/hid_bootloader_cli"
pushd "$source_dir" >/dev/null 2>&1
{ patch -f -s -p1 <"$script_dir/support/hid_bootloader_cli/mods.patch"; } || true
popd >/dev/null 2>&1

for triple in "${triples[@]}"; do
    echo
    build_dir="$script_dir/.build/$(fn_os_arch_fromtriplet "$triple")/hid_bootloader_cli"
    xroot_dir="$script_dir/.xroot/$(fn_os_arch_fromtriplet "$triple")"
    mkdir -p "$build_dir"
    echo "Building hid_bootloader_cli for $triple => $build_dir"
    rm -rf "$build_dir/*"

    CFLAGS="$(pkg-config --with-path="$xroot_dir/lib/pkgconfig" --static --cflags libusb) -I$script_dir/support/hid_bootloader_cli"
    LDFLAGS="$(pkg-config --with-path="$xroot_dir/lib/pkgconfig" --static --libs libusb) -L$xroot_dir/lib"

    pushd "$source_dir/Bootloaders/HID/HostLoaderApp" >/dev/null 2>&1

    if [ -n "$(fn_os_arch_fromtriplet $triple | grep windows)" ]; then
        OS=WINDOWS
        unset SDK
        CFLAGS="-static $CFLAGS"
        LDFLAGS="-static $LDFLAGS"
    elif [ -n "$(fn_os_arch_fromtriplet $triple | grep macos)" ]; then
        OS=MACOSX
        SDK=/sdk
    else
        OS=LINUX
        unset SDK
        CFLAGS="-static $CFLAGS"
        LDFLAGS="-static $LDFLAGS"
    fi

    rcmd make clean
    rcmd make -j$(nproc) OBJDIR="$build_dir" CC="${triple}-gcc" OS=${OS:-} SDK=${SDK:-} CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" USE_LIBUSB=YES OUTDIR="$build_dir"
    rcmd cp "$build_dir/hid_bootloader_cli"* "$xroot_dir/bin"
    popd >/dev/null 2>&1
done
