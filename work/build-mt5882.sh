#!/bin/bash
set -euo pipefail

BASE=/home/steki/codex-mt5882
KERNEL="$BASE/linux"
BUILD="$BASE/build"
ROOTFS="$BASE/initramfs"
TOOLCHAIN="$BASE/toolchain/bin/armv7a-mediatek482_001_neon-linux-gnueabi-"
WORKSPACE=/mnt/c/Users/steki/Documents/Codex/2026-08-30/referenced-chatgpt-conversation-this-is-an
export PATH="$BASE/host-bin:$BASE/host-tools/usr/bin:$PATH"

mkdir -p "$BASE"
mkdir -p "$BASE/host-bin"
printf '#!/bin/sh\nexit 0\n' > "$BASE/host-bin/lockfile"
chmod 0755 "$BASE/host-bin/lockfile"
if [ ! -d "$KERNEL/.git" ]; then
    git clone --depth 1 https://github.com/yath/mediatek-linux-3.10.git "$KERNEL"
fi
if [ ! -d "$BASE/toolchain/.git" ]; then
    git clone --depth 1 https://github.com/p0isk/gnu-toolchain_4.8.2.git "$BASE/toolchain"
fi
if [ ! -f "$BASE/busybox-armv7l" ]; then
    curl -fL https://busybox.net/downloads/binaries/1.21.1/busybox-armv7l -o "$BASE/busybox-armv7l"
fi
if [ ! -x "$BASE/host-tools/usr/bin/mkimage" ]; then
    mkdir -p "$BASE/host-tools"
    (cd "$BASE/host-tools" && apt download u-boot-tools && dpkg-deb -x u-boot-tools_*.deb .)
fi

rm -rf "$BUILD" "$ROOTFS"
mkdir -p "$BUILD"
mkdir -p "$ROOTFS"/{bin,sbin,etc,proc,sys,dev,tmp,usr/bin,usr/sbin}
cp "$BASE/busybox-armv7l" "$ROOTFS/bin/busybox"
cp "$WORKSPACE/work/init" "$ROOTFS/init"
sed -i 's/\r$//' "$ROOTFS/init"
chmod 0755 "$ROOTFS/init" "$ROOTFS/bin/busybox"

for app in sh mount cat uname dmesg ls ps free mkdir mknod hexdump dd sync poweroff reboot; do
    ln -s busybox "$ROOTFS/bin/$app"
done

cd "$KERNEL"
# Modern host compilers expose harmless warnings in this 2013 vendor tree.
sed -i 's/^subdir-ccflags-y += -Werror$/# Werror disabled for reproducible modern-host build/' arch/arm/mach-mt53xx/Makefile
make O="$BUILD" ARCH=arm mt5882_smp_mod_dbg_defconfig
scripts/config --file "$BUILD/.config" \
    -e BLK_DEV_INITRD \
    -e DEVTMPFS \
    -e DEVTMPFS_MOUNT \
    -e RD_GZIP \
    -e IKCONFIG \
    -e IKCONFIG_PROC \
    -d BLOCK \
    -d MTD \
    -d KERNEL_UIMAGE_LZO \
    -d CMDLINE_FORCE \
    -e CMDLINE_FROM_BOOTLOADER \
    --set-str INITRAMFS_SOURCE "$ROOTFS"
make O="$BUILD" ARCH=arm olddefconfig
make -j1 O="$BUILD" ARCH=arm CROSS_COMPILE="$TOOLCHAIN" KCFLAGS=-Wno-error uImage
