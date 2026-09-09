# Automatic USB boot — H32M2600 test unit

Validated on 9 September 2026 on the documented H32M2600 / MT5882 unit only.
This is not a generic Hisense firmware or an instruction for other boards.

## Installed behaviour

- USB present with `uMulti-h32-usb-test-v2`: boot Linux from USB.
- USB absent or image header missing: fall through to `kernelA rootfsA`.
- No kernel, rootfs or application was flashed to an original firmware slot.
- TTL is not needed for daily boot, but should be retained for recovery.

Installed `bootcmd`:

```text
usb start; mw.l 0x05000000 0 0x10; fatload usb 0:1 0x05000000 uMulti-h32-usb-test-v2; bootm 0x05000000; eboot.lzo kernelA rootfsA
```

The RAM clearing before `fatload` prevents a missing file from reusing a stale
legacy-image header. If loading or header parsing fails, `bootm` returns and the
last command boots the untouched Hisense A slots.

## Evidence and backup

Before the single `saveenv`, the complete 2 MiB `uboot_env` partition was read
twice and matched SHA-256:

```text
d613775ebdfaeb80b204af7616270a78139089b463a004474824efdc841bd580
```

The active automatic-boot environment was then read back as:

```text
2a08363cf138a87898ac4eb09a9b2b83caf773c178105eb45e58d84984485235
```

Backups are intentionally excluded from GitHub. The validated active backup is
named `uboot-env-autousb-active-20260909.bin`; verify its hash locally rather
than trusting a copied filename.

Tests performed on hardware:

1. valid multi-image checked by `iminfo` and booted;
2. USB removed: load failed, invalid RAM header was rejected and Hisense booted;
3. quoted environment command execution checked in RAM;
4. environment saved once;
5. reset with USB inserted booted Linux automatically;
6. TTL disconnected and cold boot repeated successfully;
7. Linux 3.10.27, USB root, Wi-Fi, Samba and audio confirmed; the readiness
   melody also completed its desktop/VNC health check.

## Recovery

The quickest recovery from a damaged USB is to remove it and power-cycle. To
restore the original policy, interrupt U-Boot using the already verified TTL
wiring, check that the prompt is `mt5882 #`, then use:

```text
setenv bootcmd 'eboot.lzo kernelA rootfsA'
printenv bootcmd
saveenv
```

Do not run this on another model or board revision. Do not use `upgrade`,
`erase`, `mmc write` or flash the oversized USB kernel into the 4 MiB slots.
`mt5882-uboot-command.ps1` is the small serial helper used during the tests; it
does not modify anything by itself and only sends commands supplied explicitly.

## Integrity limitation

`iminfo` validates this file, but live negative testing showed that this vendor
`bootm` can still start a multi-image whose payload was changed in RAM. Thus the
automatic chain reliably handles a missing USB or bad header, but cannot promise
same-boot fallback after every possible payload corruption or kernel hang.
Keep a second verified copy of the USB and shut Linux down cleanly.
