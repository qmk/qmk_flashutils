#!/usr/bin/env bash
# Copyright 2024-2026 Nick Brassel (@tzarc)
# SPDX-License-Identifier: GPL-2.0-or-later

set -eEuo pipefail

this_script=$(realpath "${BASH_SOURCE[0]}")
script_dir=$(dirname "$this_script")
source "$script_dir/common.bashinc"
cd "$script_dir"

./build-libusb.sh
./build-libusb-compat.sh
./build-hidapi.sh
./build-hidapi-shared.sh
./build-libftdi.sh
./build-libserialport.sh
./build-dfu-programmer.sh
./build-dfu-util.sh
./build-avrdude.sh
./build-mdloader.sh
./build-teensyloader.sh
./build-bootloadHID.sh
./build-hid_bootloader_cli.sh
./build-wb32-dfu-updater_cli.sh

ls -1alR "$script_dir/.xroot"
ls -1alR "$script_dir/.xroot-shared"

./repack.sh
./repack-hidapi-shared.sh
