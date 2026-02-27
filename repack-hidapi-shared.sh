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

COMMIT_DATE=$(date -u -d "$(git show --no-patch --format=%cI HEAD)" +%Y-%m-%dT%H:%M:%SZ)

for triple in "${triples[@]}"; do
    xroot_shared_dir="$script_dir/.xroot-shared/$(fn_os_arch_fromtriplet "$triple")"
    pkg_dir="$script_dir/.pkg-hidapi/$(fn_os_arch_fromtriplet "$triple")"

    if [ -n "$(fn_os_arch_fromtriplet $triple | grep macos)" ]; then
        STRIP="${triple}-strip"
        lib_name="libhidapi.dylib"
    elif [ -n "$(fn_os_arch_fromtriplet $triple | grep windows)" ]; then
        STRIP="${triple}-strip -s"
        lib_name="hidapi.dll"
    else
        STRIP="${triple}-strip -s"
        lib_name="libhidapi.so"
    fi

    rcmd rm -rf "$pkg_dir" || true
    rcmd mkdir -p "$pkg_dir"

    # Find and copy the shared library, renaming if necessary
    if [ -n "$(fn_os_arch_fromtriplet $triple | grep linux)" ]; then
        # Linux builds produce libhidapi-libusb.so*, we need libhidapi.so
        src_lib=$(find "$xroot_shared_dir/lib" -name 'libhidapi-libusb.so*' -not -type l | head -1)
        if [ -z "$src_lib" ]; then
            src_lib=$(find "$xroot_shared_dir/lib" -name 'libhidapi*.so*' -not -type l | head -1)
        fi
        cp "$src_lib" "$pkg_dir/$lib_name"
    elif [ -n "$(fn_os_arch_fromtriplet $triple | grep windows)" ]; then
        src_lib=$(find "$xroot_shared_dir" -name 'hidapi.dll' -o -name 'libhidapi.dll' | head -1)
        cp "$src_lib" "$pkg_dir/$lib_name"
    else
        src_lib=$(find "$xroot_shared_dir/lib" -name 'libhidapi*.dylib' -not -type l | head -1)
        cp "$src_lib" "$pkg_dir/$lib_name"
    fi

    echo "Stripping $lib_name"
    rcmd ${STRIP} "$pkg_dir/$lib_name" || true

    if [ -n "$(fn_os_arch_fromtriplet $triple | grep macos)" ]; then
        rcmd rcodesign sign --runtime-version 12.0.0 --code-signature-flags runtime "$pkg_dir/$lib_name" || true
    fi

    rcmd tar acvf "$script_dir/qmk_hidapi-$(fn_os_arch_fromtriplet "$triple").tar.zst" \
        --sort=name --format=posix --pax-option='exthdr.name=%d/PaxHeaders/%f' --pax-option='delete=atime,delete=ctime' \
        --clamp-mtime --mtime="${COMMIT_DATE}" --numeric-owner --owner=0 --group=0 --mode='go+u,go-w' \
        -C "$pkg_dir" .
done

# Make fat dylib for macOS Universal
mkdir -p "$script_dir/.pkg-hidapi/macosUNIVERSAL"
echo "Creating fat dylib for libhidapi.dylib"
rcmd aarch64-apple-darwin24-lipo -create \
    -output "$script_dir/.pkg-hidapi/macosUNIVERSAL/libhidapi.dylib" \
    "$script_dir/.pkg-hidapi/macosX64/libhidapi.dylib" \
    "$script_dir/.pkg-hidapi/macosARM64/libhidapi.dylib"
rcmd rcodesign sign --runtime-version 12.0.0 --code-signature-flags runtime "$script_dir/.pkg-hidapi/macosUNIVERSAL/libhidapi.dylib" || true
aarch64-apple-darwin24-lipo -info "$script_dir/.pkg-hidapi/macosUNIVERSAL/libhidapi.dylib"

rcmd tar acvf "$script_dir/qmk_hidapi-macosUNIVERSAL.tar.zst" \
    --sort=name --format=posix --pax-option='exthdr.name=%d/PaxHeaders/%f' --pax-option='delete=atime,delete=ctime' \
    --clamp-mtime --mtime="${COMMIT_DATE}" --numeric-owner --owner=0 --group=0 --mode='go+u,go-w' \
    -C "$script_dir/.pkg-hidapi/macosUNIVERSAL" .
