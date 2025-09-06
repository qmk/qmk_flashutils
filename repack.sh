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

for triple in "${triples[@]}"; do
    xroot_dir="$script_dir/.xroot/$(fn_os_arch_fromtriplet "$triple")"
    pkg_dir="$script_dir/.pkg/$(fn_os_arch_fromtriplet "$triple")"

    if [ -n "$(fn_os_arch_fromtriplet $triple | grep macos)" ]; then
        STRIP="${triple}-strip"
    else
        STRIP="${triple}-strip -s"
    fi

    ls -1 "$xroot_dir/bin" | while read -r bin; do
        echo "Stripping $bin"
        rcmd ${STRIP} "$xroot_dir/bin/$bin" || true

        if [ -n "$(fn_os_arch_fromtriplet $triple | grep macos)" ]; then
            rcmd rcodesign sign --runtime-version 12.0.0 --code-signature-flags runtime "$xroot_dir/bin/$bin" || true
        fi
    done

    rcmd rm -rf "$pkg_dir" || true
    rcmd mkdir -p "$pkg_dir"
    rcmd rsync -a --exclude=libusb-config --exclude=elf2tag "$xroot_dir/bin/" "$pkg_dir/"
    rcmd rsync -a "$xroot_dir/etc/" "$pkg_dir/"

    echo "FLASHUTILS_HOST=$(fn_os_arch_fromtriplet $triple)" >"$pkg_dir/flashutils_release_$(fn_os_arch_fromtriplet $triple)"
    echo "COMMIT_DATE=$(date -u -d "$(git show --no-patch --format=%cI HEAD)" +%Y-%m-%dT%H:%M:%SZ)" >>"$pkg_dir/flashutils_release_$(fn_os_arch_fromtriplet $triple)"
    echo "COMMIT_HASH=$(git describe --always --dirty --exclude '*')" >>"$pkg_dir/flashutils_release_$(fn_os_arch_fromtriplet $triple)"

    rcmd tar acvf "$script_dir/qmk_flashutils-$(fn_os_arch_fromtriplet "$triple").tar.zst" -C "$pkg_dir" .
done

# Make fat binaries for macOS
mkdir -p "$script_dir/.pkg/macosUNIVERSAL"
for bin in "$script_dir"/.pkg/macosX64/*; do
    if [ -x "$bin" ]; then
        echo "Creating fat binary for $bin"
        rcmd aarch64-apple-darwin24-lipo -create -output "$script_dir/.pkg/macosUNIVERSAL/$(basename "${bin}")" "$bin" "$script_dir/.pkg/macosARM64/$(basename "$bin")"
        rcmd rcodesign sign --runtime-version 12.0.0 --code-signature-flags runtime "$script_dir/.pkg/macosUNIVERSAL/$(basename "${bin}")" || true
        aarch64-apple-darwin24-lipo -info "$script_dir/.pkg/macosUNIVERSAL/$(basename "${bin}")"
    else
        cp "$bin" "$script_dir/.pkg/macosUNIVERSAL/"
    fi
done

rm -f "$script_dir/.pkg/macosUNIVERSAL/flashutils_release"* || true
echo "FLASHUTILS_HOST=macosUNIVERSAL" >"$script_dir/.pkg/macosUNIVERSAL/flashutils_release_macosUNIVERSAL"
echo "COMMIT_DATE=$(date -u -d "$(git show --no-patch --format=%cI HEAD)" +%Y-%m-%dT%H:%M:%SZ)" >>"$script_dir/.pkg/macosUNIVERSAL/flashutils_release_macosUNIVERSAL"
echo "COMMIT_HASH=$(git describe --always --dirty --exclude '*')" >>"$script_dir/.pkg/macosUNIVERSAL/flashutils_release_macosUNIVERSAL"

rcmd tar acvf "$script_dir/qmk_flashutils-macosUNIVERSAL.tar.zst" -C "$script_dir/.pkg/macosUNIVERSAL" .

