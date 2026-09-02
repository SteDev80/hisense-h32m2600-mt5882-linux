param(
    [switch]$ResetFirst,
    [switch]$WaitForPowerCycle,
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
    if ($WaitForPowerCycle) {
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

    Start-Sleep -Seconds 15
    $usb = Run-Uboot 'usb start' 60
    if ($usb -notmatch '1 Storage Device\(s\) found') { throw 'Lexar non enumerata' }

    $kernel = Run-Uboot 'fatload usb 0:1 0x00007fc0 uImage-h32m2600-rescue-initrd' 120
    if ($kernel -notmatch '5027136 bytes read') { throw 'Kernel non caricato integralmente' }

    $initrd = Run-Uboot 'fatload usb 0:1 0x04000000 uInitrd-h32m2600-bootstrap' 120
    if ($initrd -notmatch '1975736 bytes read') { throw 'Bootstrap p27 non caricato integralmente' }

    $kernelInfo = Run-Uboot 'iminfo 0x00007fc0' 45
    if ($kernelInfo -notmatch 'Verifying Checksum \.\.\. OK') { throw 'CRC kernel non valido' }

    $initrdInfo = Run-Uboot 'iminfo 0x04000000' 45
    if ($initrdInfo -notmatch 'Verifying Checksum \.\.\. OK') { throw 'CRC bootstrap p27 non valido' }

    [void](Run-Uboot ("setenv bootargs " + $bootargs) 30)
    $env = Run-Uboot 'printenv bootargs' 30
    if ($env -notmatch 'rdinit=/init' -or $env -notmatch "h32mode=$Mode") { throw 'bootargs non impostati correttamente' }

    [Console]::WriteLine("`r`n[HOST] -> bootm 0x00007fc0 0x04000000")
    $serial.Write("bootm 0x00007fc0 0x04000000`r")
    $deadline = [DateTime]::UtcNow.AddMinutes(8)
    while ([DateTime]::UtcNow -lt $deadline) {
        $text = $serial.ReadExisting()
        if ($text) {
            [Console]::Write($text)
            $all += $text
            $all | Set-Content -LiteralPath $logPath -Encoding utf8
            $modeMarker = if ($Mode -eq 'arch') { '=== ARCH LINUX ARM EXPERIMENTAL MODE ===' } else { '=== BUILDROOT P27 MODE ===' }
            if ($all -match '=== MT5882 BUILDROOT RESCUE READY ===' -and $all -match [regex]::Escape($modeMarker)) {
                [Console]::WriteLine("`r`n[HOST] H32LINUX_${Mode}_READY")
                break
            }
        }
        Start-Sleep -Milliseconds 20
    }
}
finally {
    $all | Set-Content -LiteralPath $logPath -Encoding utf8
    if ($serial.IsOpen) { $serial.Close() }
}
