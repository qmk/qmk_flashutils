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

source_dir="$script_dir/.repos/eudev"
if [ ! -e "$source_dir/configure" ]; then
    pushd "$source_dir" >/dev/null 2>&1
    autoreconf -f -i -s
    popd >/dev/null 2>&1
fi

for triple in "${triples[@]}"; do
    # Only build for Linux targets
    if [ -z "$(fn_os_arch_fromtriplet $triple | grep linux)" ]; then
        continue
    fi

    echo
    build_dir="$script_dir/.build/$(fn_os_arch_fromtriplet "$triple")/eudev"
    xroot_dir="$script_dir/.xroot/$(fn_os_arch_fromtriplet "$triple")"
    mkdir -p "$build_dir"
    echo "Building eudev for $triple => $build_dir"
    pushd "$build_dir" >/dev/null 2>&1
    rm -rf "$build_dir/*"

    rcmd "$source_dir/configure" \
        --prefix="$xroot_dir" \
        --host=$triple \
        --enable-static \
        --disable-shared \
        --disable-programs \
        --disable-blkid \
        --disable-selinux \
        --disable-kmod \
        --disable-mtd_probe \
        --disable-manpages \
        --disable-hwdb \
        CC="${triple}-gcc" \
        CXX="${triple}-g++" \
        CFLAGS="-fPIC"
    rcmd make clean
    rcmd make -j$(nproc) install
    popd >/dev/null 2>&1
done
