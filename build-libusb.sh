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

rcmd() {
    echo "Running: $*"
    "$@"
}

triples=(
    x86_64-qmk-linux-gnu
    aarch64-unknown-linux-gnu
    riscv64-unknown-linux-gnu
    x86_64-w64-mingw32
    aarch64-apple-darwin24
    x86_64-apple-darwin24
)

source_dir="$script_dir/.repos/libusb"
if [ ! -e "$source_dir/configure" ]; then
    pushd "$source_dir" >/dev/null 2>&1
    ./bootstrap.sh
    popd >/dev/null 2>&1
fi

for triple in "${triples[@]}"; do
    echo
    build_dir="$script_dir/.build/$(fn_os_arch_fromtriplet "$triple")/libusb"
    xroot_dir="$script_dir/.xroot/$(fn_os_arch_fromtriplet "$triple")"
    mkdir -p "$build_dir"
    echo "Building libusb for $triple => $build_dir"
    pushd "$build_dir" >/dev/null 2>&1
    rm -rf "$build_dir/*"
    rcmd "$source_dir/configure" --prefix="$xroot_dir" --host=$triple --enable-shared=no --enable-static --disable-udev CC="${triple}-gcc" CXX="${triple}-g++" CFLAGS="-fPIC" LDFLAGS="-fPIC"
    make clean
    make -j$(nproc) install
    popd >/dev/null 2>&1
done
