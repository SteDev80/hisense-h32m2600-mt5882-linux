# USB multi-image experiment, 2026-09-04

Initially tested only in RAM. On 9 September 2026 the validated image was
installed as the USB-first target after separate present/absent USB tests.

Separate file `uMulti-h32-usb-test-v2`, 7004453 bytes, SHA256
`217574bdfb8f59a281b55e20a3298a906b72049b9b8e76618f97d96733b94d75`.
Original USB kernel/initrd unchanged. Experimental file copied to USB FAT;
FAT remounted read-only. Staging copy also remains in Condivisa.

Kernel payload copied to 0x8000, entry 0x8000. Original single image uses
load=0x7fc0 because it executes in place with payload at header+64. Keeping
that load address in a relocated multi-image would be wrong. Initial local
artifact without this correction was never deployed or booted.

Live U-Boot accepted the multi-image at 0x05000000, found its ramdisk,
and booted the USB root. UART subsequently confirmed kernel 3.10.27,
Wi-Fi 192.168.1.52, VNC/Samba listening, H32_AUDIO_READY.
The first host logger failed on a concurrent file read; TV boot continued.
Logger now writes at completion and closes COM before writing the log.

## Failed safety test — do not install a simple automatic chain

In a second test the valid multi-image was loaded, checked with iminfo,
then its final payload byte at 0x056ae124 was changed from 00 to ff in RAM.
With `setenv verify yes`, `bootm` still started Linux; no Bad Data CRC
rejection occurred. The negative test script is now disabled.
No USB file was corrupted. The script's timeout omitted the final live
boot response from its saved transcript; the tool output captured it.

Related (not proven identical) Vizio U-Boot source, common/cmd_bootm.c
lines 774-784, skips the payload checksum under CONFIG_FAST_BOOT. This
is consistent with the live behavior, but the exact firmware build config
has not been recovered. `iminfo` does verify CRC, yet this U-Boot has no
working hush `if` or `run` to gate bootm on its result.

The second test retained stock bootargs; the USB initramfs nevertheless
selected USB root. Subsequent live check: /dev/sda2 mounted at /, no mmc
mount, /sys/block/mmcblk0/ro=1. Restore normal tested USB bootargs afterward.

The actual original-firmware fallback was subsequently verified with USB absent,
then an automatic cold boot from USB was verified without TTL. The original and
modified 2 MiB environment partition were archived outside the repository.
The payload-CRC limitation remains: an image that reaches the kernel and hangs
cannot fall back during the same boot. Remove the USB and power-cycle to boot
Hisense. See `README-autoboot-usb.md`.
