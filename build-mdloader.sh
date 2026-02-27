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

source_dir="$script_dir/.repos/mdloader"
for triple in "${triples[@]}"; do
    echo
    build_dir="$script_dir/.build/$(fn_os_arch_fromtriplet "$triple")/mdloader"
    xroot_dir="$script_dir/.xroot/$(fn_os_arch_fromtriplet "$triple")"
    mkdir -p "$build_dir"
    echo "Building mdloader for $triple => $build_dir"
    rm -rf "$build_dir/*"
    pushd "$source_dir" >/dev/null 2>&1

    if [ -n "$(fn_os_arch_fromtriplet $triple | grep windows)" ]; then
        OS=Windows_NT
        CFLAGS="-static"
        LDFLAGS="-static"
    elif [ -n "$(fn_os_arch_fromtriplet $triple | grep macos)" ]; then
        unset OS
        unset CFLAGS
        unset LDFLAGS
    else
        unset OS
        CFLAGS="-static"
        LDFLAGS="-static"
    fi

    rcmd make clean
    rcmd make -j$(nproc) OBJDIR="$build_dir" CC="${triple}-gcc" CXX="${triple}-g++" OS=${OS:-} CFLAGS="${CFLAGS:-}" LDFLAGS="${LDFLAGS:-}"
    rcmd cp "$build_dir/mdloader"* "$xroot_dir/bin"
    popd >/dev/null 2>&1
done
