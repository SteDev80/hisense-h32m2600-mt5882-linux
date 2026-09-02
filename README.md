# Hisense H32M2600 / MediaTek MT5882 Linux experiments

Experimental tooling for booting a separate ARMv7 Linux environment on a
Hisense H32M2600 television with a MediaTek MT5882 (Capri) SoC.

The project currently includes:

- a minimal Buildroot rescue system and rootfs overlay;
- scripts for preparing and checking a two-partition USB drive;
- non-persistent U-Boot/UART boot helpers for Windows;
- an experimental Arch Linux ARM userspace supervised by Buildroot;
- a Windows Forms boot selector for choosing the test environment over TTL;
- launch helpers for VNC and Home Assistant Core.

## Safety model

The intended workflow does **not** modify U-Boot. Boot variables are changed in
RAM only and are lost at power-off. The scripts intentionally avoid `saveenv`,
`mmc write`, `erase`, firmware upgrade commands, and automatic eMMC mounting.

This is experimental recovery and research software for one tested hardware
configuration. Verify every command against your own board before using it.
Keep a working UART connection and an original firmware backup.

## Hardware tested

- Hisense H32M2600 mainboard family RSAG7.820.7642
- MediaTek MT5882/Capri, ARMv7-A
- approximately 773 MiB usable RAM
- Hynix H26M31001HPR eMMC
- U-Boot 2011.12.12 with the `mt5882 #` UART prompt
- Lexar USB mass-storage drive with FAT32 boot and ext4 root partitions

## Repository layout

- `buildroot/` — Buildroot configuration, overlay, services, and boot notes
- `buildroot-bootstrap/` — small USB bootstrap configuration
- `windows/H32BootSelector/` — .NET 8 Windows TTL boot selector
- `work/` — build, UART, USB preparation, inspection, and recovery scripts

Generated root filesystems, USB images, device dumps, firmware/kernel binaries,
captured UART logs, build caches, and cloned third-party source trees are not
committed. This repository therefore cannot redistribute the original Hisense
firmware or reproduce a ready-to-flash image by itself.

## Source dependencies

- [MediaTek Linux 3.10 source](https://github.com/yath/mediatek-linux-3.10)
- [Buildroot](https://buildroot.org/)
- [Arch Linux ARM](https://archlinuxarm.org/)

## VNC credentials

No VNC password is stored in the repository. The Buildroot startup script uses
`VNC_PASSWORD` from `/etc/default/h32-vnc` when supplied; otherwise it creates a
random eight-character password for that boot and prints it to the UART console.

## Status

Buildroot, the experimental Arch userspace, VNC, and Home Assistant Core have
been exercised on the test television. Device-specific multimedia acceleration,
video playback, and permanent installation are not claimed as supported.

## License and third-party code

Upstream projects retain their own licenses. Kernel-derived changes must be used
under the applicable GNU GPL terms. No rights to Hisense or MediaTek proprietary
firmware are granted or implied.
