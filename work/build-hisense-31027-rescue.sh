#!/bin/bash
set -euo pipefail

base=/home/steki/codex-mt5882
kernel="$base/SmartTV-Series5/linux-3.10"
output="$base/build-hisense-31027-rescue"
cross="$base/toolchain/bin/armv7a-mediatek482_001_neon-linux-gnueabi-"

export PATH="$base/host-tools/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

install -D -m 0755 /mnt/c/Users/steki/Documents/Codex/2026-08-30/referenced-chatgpt-conversation-this-is-an/work/lockfile "$base/host-bin/lockfile"
export PATH="$base/host-bin:$PATH"

mkdir -p "$output"
make -C "$kernel" O="$output" ARCH=arm mt5882_smp_mod_defconfig

"$kernel/scripts/config" --file "$output/.config" \
    -e BLK_DEV_INITRD \
    -e RD_GZIP \
    -e IKCONFIG \
    -e IKCONFIG_PROC \
    -e DEVTMPFS \
    -e DEVTMPFS_MOUNT \
    -e MTKMSDC_DRIVER_COMMON \
    -e MMC \
    -e MMC_BLOCK \
    -e MTKEMMC_BOOT \
    -e MTKMSDC_PARTITION \
    -e USB_STORAGE \
    -e EXT4_FS \
    -d MTD \
    -d APANIC \
    -e CMDLINE_FROM_BOOTLOADER \
    -d CMDLINE_FORCE \
    --set-str INITRAMFS_SOURCE "" \
    -k -e USB_MTK53xx_HCD

make -C "$kernel" O="$output" ARCH=arm olddefconfig
make -C "$kernel" O="$output" ARCH=arm CROSS_COMPILE="$cross" KCFLAGS=-Wno-error -j4 uImage LOADADDR=0x00007fc0

"$base/host-tools/usr/bin/mkimage" -l "$output/arch/arm/boot/uImage"
sha256sum "$output/arch/arm/boot/uImage"
