# QMK Flashing Utilities

Builds of firmware flashing utilities primarily for QMK Firmware use.

Currently provides:

* `avrdude`
* `bootloadHID`
* `dfu-programmer`
* `dfu-util`
* `hid_bootloader_cli`
* `mdloader`
* `teensy_loader_cli`
* `wb32-dfu-updater_cli`

...for the OS/architectures:

* Linux x86_64
* Linux aarch64 (arm64)
* Linux riscv64
* macOS aarch64 (arm64)
* macOS x86_64
* Windows x86_64

Builds require the toolchains provided by the container `ghcr.io/tzarc/qmk_toolchains:builder`; this repo must be mounted on `/t` inside the container -- the user/group permissions inside the container will be updated to match during execution.

Corresponding builds are done on GitHub actions.
