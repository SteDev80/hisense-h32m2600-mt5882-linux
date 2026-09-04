#!/bin/sh
set -eu
stage=${1:?extracted package directory required}
case "$stage" in /mnt/usb2/h32-vendor-v1) ;; *) exit 1 ;; esac
awk '$1=="/dev/sda2" && $2=="/mnt/usb2" && $3=="ext4" && $4 ~ /^rw(,|$)/ {ok=1} END {exit !ok}' /proc/mounts
grep -q Lexar /sys/block/sda/device/vendor
cd "$stage"
sha256sum -c SHA256SUMS >/run/h32-vendor-package-check.log
source=/mnt/p27/h32linux/rootfs
target=/mnt/usb2/h32linux-vendor-v1
test -x "$source/sbin/init"
test ! -e "$target"
mkdir "$target"
echo 'Copying current Buildroot to a new USB-only root...'
cp -a "$source" "$target/rootfs"
cp -a "$stage/overlay/." "$target/rootfs/"
old_init="$target/rootfs/etc/init.d/S99mt5882.pre-homeassistant"
if [ -f "$old_init" ]; then
    mv "$old_init" "$target/rootfs/opt/h32-vendor/disabled-S99mt5882.pre-homeassistant"
fi
chmod 755 "$target/rootfs/etc/init.d/S97vendor-wifi" "$target/rootfs/etc/init.d/S99mt5882" "$target/rootfs/usr/local/sbin/h32-vendor-wifi"
mkdir -p /run/h32-vendor-fat
mount -t vfat -o ro /dev/sda1 /run/h32-vendor-fat
mount -o remount,rw /run/h32-vendor-fat
fat=/run/h32-vendor-fat
grep -qx 'H32LINUX-MT5882-7642-V1' "$fat/H32LINUX.KEY"
test ! -e "$fat/uInitrd-h32m2600-usb-vendor-v1"
cp "$stage/uInitrd-h32m2600-usb-vendor-v1" "$fat/uInitrd-h32m2600-usb-vendor-v1"
expected=$(sha256sum "$stage/uInitrd-h32m2600-usb-vendor-v1"); expected=${expected%% *}
actual=$(sha256sum "$fat/uInitrd-h32m2600-usb-vendor-v1"); actual=${actual%% *}
test "$actual" = "$expected"
mount -o remount,ro "$fat"
umount "$fat"
echo 'USB_VENDOR_INSTALL_OK'
echo 'Original p27 root, old bootstrap and kernel preserved.'
