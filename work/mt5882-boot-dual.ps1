param(
    [switch]$ResetFirst,
    [switch]$WaitForPowerCycle,
    [switch]$RebootFromLinux,
    [switch]$UsbVendor,
    [switch]$DisableVendorWifi,
    [switch]$ReadOnlyBootAudit,
    [switch]$UsbFallbackRamTest,
    [switch]$HoldAtUboot,
    [switch]$MultiImageTest,
    [ValidateSet('buildroot', 'arch')]
    [string]$Mode = 'buildroot'
)

$ErrorActionPreference = 'Stop'

$serial = [System.IO.Ports.SerialPort]::new('COM3', 115200, 'None', 8, 'One')
$serial.Handshake = 'None'
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.ReadTimeout = 100
$serial.WriteTimeout = 3000

$logPath = "C:\Users\steki\Documents\Codex\2026-08-30\referenced-chatgpt-conversation-this-is-an\outputs\buildroot-h32m2600\uart-$Mode-boot.txt"
if ($UsbVendor) {
    $logPath = Join-Path (Split-Path $PSScriptRoot -Parent) "outputs\vendor-usb-v1\uart-$Mode-boot.txt"
}
if ($MultiImageTest) {
    $logPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'outputs\usb-multi-test\uart-multi-boot.txt'
}
$all = ''

function Read-UntilPrompt([int]$seconds) {
    $buffer = ''
    $deadline = [DateTime]::UtcNow.AddSeconds($seconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        $text = $script:serial.ReadExisting()
        if ($text) {
            [Console]::Write($text)
            $script:all += $text
            $buffer += $text
            if ($buffer.Length -gt 32768) {
                $buffer = $buffer.Substring($buffer.Length - 32768)
            }
        }
        if ($buffer -match 'mt5882\s*#\s*$') { return $buffer }
        Start-Sleep -Milliseconds 20
    }
    throw 'Timeout in attesa del prompt U-Boot'
}

function Run-Uboot([string]$command, [int]$seconds = 90) {
    [Console]::WriteLine("`r`n[HOST] -> $command")
    $script:serial.Write($command + "`r")
    return Read-UntilPrompt $seconds
}

$bootargs = 'console=ttyMT0,115200n1 earlyprintk loglevel=8 ignore_loglevel rdinit=/init vmalloc=700mb mtdparts=mt53xx-emmc:2M(uboot),2M(uboot_env),256k(part_02),256k(part_03),4M(kernelA),4M(kernelB),75M(rootfsA),75M(rootfsB),256k(basic),8M(perm),320M(3rd_ro),750M(rw_area),256k(reserved),256k(channelA),256k(channelB),256k(pq),256k(aq),75M(logo),256k(ci),256k(part_19),3M(adsp),256k(ci),256k(dvbsDB),256k(hdcp),1M(facs),256k(hiscfg),2048M(data) usbportusing=1,1,1,1 usbpwrgpio=-1:-1,-1:-1,-1:-1,-1:-1 usbocgpio=404:0,404:0,405:0,405:0 usbhubrstgpio=-1:-1 msdcgpio=-1,-1,-1,-1,-1,-1 tzsz=18m no_console_suspend gpustart=810270720 gpusize=0 gpuionsize=0' + " h32mode=$Mode"

try {
    $serial.Open()
    if ($UsbVendor) {
        $bootargs += ' h32root=usb h32vendor=' + $(if ($DisableVendorWifi) { '0' } else { '1' })
    }
    if ($RebootFromLinux) {
        $serial.Write('test "$(uname -r)" = 3.10.27 && echo H32_LINUX_REBOOT_OK' + "`r")
        Start-Sleep -Seconds 1
        $probe = $serial.ReadExisting()
        $all += $probe
        if ($probe -notmatch '(?m)^H32_LINUX_REBOOT_OK\r?$') { throw 'Linux shell not confirmed; no reboot sent' }
        # The RAM lab has a shell as PID 1; regular reboot cannot ask init there.
        # Restrict forced reboot to that lab with its USB filesystem read-only.
        $serial.Write('if test -d /lab/archlinux/rootfs && grep -q "^rootfs / rootfs " /proc/mounts && grep -q "^/dev/sda2 /lab ext4 ro," /proc/mounts; then reboot -f; else reboot; fi' + "`r")
        $buffer = ''
        $deadline = [DateTime]::UtcNow.AddMinutes(3)
        while ([DateTime]::UtcNow -lt $deadline) {
            $text = $serial.ReadExisting()
            if ($text) {
                [Console]::Write($text); $all += $text; $buffer += $text
                if ($text -match 'U-Boot 2011\.12\.12|Hit any key to stop autoboot') { $serial.Write(' ') }
                if ($buffer -match 'mt5882\s*#\s*$') { break }
            }
            Start-Sleep -Milliseconds 10
        }
        if ($buffer -notmatch 'mt5882\s*#\s*$') { throw 'U-Boot not intercepted after Linux reboot' }
    }
    elseif ($WaitForPowerCycle) {
        [Console]::WriteLine('[HOST] ARMED: in attesa del riavvio fisico della TV...')
        $buffer = ''
        $deadline = [DateTime]::UtcNow.AddMinutes(30)
        while ([DateTime]::UtcNow -lt $deadline) {
            $text = $serial.ReadExisting()
            if ($text) {
                [Console]::Write($text)
                $all += $text
                $buffer += $text
                if ($text -match 'U-Boot 2011\.12\.12|Hit any key to stop autoboot') {
                    $serial.Write(' ')
                    Start-Sleep -Milliseconds 50
                    $serial.Write(' ')
                }
                if ($buffer -match 'mt5882\s*#\s*$') { break }
                if ($buffer.Length -gt 131072) {
                    $buffer = $buffer.Substring($buffer.Length - 65536)
                }
            }
            Start-Sleep -Milliseconds 10
        }
        if ($buffer -notmatch 'mt5882\s*#\s*$') { throw 'Prompt U-Boot non intercettato dopo il riavvio fisico' }
    }
    elseif ($ResetFirst) {
        [Console]::WriteLine('[HOST] -> reset (solo riavvio, nessuna scrittura)')
        $serial.Write("reset`r")
        $buffer = ''
        $deadline = [DateTime]::UtcNow.AddMinutes(3)
        while ([DateTime]::UtcNow -lt $deadline) {
            $text = $serial.ReadExisting()
            if ($text) {
                [Console]::Write($text)
                $all += $text
                $buffer += $text
                if ($text -match 'Hit any key to stop autoboot') { $serial.Write(' ') }
                if ($buffer -match 'mt5882\s*#\s*$') { break }
            }
            Start-Sleep -Milliseconds 10
        }
        if ($buffer -notmatch 'mt5882\s*#\s*$') { throw 'Prompt U-Boot non intercettato dopo reset' }
    }
    else {
        $serial.Write("`r")
        [void](Read-UntilPrompt 15)
    }

    if ($HoldAtUboot) {
        $confirmation = Run-Uboot 'version' 15
        if ($confirmation -notmatch 'U-Boot 2011\.12\.12') { throw 'U-Boot hold not confirmed' }
        $all | Set-Content -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'outputs/uboot-held-for-usb-test.txt') -Encoding utf8
        [Console]::WriteLine('[HOST] HELD_AT_UBOOT: Linux stopped; USB may now be removed.')
        return
    }
    Start-Sleep -Seconds 15
    if ($UsbFallbackRamTest) {
        $fallbackAudit = Run-Uboot 'printenv bootargs' 20
    }
    $usb = Run-Uboot 'usb start' 60
    if ($usb -notmatch '1 Storage Device\(s\) found') { throw 'Lexar non enumerata' }

    if ($UsbFallbackRamTest) {
        # Scratch RAM, disjoint from kernel and initrd; never a flash address.
        $fallbackAudit += Run-Uboot 'fatload usb 0:1 0x05000000 uImage-h32m2600-rescue-initrd' 120
        $validScratch = Run-Uboot 'iminfo 0x05000000' 30
        if ($validScratch -notmatch 'Verifying Checksum \.\.\. OK') { throw 'Scratch image did not validate' }
        $fallbackAudit += $validScratch
        # Invalidate a previously valid image BEFORE trying a missing file.
        # Version stands in for stock boot: demonstrate fall-through, not boot stock.
        $missing = Run-Uboot 'mw.l 0x05000000 0 0x10; fatload usb 0:1 0x05000000 H32-NONEXISTENT-RAM-TEST.img; bootm 0x05000000; version' 30
        $fallbackAudit += $missing
        if ($missing -notmatch 'Wrong Image Format' -or $missing -notmatch 'GNU ld') { throw 'Missing image fallback test did not pass' }
        $corrupt = Run-Uboot 'mw.l 0x05000000 0 0x10; bootm 0x05000000; version' 20
        $fallbackAudit += $corrupt
        if ($corrupt -notmatch 'Wrong Image Format' -or $corrupt -notmatch 'GNU ld') { throw 'Invalid header fallback test did not pass' }
        $fallbackAudit | Set-Content -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'outputs/usb-fallback-ram-test.txt') -Encoding utf8
    }

    if ($MultiImageTest) {
        if (-not $UsbVendor -or $Mode -ne 'buildroot') { throw 'Multi test requires USB vendor Buildroot' }
        [void](Run-Uboot 'mw.l 0x05000000 0 0x10' 15)
        $multi = Run-Uboot 'fatload usb 0:1 0x05000000 uMulti-h32-usb-test-v2' 120
        if ($multi -notmatch '7004453 bytes read') { throw 'Multi-image incomplete; held at U-Boot' }
        $multiInfo = Run-Uboot 'iminfo 0x05000000' 45
        if ($multiInfo -notmatch 'Verifying Checksum \.\.\. OK') { throw 'Multi CRC invalid; held at U-Boot' }
        [void](Run-Uboot 'setenv verify yes' 15)
    } else {
    $kernel = Run-Uboot 'fatload usb 0:1 0x00007fc0 uImage-h32m2600-rescue-initrd' 120
    if ($kernel -notmatch '5027136 bytes read') { throw 'Kernel non caricato integralmente' }

    $initrdName = if ($UsbVendor) { 'uInitrd-h32m2600-usb-vendor-v1' } else { 'uInitrd-h32m2600-bootstrap' }
    $initrdBytes = if ($UsbVendor) { 1977369 } else { 1975736 }
    $initrd = Run-Uboot "fatload usb 0:1 0x04000000 $initrdName" 120
    if ($initrd -notmatch "$initrdBytes bytes read") { throw 'Bootstrap non caricato integralmente' }

    $kernelInfo = Run-Uboot 'iminfo 0x00007fc0' 45
    if ($kernelInfo -notmatch 'Verifying Checksum \.\.\. OK') { throw 'CRC kernel non valido' }

    $initrdInfo = Run-Uboot 'iminfo 0x04000000' 45
    if ($initrdInfo -notmatch 'Verifying Checksum \.\.\. OK') { throw 'CRC bootstrap p27 non valido' }
    }

    [void](Run-Uboot ("setenv bootargs " + $bootargs) 30)
    if ($ReadOnlyBootAudit) {
        $audit = ''
        foreach ($query in @('version', 'printenv bootcmd', 'printenv bootdelay', 'printenv preboot', 'help usbboot', 'help env', 'help load', 'help run', 'help test', 'if version; then version; fi')) {
            $audit += "`r`nQUERY: $query`r`n" + (Run-Uboot $query 15)
        }
        $audit | Set-Content -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'outputs/uboot-readonly-audit.txt') -Encoding utf8
    }
    $env = Run-Uboot 'printenv bootargs' 30
    if ($env -notmatch 'rdinit=/init' -or $env -notmatch "h32mode=$Mode") { throw 'bootargs non impostati correttamente' }

    $bootCommand = if ($MultiImageTest) { 'bootm 0x05000000' } else { 'bootm 0x00007fc0 0x04000000' }
    [Console]::WriteLine("`r`n[HOST] -> $bootCommand")
    $serial.Write($bootCommand + "`r")
    $deadline = [DateTime]::UtcNow.AddMinutes(8)
    $bootReady = $false
    $nextLoginProbe = [DateTime]::UtcNow.AddSeconds(60)
    while ([DateTime]::UtcNow -lt $deadline) {
        $text = $serial.ReadExisting()
        if ($text) {
            [Console]::Write($text)
            $all += $text
            if ($MultiImageTest -and $all -match 'mt5882\s*#\s*$' -and $text -match 'mt5882\s*#\s*$') {
                throw 'Multi boot returned to U-Boot; normal USB boot remains available'
            }
            $modeMarker = if ($Mode -eq 'arch') { '=== ARCH LINUX ARM EXPERIMENTAL MODE ===' } else { '=== BUILDROOT P27 MODE ===' }
            if ($UsbVendor -and $Mode -eq 'buildroot') { $modeMarker = '=== BUILDROOT USB VENDOR MODE ===' }
            # S99mt5882 prints READY before the later Wi-Fi/desktop scripts.
            # In Buildroot, wait for getty as well before releasing the UART.
            $loginReady = ($Mode -ne 'buildroot') -or ($all -match 'h32m2600 login:\s*$')
            if ($loginReady -and $all -match '=== MT5882 BUILDROOT RESCUE READY ===' -and $all -match [regex]::Escape($modeMarker)) {
                $bootReady = $true
                [Console]::WriteLine("`r`n[HOST] H32LINUX_${Mode}_READY")
                [Console]::WriteLine('[HOST] Console pronta; verificare separatamente IP e connessione VNC.')
                break
            }
        }
        # Getty may wait for a newline before emitting its login prompt.
        if ($all -match '=== MT5882 BUILDROOT RESCUE READY ===' -and [DateTime]::UtcNow -gt $nextLoginProbe) {
            $serial.Write("`r")
            $nextLoginProbe = [DateTime]::UtcNow.AddSeconds(5)
        }
        Start-Sleep -Milliseconds 20
    }
    if (-not $bootReady) { throw 'Avvio non confermato entro il tempo previsto; controllare il log UART.' }
}
finally {
    if ($serial.IsOpen) { $serial.Close() }
    $all | Set-Content -LiteralPath $logPath -Encoding utf8
}
