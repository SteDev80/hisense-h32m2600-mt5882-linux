$ErrorActionPreference = 'Stop'
$serial = [System.IO.Ports.SerialPort]::new('COM3', 115200, 'None', 8, 'One')
$serial.Handshake = 'None'
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.ReadTimeout = 100
$serial.WriteTimeout = 1000
$logPath = 'C:\Users\steki\Documents\Codex\2026-08-30\referenced-chatgpt-conversation-this-is-an\outputs\buildroot-h32m2600\uart-stock-readonly-inspect.txt'
$all = ''
$bootargs = 'root=/dev/mmcblk0p7 rootwait rootfstype=squashfs ro console=ttyMT0,115200n1 earlyprintk loglevel=8 ignore_loglevel vmalloc=700mb mtdparts=mt53xx-emmc:2M(uboot),2M(uboot_env),256k(part_02),256k(part_03),4M(kernelA),4M(kernelB),75M(rootfsA),75M(rootfsB),256k(basic),8M(perm),320M(3rd_ro),750M(rw_area),256k(reserved),256k(channelA),256k(channelB),256k(pq),256k(aq),75M(logo),256k(ci),256k(part_19),3M(adsp),256k(ci),256k(dvbsDB),256k(hdcp),1M(facs),256k(hiscfg),2048M(data) usbportusing=1,1,1,1 usbpwrgpio=-1:-1,-1:-1,-1:-1,-1:-1 usbocgpio=404:0,404:0,405:0,405:0 usbhubrstgpio=-1:-1 msdcgpio=-1,-1,-1,-1,-1,-1 tzsz=18m no_console_suspend gpustart=810270720 gpusize=0 gpuionsize=0 init=/bin/sh'

function Read-UntilPrompt([int]$seconds) {
    $buffer = ''
    $deadline = [DateTime]::UtcNow.AddSeconds($seconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        $text = $script:serial.ReadExisting()
        if ($text.Length -gt 0) {
            [Console]::Write($text)
            $script:all += $text
            $buffer += $text
            $script:all | Set-Content -LiteralPath $script:logPath -Encoding utf8
        }
        if ($buffer -match 'mt5882\s*#\s*$') { return 'uboot' }
        if ($buffer -match '(?m)^/ #\s*$|(?m)^#\s*$') { return 'shell' }
        Start-Sleep -Milliseconds 15
    }
    return 'timeout'
}

try {
    $serial.Open()
    [Console]::WriteLine('[HOST] STOCK_LISTENER_READY: riavvia ora alimentazione TV.')
    $deadline = [DateTime]::UtcNow.AddMinutes(8)
    $buffer = ''
    while ([DateTime]::UtcNow -lt $deadline) {
        $text = $serial.ReadExisting()
        if ($text.Length -gt 0) { [Console]::Write($text); $all += $text; $buffer += $text }
        if ($buffer -match 'U-Boot 2011\.12\.12|Hit any key to stop autoboot') { $serial.Write(' ') }
        if ($buffer -match 'mt5882\s*#\s*$') { break }
        Start-Sleep -Milliseconds 10
    }
    if ($buffer -notmatch 'mt5882\s*#\s*$') { throw 'Prompt U-Boot non ricevuto.' }
    $serial.Write('setenv bootargs ' + $bootargs + "`r")
    if ((Read-UntilPrompt 20) -ne 'uboot') { throw 'setenv bootargs non confermato.' }
    $serial.Write("printenv bootargs`r")
    if ((Read-UntilPrompt 20) -ne 'uboot') { throw 'printenv bootargs non confermato.' }
    $serial.Write("eboot.lzo kernelA rootfsA`r")

    Start-Sleep -Seconds 3
    $serial.Write("`r")
    if ((Read-UntilPrompt 180) -ne 'shell') {
        $serial.Write("`r")
        if ((Read-UntilPrompt 30) -ne 'shell') { throw 'Shell di manutenzione non rilevata.' }
    }

    $commands = @(
        'mount -t proc proc /proc',
        'mount -t sysfs sysfs /sys',
        'echo ===UNAME===; uname -a',
        'echo ===CMDLINE===; cat /proc/cmdline',
        'echo ===CONFIG_GZ===; ls -l /proc/config.gz',
        'echo ===USB_MODULES===; find /lib/modules -type f 2>/dev/null | grep -Ei "usb|ehci|xhci|ohci|storage|scsi"',
        'echo ===MODULES_DEP===; find /lib/modules -name modules.dep -exec grep -Ei "usb|ehci|xhci|ohci|storage|scsi" {} \;',
        'echo ===INIT_USB===; grep -R -nEi "insmod|modprobe" /etc/init.d /etc/rc* 2>/dev/null | grep -Ei "usb|ehci|xhci|ohci|storage"',
        'echo ===CONFIG_BEGIN===; if test -f /proc/config.gz; then zcat /proc/config.gz; fi; echo ===CONFIG_END==='
    )
    foreach ($command in $commands) {
        $serial.Write($command + "`r")
        Start-Sleep -Milliseconds 300
        [void](Read-UntilPrompt 45)
    }
    $all | Set-Content -LiteralPath $logPath -Encoding utf8
    [Console]::WriteLine("`r`n[HOST] STOCK_READONLY_INSPECTION_DONE")
}
finally {
    if ($serial.IsOpen) { $serial.Close() }
}
