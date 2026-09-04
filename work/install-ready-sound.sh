#!/bin/sh
set -eu
src=/mnt/usb2/Condivisa/h32-ready-install
arch=/mnt/usb2/archlinux/rootfs
awk '$1=="/dev/sda2" && $2=="/" {ok=1} END{exit !ok}' /proc/mounts
if grep -q '/dev/mmc' /proc/mounts; then exit 1; fi
test ! -e /etc/init.d/S99zzzzready
test ! -e /usr/local/sbin/h32-ready-sound
test ! -e "$arch/usr/local/bin/h32-ready-check.py"
test ! -e /opt/h32-audio/ready.wav
sh -n "$src/h32-ready-sound"
sh -n "$src/S99zzzzready"
cp "$src/h32-ready-sound" /usr/local/sbin/h32-ready-sound
cp "$src/h32-ready-check.py" "$arch/usr/local/bin/h32-ready-check.py"
cp "$src/ready.wav" /opt/h32-audio/ready.wav
chmod 755 /usr/local/sbin/h32-ready-sound
chmod 644 "$arch/usr/local/bin/h32-ready-check.py" /opt/h32-audio/ready.wav
chown 0:0 /usr/local/sbin/h32-ready-sound "$arch/usr/local/bin/h32-ready-check.py" /opt/h32-audio/ready.wav
# Enable only after payload is completely installed.
cp "$src/S99zzzzready" /etc/init.d/S99zzzzready
chown 0:0 /etc/init.d/S99zzzzready
chmod 755 /etc/init.d/S99zzzzready
sync
echo H32_READY_SOUND_INSTALLED
